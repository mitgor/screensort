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

    // MARK: - Services

    nonisolated(unsafe) private let photoService: PhotoLibraryServiceProtocol
    nonisolated(unsafe) private let extractor: MusicExtractorProtocol
    nonisolated(unsafe) private let youtubeService: YouTubeServiceProtocol
    nonisolated(unsafe) private let authService: AuthServiceProtocol

    // MARK: - Config

    private let playlistName = "ScreenSort"
    private let processedAlbumName = "ScreenSort - Processed"
    private let flaggedAlbumName = "ScreenSort - Flagged"

    // MARK: - Init

    nonisolated init(
        photoService: PhotoLibraryServiceProtocol,
        extractor: MusicExtractorProtocol,
        youtubeService: YouTubeServiceProtocol,
        authService: AuthServiceProtocol
    ) {
        self.photoService = photoService
        self.extractor = extractor
        self.youtubeService = youtubeService
        self.authService = authService
    }

    // MARK: - Setup

    func checkInitialState() {
        photoPermissionStatus = photoService.authorizationStatus()
        isYouTubeAuthenticated = authService.isAuthenticated
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
            // 1. Fetch screenshots
            let screenshots = try await photoService.fetchScreenshots()
            processingProgress = (0, screenshots.count)

            guard !screenshots.isEmpty else {
                lastError = "No screenshots found in library"
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

            // Move to processed album
            try await photoService.addAsset(asset, toAlbum: processedAlbumName)

            return ProcessingResultItem(
                assetId: asset.localIdentifier,
                status: .success,
                songTitle: metadata.songTitle,
                artist: metadata.artist,
                message: "Added to playlist"
            )

        } catch let error as MusicExtractionError {
            // Low confidence or not music - move to flagged
            try? await photoService.addAsset(asset, toAlbum: flaggedAlbumName)

            return ProcessingResultItem(
                assetId: asset.localIdentifier,
                status: .flagged,
                songTitle: nil,
                artist: nil,
                message: error.localizedDescription
            )

        } catch let error as YouTubeError {
            // YouTube error - move to flagged
            try? await photoService.addAsset(asset, toAlbum: flaggedAlbumName)

            return ProcessingResultItem(
                assetId: asset.localIdentifier,
                status: .failed,
                songTitle: nil,
                artist: nil,
                message: error.localizedDescription
            )

        } catch {
            // Other error - move to flagged
            try? await photoService.addAsset(asset, toAlbum: flaggedAlbumName)

            return ProcessingResultItem(
                assetId: asset.localIdentifier,
                status: .failed,
                songTitle: nil,
                artist: nil,
                message: error.localizedDescription
            )
        }
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

    enum Status {
        case success
        case flagged
        case failed
    }
}
