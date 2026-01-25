import SwiftUI
import Photos
import Combine

@MainActor
class ProcessingViewModel: ObservableObject {

    // MARK: - Published State

    @Published var photoPermissionStatus: PHAuthorizationStatus = .notDetermined
    @Published var isYouTubeAuthenticated = false
    @Published var isProcessing = false
    @Published var processingProgress: (current: Int, total: Int) = (0, 0)
    @Published var lastError: String?
    @Published var results: [ProcessingResultItem] = []
    @Published var googleDocURL: String?

    // MARK: - Services

    nonisolated(unsafe) private let photoService: PhotoLibraryServiceProtocol
    nonisolated(unsafe) private let extractor: MusicExtractorProtocol
    nonisolated(unsafe) private let youtubeService: YouTubeServiceProtocol
    nonisolated(unsafe) private let authService: AuthServiceProtocol
    nonisolated(unsafe) private let googleDocsService: GoogleDocsServiceProtocol

    // MARK: - Config

    private let playlistName = "ScreenSort"
    private let processedAlbumName = "ScreenSort - Processed"
    private let flaggedAlbumName = "ScreenSort - Flagged"
    private let captionPrefix = "ScreenSort"

    // MARK: - Init

    nonisolated init(
        photoService: PhotoLibraryServiceProtocol,
        extractor: MusicExtractorProtocol,
        youtubeService: YouTubeServiceProtocol,
        authService: AuthServiceProtocol,
        googleDocsService: GoogleDocsServiceProtocol
    ) {
        self.photoService = photoService
        self.extractor = extractor
        self.youtubeService = youtubeService
        self.authService = authService
        self.googleDocsService = googleDocsService
    }

    // MARK: - Setup

    func checkInitialState() {
        photoPermissionStatus = photoService.authorizationStatus()
        isYouTubeAuthenticated = authService.isAuthenticated
        googleDocURL = googleDocsService.documentURL
    }

    // MARK: - Photo Permissions

    func requestPhotoAccess() async {
        photoPermissionStatus = await photoService.requestAuthorization()
    }

    var hasPhotoAccess: Bool {
        photoPermissionStatus == .authorized || photoPermissionStatus == .limited
    }

    // MARK: - YouTube Auth

    func authenticateYouTube() async {
        do {
            try await authService.authenticate()
            isYouTubeAuthenticated = true
            lastError = nil
        } catch {
            lastError = "YouTube login failed: \(error.localizedDescription)"
            isYouTubeAuthenticated = false
        }
    }

    func signOutYouTube() {
        try? authService.signOut()
        isYouTubeAuthenticated = false
    }

    // MARK: - Processing

    func processNow() async {
        guard hasPhotoAccess else {
            lastError = "Photo library access required"
            return
        }

        guard isYouTubeAuthenticated else {
            lastError = "YouTube login required"
            return
        }

        isProcessing = true
        results = []
        lastError = nil

        do {
            // 1. Fetch screenshots (excluding already processed ones)
            let allScreenshots = try await photoService.fetchScreenshots()
            let screenshots = allScreenshots.filter { asset in
                // Skip if already has ScreenSort caption
                let existingCaption = photoService.getCaption(for: asset)
                return existingCaption == nil || !existingCaption!.hasPrefix(captionPrefix)
            }

            processingProgress = (0, screenshots.count)

            guard !screenshots.isEmpty else {
                lastError = "No new screenshots to process"
                isProcessing = false
                return
            }

            // 2. Get/create playlist
            let playlistId = try await youtubeService.getOrCreatePlaylist(named: playlistName)

            // 3. Ensure albums exist
            _ = try await photoService.createAlbumIfNeeded(named: processedAlbumName)
            _ = try await photoService.createAlbumIfNeeded(named: flaggedAlbumName)

            // 4. Process each screenshot
            for (index, asset) in screenshots.enumerated() {
                processingProgress = (index + 1, screenshots.count)

                let result = await processScreenshot(asset: asset, playlistId: playlistId)
                results.append(result)
            }

            // Update Google Doc URL if available
            googleDocURL = googleDocsService.documentURL

        } catch {
            lastError = error.localizedDescription
        }

        isProcessing = false
    }

    private func processScreenshot(asset: PHAsset, playlistId: String) async -> ProcessingResultItem {
        do {
            // Extract metadata
            let metadata = try await extractor.extractMusicMetadata(from: asset)

            // Search YouTube
            let videoId = try await youtubeService.searchForSong(
                title: metadata.songTitle,
                artist: metadata.artist
            )

            // Add to playlist
            try await youtubeService.addToPlaylist(videoId: videoId, playlistId: playlistId)

            // Build YouTube link
            let youtubeLink = "https://youtube.com/watch?v=\(videoId)"

            // Log to Google Docs
            let logEntry = ContentLogEntry(
                type: .music,
                title: metadata.songTitle,
                creator: metadata.artist,
                serviceLink: youtubeLink,
                capturedAt: asset.creationDate ?? Date()
            )
            _ = try? await googleDocsService.appendEntry(logEntry)

            // Move to processed album
            try await photoService.addAsset(asset, toAlbum: processedAlbumName)

            // Set caption on photo
            let caption = buildCaption(
                type: "Music",
                title: metadata.songTitle,
                creator: metadata.artist,
                status: "Added to YouTube"
            )
            try? await photoService.setCaption(caption, for: asset)

            return ProcessingResultItem(
                assetId: asset.localIdentifier,
                status: .success,
                songTitle: metadata.songTitle,
                artist: metadata.artist,
                message: "Added to playlist",
                youtubeLink: youtubeLink
            )

        } catch let error as MusicExtractionError {
            // Low confidence or not music - move to flagged
            try? await photoService.addAsset(asset, toAlbum: flaggedAlbumName)

            // Set caption indicating failure
            let caption = buildCaption(
                type: "Unknown",
                title: nil,
                creator: nil,
                status: "Failed: \(error.localizedDescription)"
            )
            try? await photoService.setCaption(caption, for: asset)

            return ProcessingResultItem(
                assetId: asset.localIdentifier,
                status: .flagged,
                songTitle: nil,
                artist: nil,
                message: error.localizedDescription,
                youtubeLink: nil
            )

        } catch let error as YouTubeError {
            // YouTube error - move to flagged
            try? await photoService.addAsset(asset, toAlbum: flaggedAlbumName)

            let caption = buildCaption(
                type: "Music",
                title: nil,
                creator: nil,
                status: "YouTube error: \(error.localizedDescription)"
            )
            try? await photoService.setCaption(caption, for: asset)

            return ProcessingResultItem(
                assetId: asset.localIdentifier,
                status: .failed,
                songTitle: nil,
                artist: nil,
                message: error.localizedDescription,
                youtubeLink: nil
            )

        } catch {
            // Other error - move to flagged
            try? await photoService.addAsset(asset, toAlbum: flaggedAlbumName)

            let caption = buildCaption(
                type: "Unknown",
                title: nil,
                creator: nil,
                status: "Error: \(error.localizedDescription)"
            )
            try? await photoService.setCaption(caption, for: asset)

            return ProcessingResultItem(
                assetId: asset.localIdentifier,
                status: .failed,
                songTitle: nil,
                artist: nil,
                message: error.localizedDescription,
                youtubeLink: nil
            )
        }
    }

    // MARK: - Caption Building

    private func buildCaption(type: String, title: String?, creator: String?, status: String) -> String {
        var parts = ["\(captionPrefix): \(type)"]

        if let title = title {
            parts.append("Title: \(title)")
        }
        if let creator = creator {
            parts.append("Artist: \(creator)")
        }
        parts.append("Status: \(status)")

        return parts.joined(separator: " | ")
    }
}

// MARK: - Result Item

struct ProcessingResultItem: Identifiable {
    let id = UUID()
    let assetId: String
    let status: Status
    let songTitle: String?
    let artist: String?
    let message: String
    let youtubeLink: String?

    enum Status {
        case success
        case flagged
        case failed
    }
}
