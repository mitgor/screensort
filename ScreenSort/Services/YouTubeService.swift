//
//  YouTubeService.swift
//  ScreenSort
//
//  Handles YouTube Data API operations for searching and playlist management.
//

import Foundation

// MARK: - Configuration

/// Configuration constants for YouTube API operations.
enum YouTubeAPIConfig {
    /// Base URL for YouTube Data API v3.
    static let baseURL = "https://www.googleapis.com/youtube/v3"

    /// Music category ID for filtering search results.
    static let musicCategoryId = "10"

    /// Maximum results to return from search.
    static let searchMaxResults = 1

    /// Maximum playlists to fetch when looking for existing ones.
    static let playlistFetchLimit = 50

    /// Default playlist description for newly created playlists.
    static let defaultPlaylistDescription = "Songs added by ScreenSort app"

    /// Default privacy status for newly created playlists.
    static let defaultPrivacyStatus = "private"
}

// MARK: - YouTube Service

/// Service for interacting with YouTube Data API.
///
/// Handles video search and playlist operations using OAuth for authenticated
/// operations (playlists) and API key for public operations (search).
///
/// ## Usage
/// ```swift
/// let service = YouTubeService()
///
/// // Search for a song
/// let videoId = try await service.searchForSong(title: "Bohemian Rhapsody", artist: "Queen")
///
/// // Add to playlist
/// let playlistId = try await service.getOrCreatePlaylist(named: "ScreenSort")
/// try await service.addToPlaylist(videoId: videoId, playlistId: playlistId)
/// ```
final class YouTubeService: YouTubeServiceProtocol {

    // MARK: - Dependencies

    private let authService: AuthServiceProtocol
    private let apiClient: APIClient
    private let apiKey: String

    // MARK: - Initialization

    /// Creates a new YouTube service with the specified dependencies.
    ///
    /// - Parameters:
    ///   - authService: Service for OAuth authentication.
    ///   - apiClient: HTTP client for API requests. Defaults to `APIClient.shared`.
    init(
        authService: AuthServiceProtocol,
        apiClient: APIClient = APIClient.shared
    ) {
        self.authService = authService
        self.apiClient = apiClient
        self.apiKey = Bundle.main.object(forInfoDictionaryKey: "YOUTUBE_API_KEY") as? String ?? ""
    }

    /// Convenience initializer for production use.
    @MainActor
    convenience init() {
        self.init(authService: AuthService(), apiClient: APIClient.shared)
    }

    // MARK: - Search

    /// Search YouTube for a song by title and artist.
    ///
    /// Searches the Music category and appends "official audio" to improve
    /// result quality.
    ///
    /// - Parameters:
    ///   - title: The song title to search for.
    ///   - artist: The artist name to search for.
    /// - Returns: The video ID of the best matching result.
    /// - Throws: `YouTubeError.noResultsFound` if no videos match, or other
    ///           `YouTubeError` variants for API failures.
    func searchForSong(title: String, artist: String) async throws -> String {
        let searchQuery = buildSearchQuery(title: title, artist: artist)
        let url = try buildSearchURL(query: searchQuery)

        let (data, response) = try await apiClient.get(url: url)

        try handleAPIErrors(response: response, data: data, context: "search")

        let searchResponse = try JSONDecoder().decode(YouTubeSearchResponse.self, from: data)

        guard let firstResult = searchResponse.items.first else {
            throw YouTubeError.noResultsFound(query: "\(title) \(artist)")
        }

        return firstResult.id.videoId
    }

    // MARK: - Playlist Operations

    /// Add a video to a playlist.
    ///
    /// Requires OAuth authentication. Silently succeeds if the video is
    /// already in the playlist (HTTP 409).
    ///
    /// - Parameters:
    ///   - videoId: The YouTube video ID to add.
    ///   - playlistId: The playlist ID to add the video to.
    /// - Throws: `YouTubeError` if the operation fails.
    func addToPlaylist(videoId: String, playlistId: String) async throws {
        let accessToken = try await authService.getValidAccessToken()
        let url = URL(string: "\(YouTubeAPIConfig.baseURL)/playlistItems?part=snippet")!

        let requestBody = PlaylistItemInsertRequest(
            snippet: PlaylistItemInsertRequest.Snippet(
                playlistId: playlistId,
                resourceId: PlaylistItemInsertRequest.ResourceId(
                    kind: "youtube#video",
                    videoId: videoId
                )
            )
        )

        let bodyData = try JSONEncoder().encode(requestBody)

        let (data, response) = try await apiClient.post(
            url: url,
            body: bodyData,
            headers: ["Authorization": "Bearer \(accessToken)"]
        )

        // 409 Conflict means video already in playlist - this is fine
        if response.statusCode == 409 {
            return
        }

        try handleAPIErrors(response: response, data: data, context: "playlist insert")
    }

    /// Get an existing playlist by name, or create it if it doesn't exist.
    ///
    /// Requires OAuth authentication.
    ///
    /// - Parameter name: The playlist name to find or create.
    /// - Returns: The playlist ID.
    /// - Throws: `YouTubeError` if the operation fails.
    func getOrCreatePlaylist(named name: String) async throws -> String {
        let accessToken = try await authService.getValidAccessToken()

        // First, try to find an existing playlist
        if let existingId = try await findPlaylist(named: name, accessToken: accessToken) {
            return existingId
        }

        // Create a new playlist if not found
        return try await createPlaylist(named: name, accessToken: accessToken)
    }

    // MARK: - Private: Search Helpers

    /// Builds a search query optimized for finding music videos.
    private func buildSearchQuery(title: String, artist: String) -> String {
        let cleanTitle = sanitizeForSearch(title)
        let cleanArtist = sanitizeForSearch(artist)
        return "\(cleanTitle) \(cleanArtist) official audio"
    }

    /// Removes special characters that might interfere with search.
    private func sanitizeForSearch(_ text: String) -> String {
        let allowedCharacters = CharacterSet.alphanumerics.union(.whitespaces)
        return text
            .unicodeScalars
            .filter { allowedCharacters.contains($0) }
            .map { Character($0) }
            .map { String($0) }
            .joined()
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// Builds the search API URL with query parameters.
    private func buildSearchURL(query: String) throws -> URL {
        var components = URLComponents(string: "\(YouTubeAPIConfig.baseURL)/search")!
        components.queryItems = [
            URLQueryItem(name: "part", value: "snippet"),
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "type", value: "video"),
            URLQueryItem(name: "videoCategoryId", value: YouTubeAPIConfig.musicCategoryId),
            URLQueryItem(name: "maxResults", value: String(YouTubeAPIConfig.searchMaxResults)),
            URLQueryItem(name: "key", value: apiKey)
        ]

        guard let url = components.url else {
            throw YouTubeError.searchFailed(reason: "Invalid search URL")
        }

        return url
    }

    // MARK: - Private: Playlist Helpers

    /// Finds an existing playlist by name.
    private func findPlaylist(named name: String, accessToken: String) async throws -> String? {
        var components = URLComponents(string: "\(YouTubeAPIConfig.baseURL)/playlists")!
        components.queryItems = [
            URLQueryItem(name: "part", value: "snippet"),
            URLQueryItem(name: "mine", value: "true"),
            URLQueryItem(name: "maxResults", value: String(YouTubeAPIConfig.playlistFetchLimit))
        ]

        let (data, response) = try await apiClient.get(
            url: components.url!,
            headers: ["Authorization": "Bearer \(accessToken)"],
            cachePolicy: .reloadIgnoringLocalCacheData  // Always fetch fresh playlist list
        )

        try handleAPIErrors(response: response, data: data, context: "fetch playlists")

        let playlistResponse = try JSONDecoder().decode(YouTubePlaylistListResponse.self, from: data)

        return playlistResponse.items.first { $0.snippet.title == name }?.id
    }

    /// Creates a new private playlist.
    private func createPlaylist(named name: String, accessToken: String) async throws -> String {
        let url = URL(string: "\(YouTubeAPIConfig.baseURL)/playlists?part=snippet,status")!

        let requestBody = PlaylistCreateRequest(
            snippet: PlaylistCreateRequest.Snippet(
                title: name,
                description: YouTubeAPIConfig.defaultPlaylistDescription
            ),
            status: PlaylistCreateRequest.Status(
                privacyStatus: YouTubeAPIConfig.defaultPrivacyStatus
            )
        )

        let bodyData = try JSONEncoder().encode(requestBody)

        let (data, response) = try await apiClient.post(
            url: url,
            body: bodyData,
            headers: ["Authorization": "Bearer \(accessToken)"]
        )

        try handleAPIErrors(response: response, data: data, context: "create playlist")

        let createResponse = try JSONDecoder().decode(YouTubePlaylistCreateResponse.self, from: data)
        return createResponse.id
    }

    // MARK: - Private: Error Handling

    /// Handles common API error responses.
    private func handleAPIErrors(response: HTTPURLResponse, data: Data, context: String) throws {
        // Check for auth errors
        if response.statusCode == 401 {
            throw YouTubeError.tokenExpired
        }

        // Check for quota exceeded
        if response.statusCode == 403 {
            if let errorResponse = try? JSONDecoder().decode(YouTubeAPIErrorResponse.self, from: data),
               errorResponse.error.errors.contains(where: { $0.reason == "quotaExceeded" }) {
                throw YouTubeError.quotaExceeded
            }
        }

        // Check for general HTTP errors
        guard (200...299).contains(response.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8)
            throw YouTubeError.invalidResponse(statusCode: response.statusCode, message: errorMessage)
        }
    }
}

// MARK: - Request Models

/// Request body for adding a video to a playlist.
private struct PlaylistItemInsertRequest: Encodable {
    let snippet: Snippet

    struct Snippet: Encodable {
        let playlistId: String
        let resourceId: ResourceId
    }

    struct ResourceId: Encodable {
        let kind: String
        let videoId: String
    }
}

/// Request body for creating a new playlist.
private struct PlaylistCreateRequest: Encodable {
    let snippet: Snippet
    let status: Status

    struct Snippet: Encodable {
        let title: String
        let description: String
    }

    struct Status: Encodable {
        let privacyStatus: String
    }
}

// MARK: - Response Models

/// Response from YouTube search API.
private struct YouTubeSearchResponse: Decodable {
    let items: [SearchItem]

    struct SearchItem: Decodable {
        let id: VideoId

        struct VideoId: Decodable {
            let videoId: String
        }
    }
}

/// Response from YouTube playlist list API.
private struct YouTubePlaylistListResponse: Decodable {
    let items: [PlaylistItem]

    struct PlaylistItem: Decodable {
        let id: String
        let snippet: Snippet

        struct Snippet: Decodable {
            let title: String
        }
    }
}

/// Response from YouTube playlist create API.
private struct YouTubePlaylistCreateResponse: Decodable {
    let id: String
}

/// Error response from YouTube API.
private struct YouTubeAPIErrorResponse: Decodable {
    let error: APIError

    struct APIError: Decodable {
        let code: Int
        let message: String
        let errors: [ErrorDetail]
    }

    struct ErrorDetail: Decodable {
        let reason: String
    }
}
