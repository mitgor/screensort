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
    @Published var googleDocsStatus: String?
    @Published var googleDocsError: String?

    // MARK: - Services

    nonisolated(unsafe) private let photoService: PhotoLibraryServiceProtocol
    nonisolated(unsafe) private let ocrService: OCRServiceProtocol
    nonisolated(unsafe) private let classifier: ScreenshotClassifierProtocol
    nonisolated(unsafe) private let musicExtractor: MusicExtractorProtocol
    nonisolated(unsafe) private let movieExtractor: MovieExtractorProtocol
    nonisolated(unsafe) private let bookExtractor: BookExtractorProtocol
    nonisolated(unsafe) private let youtubeService: YouTubeServiceProtocol
    nonisolated(unsafe) private let tmdbService: TMDbServiceProtocol
    nonisolated(unsafe) private let googleBooksService: GoogleBooksServiceProtocol
    nonisolated(unsafe) private let authService: AuthServiceProtocol
    nonisolated(unsafe) private let googleDocsService: GoogleDocsServiceProtocol

    // MARK: - Config

    private let playlistName = "ScreenSort"
    private let captionPrefix = "ScreenSort"

    // MARK: - Init

    nonisolated init(
        photoService: PhotoLibraryServiceProtocol,
        ocrService: OCRServiceProtocol = OCRService(),
        classifier: ScreenshotClassifierProtocol = ScreenshotClassifier(),
        musicExtractor: MusicExtractorProtocol,
        movieExtractor: MovieExtractorProtocol = MovieExtractor(),
        bookExtractor: BookExtractorProtocol = BookExtractor(),
        youtubeService: YouTubeServiceProtocol,
        tmdbService: TMDbServiceProtocol = TMDbService(),
        googleBooksService: GoogleBooksServiceProtocol = GoogleBooksService(),
        authService: AuthServiceProtocol,
        googleDocsService: GoogleDocsServiceProtocol
    ) {
        self.photoService = photoService
        self.ocrService = ocrService
        self.classifier = classifier
        self.musicExtractor = musicExtractor
        self.movieExtractor = movieExtractor
        self.bookExtractor = bookExtractor
        self.youtubeService = youtubeService
        self.tmdbService = tmdbService
        self.googleBooksService = googleBooksService
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
                let existingCaption = photoService.getCaption(for: asset)
                return existingCaption == nil || !existingCaption!.hasPrefix(captionPrefix)
            }

            processingProgress = (0, screenshots.count)

            guard !screenshots.isEmpty else {
                lastError = "No new screenshots to process"
                isProcessing = false
                return
            }

            // 2. Get/create YouTube playlist (for music)
            let playlistId = try await youtubeService.getOrCreatePlaylist(named: playlistName)

            // 3. Ensure all albums exist
            for type in ScreenshotType.allCases {
                _ = try await photoService.createAlbumIfNeeded(named: type.albumName)
            }

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

    // MARK: - Screenshot Routing

    private func processScreenshot(asset: PHAsset, playlistId: String) async -> ProcessingResultItem {
        do {
            // 1. Run OCR once
            let observations = try await ocrService.recognizeText(from: asset, minimumConfidence: 0.0)

            // 2. Classify the screenshot
            let screenshotType = classifier.classify(textObservations: observations)

            // 3. Route to appropriate handler
            switch screenshotType {
            case .music:
                return await processMusicScreenshot(asset: asset, observations: observations, playlistId: playlistId)
            case .movie:
                return await processMovieScreenshot(asset: asset, observations: observations)
            case .book:
                return await processBookScreenshot(asset: asset, observations: observations)
            case .meme:
                return await processMemeScreenshot(asset: asset)
            case .unknown:
                return await processUnknownScreenshot(asset: asset)
            }

        } catch {
            return await handleProcessingError(asset: asset, error: error)
        }
    }

    // MARK: - Music Processing

    private func processMusicScreenshot(
        asset: PHAsset,
        observations: [TextObservation],
        playlistId: String
    ) async -> ProcessingResultItem {
        do {
            // Extract metadata
            let metadata = try await musicExtractor.extractMusicMetadata(from: observations)

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
            await logToGoogleDocs(
                type: .music,
                title: metadata.songTitle,
                creator: metadata.artist,
                serviceLink: youtubeLink,
                capturedAt: asset.creationDate ?? Date()
            )

            // Move to album
            try await photoService.addAsset(asset, toAlbum: ScreenshotType.music.albumName)

            // Set caption
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
                contentType: .music,
                title: metadata.songTitle,
                creator: metadata.artist,
                message: "Added to playlist",
                serviceLink: youtubeLink
            )

        } catch {
            return await handleExtractionError(asset: asset, contentType: .music, error: error)
        }
    }

    // MARK: - Movie Processing

    private func processMovieScreenshot(
        asset: PHAsset,
        observations: [TextObservation]
    ) async -> ProcessingResultItem {
        do {
            // Extract metadata
            let metadata = try await movieExtractor.extractMovieMetadata(from: observations)

            // Try to get TMDb link (optional)
            var serviceLink: String?
            if tmdbService.isConfigured {
                do {
                    let tmdbResult = try await tmdbService.searchMovie(
                        title: metadata.title,
                        year: metadata.year
                    )
                    serviceLink = tmdbResult.tmdbURL
                } catch {
                    // TMDb is optional - continue without it
                }
            }

            // Log to Google Docs
            await logToGoogleDocs(
                type: .movie,
                title: metadata.title,
                creator: metadata.creator,
                serviceLink: serviceLink,
                capturedAt: asset.creationDate ?? Date()
            )

            // Move to album
            try await photoService.addAsset(asset, toAlbum: ScreenshotType.movie.albumName)

            // Set caption
            let caption = buildCaption(
                type: "Movie",
                title: metadata.title,
                creator: metadata.director,
                status: serviceLink != nil ? "Linked to TMDb" : "Logged"
            )
            try? await photoService.setCaption(caption, for: asset)

            return ProcessingResultItem(
                assetId: asset.localIdentifier,
                status: .success,
                contentType: .movie,
                title: metadata.title,
                creator: metadata.creator,
                message: serviceLink != nil ? "Found on TMDb" : "Logged to Google Docs",
                serviceLink: serviceLink
            )

        } catch {
            return await handleExtractionError(asset: asset, contentType: .movie, error: error)
        }
    }

    // MARK: - Book Processing

    private func processBookScreenshot(
        asset: PHAsset,
        observations: [TextObservation]
    ) async -> ProcessingResultItem {
        do {
            // Extract metadata
            let metadata = try await bookExtractor.extractBookMetadata(from: observations)

            // Try to get Google Books link
            var serviceLink: String?
            do {
                let booksResult = try await googleBooksService.searchBook(
                    title: metadata.title,
                    author: metadata.author
                )
                serviceLink = booksResult.infoLink
            } catch {
                // Google Books is optional - continue without it
            }

            // Log to Google Docs
            await logToGoogleDocs(
                type: .book,
                title: metadata.title,
                creator: metadata.creator,
                serviceLink: serviceLink,
                capturedAt: asset.creationDate ?? Date()
            )

            // Move to album
            try await photoService.addAsset(asset, toAlbum: ScreenshotType.book.albumName)

            // Set caption
            let caption = buildCaption(
                type: "Book",
                title: metadata.title,
                creator: metadata.author,
                status: serviceLink != nil ? "Linked to Google Books" : "Logged"
            )
            try? await photoService.setCaption(caption, for: asset)

            return ProcessingResultItem(
                assetId: asset.localIdentifier,
                status: .success,
                contentType: .book,
                title: metadata.title,
                creator: metadata.creator,
                message: serviceLink != nil ? "Found on Google Books" : "Logged to Google Docs",
                serviceLink: serviceLink
            )

        } catch {
            return await handleExtractionError(asset: asset, contentType: .book, error: error)
        }
    }

    // MARK: - Meme Processing

    private func processMemeScreenshot(asset: PHAsset) async -> ProcessingResultItem {
        // Memes just get moved to album - no extraction or logging
        do {
            try await photoService.addAsset(asset, toAlbum: ScreenshotType.meme.albumName)

            let caption = buildCaption(
                type: "Meme",
                title: nil,
                creator: nil,
                status: "Saved to album"
            )
            try? await photoService.setCaption(caption, for: asset)

            return ProcessingResultItem(
                assetId: asset.localIdentifier,
                status: .success,
                contentType: .meme,
                title: "Meme",
                creator: nil,
                message: "Saved to Memes album",
                serviceLink: nil
            )
        } catch {
            return ProcessingResultItem(
                assetId: asset.localIdentifier,
                status: .failed,
                contentType: .meme,
                title: nil,
                creator: nil,
                message: error.localizedDescription,
                serviceLink: nil
            )
        }
    }

    // MARK: - Unknown Processing

    private func processUnknownScreenshot(asset: PHAsset) async -> ProcessingResultItem {
        do {
            try await photoService.addAsset(asset, toAlbum: ScreenshotType.unknown.albumName)

            let caption = buildCaption(
                type: "Unknown",
                title: nil,
                creator: nil,
                status: "Could not classify"
            )
            try? await photoService.setCaption(caption, for: asset)

            return ProcessingResultItem(
                assetId: asset.localIdentifier,
                status: .flagged,
                contentType: .unknown,
                title: nil,
                creator: nil,
                message: "Could not classify screenshot",
                serviceLink: nil
            )
        } catch {
            return ProcessingResultItem(
                assetId: asset.localIdentifier,
                status: .failed,
                contentType: .unknown,
                title: nil,
                creator: nil,
                message: error.localizedDescription,
                serviceLink: nil
            )
        }
    }

    // MARK: - Error Handling

    private func handleExtractionError(
        asset: PHAsset,
        contentType: ScreenshotType,
        error: Error
    ) async -> ProcessingResultItem {
        // Move to flagged album
        try? await photoService.addAsset(asset, toAlbum: ScreenshotType.unknown.albumName)

        let caption = buildCaption(
            type: contentType.displayName,
            title: nil,
            creator: nil,
            status: "Failed: \(error.localizedDescription)"
        )
        try? await photoService.setCaption(caption, for: asset)

        return ProcessingResultItem(
            assetId: asset.localIdentifier,
            status: .flagged,
            contentType: contentType,
            title: nil,
            creator: nil,
            message: error.localizedDescription,
            serviceLink: nil
        )
    }

    private func handleProcessingError(asset: PHAsset, error: Error) async -> ProcessingResultItem {
        try? await photoService.addAsset(asset, toAlbum: ScreenshotType.unknown.albumName)

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
            contentType: .unknown,
            title: nil,
            creator: nil,
            message: error.localizedDescription,
            serviceLink: nil
        )
    }

    // MARK: - Google Docs Logging

    private func logToGoogleDocs(
        type: ContentLogEntry.ContentType,
        title: String,
        creator: String,
        serviceLink: String?,
        capturedAt: Date
    ) async {
        let logEntry = ContentLogEntry(
            type: type,
            title: title,
            creator: creator,
            serviceLink: serviceLink,
            capturedAt: capturedAt
        )

        do {
            let wasAdded = try await googleDocsService.appendEntry(logEntry)
            await MainActor.run {
                googleDocURL = googleDocsService.documentURL
                googleDocsStatus = wasAdded ? "Logged to Google Doc" : "Already in Google Doc"
                googleDocsError = nil
            }
        } catch {
            await MainActor.run {
                googleDocsError = "Google Docs: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Caption Building

    private func buildCaption(type: String, title: String?, creator: String?, status: String) -> String {
        var parts = ["\(captionPrefix): \(type)"]

        if let title = title {
            parts.append("Title: \(title)")
        }
        if let creator = creator {
            parts.append("Creator: \(creator)")
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
    let contentType: ScreenshotType
    let title: String?
    let creator: String?
    let message: String
    let serviceLink: String?

    enum Status {
        case success
        case flagged
        case failed
    }
}
