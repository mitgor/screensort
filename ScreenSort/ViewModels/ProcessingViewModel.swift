import SwiftUI
import Photos
import Observation
import UIKit

@MainActor
@Observable
final class ProcessingViewModel {

    // MARK: - Observable State

    var photoPermissionStatus: PHAuthorizationStatus = .notDetermined
    var isYouTubeAuthenticated = false
    var isProcessing = false
    var processingProgress: (current: Int, total: Int) = (0, 0)
    var lastError: String?
    var results: [ProcessingResultItem] = []
    var googleDocURL: String?
    var googleDocsStatus: String?
    var googleDocsError: String?

    private var processingTask: Task<Void, Never>?

    /// OCR text snapshots for potential correction learning
    /// Key: asset localIdentifier, Value: array of recognized text strings
    private(set) var ocrSnapshots: [String: [String]] = [:]

    // MARK: - Services

    private let photoService: PhotoLibraryServiceProtocol
    private let ocrService: OCRServiceProtocol
    private let classifier: ScreenshotClassifierProtocol
    private let musicExtractor: MusicExtractorProtocol
    private let movieExtractor: MovieExtractorProtocol
    private let bookExtractor: BookExtractorProtocol
    private let youtubeService: YouTubeServiceProtocol
    private let tmdbService: TMDbServiceProtocol
    private let googleBooksService: GoogleBooksServiceProtocol
    private let authService: AuthServiceProtocol
    private let googleDocsService: GoogleDocsServiceProtocol

    // MARK: - Config

    private let playlistName = "ScreenSort"
    private let captionPrefix = "ScreenSort"

    // MARK: - Init

    init(
        photoService: PhotoLibraryServiceProtocol,
        ocrService: OCRServiceProtocol,
        classifier: ScreenshotClassifierProtocol,
        musicExtractor: MusicExtractorProtocol,
        movieExtractor: MovieExtractorProtocol,
        bookExtractor: BookExtractorProtocol,
        youtubeService: YouTubeServiceProtocol,
        tmdbService: TMDbServiceProtocol,
        googleBooksService: GoogleBooksServiceProtocol,
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

    /// Convenience initializer with default production services.
    convenience init() {
        let authService = AuthService()
        self.init(
            photoService: PhotoLibraryService(),
            ocrService: OCRService(),
            classifier: ScreenshotClassifier(),
            musicExtractor: MusicExtractor(),
            movieExtractor: MovieExtractor(),
            bookExtractor: BookExtractor(),
            youtubeService: YouTubeService(authService: authService),
            tmdbService: TMDbService(),
            googleBooksService: GoogleBooksService(authService: authService),
            authService: authService,
            googleDocsService: GoogleDocsService(authService: authService)
        )
    }

    // MARK: - Computed Properties

    var hasPhotoAccess: Bool {
        photoPermissionStatus == .authorized || photoPermissionStatus == .limited
    }

    var canProcess: Bool {
        hasPhotoAccess && isYouTubeAuthenticated && !isProcessing
    }

    // Pre-computed result counts to avoid filtering in view body
    var successCount: Int {
        results.filter { $0.status == .success }.count
    }

    var flaggedCount: Int {
        results.filter { $0.status == .flagged }.count
    }

    var failedCount: Int {
        results.filter { $0.status == .failed }.count
    }

    var unknownCount: Int {
        results.filter { $0.contentType == .unknown }.count
    }

    var successResults: [ProcessingResultItem] {
        results.filter { $0.status == .success && $0.title != nil }
    }

    var successCountByType: [ScreenshotType: Int] {
        Dictionary(grouping: results.filter { $0.status == .success }) { $0.contentType }
            .mapValues { $0.count }
    }

    // MARK: - Setup

    func checkInitialState() {
        photoPermissionStatus = photoService.authorizationStatus()
        isYouTubeAuthenticated = authService.isAuthenticated
        googleDocURL = googleDocsService.documentURL

        // Load cached results from previous session
        let cachedResults = ProcessedScreenshotStore.shared.loadResults()
        if !cachedResults.isEmpty {
            self.results = cachedResults
        }
        print("[ProcessingViewModel] Loaded \(cachedResults.count) cached results, \(ProcessedScreenshotStore.shared.loadProcessedIDs().count) processed IDs")

        // Clean up stale entries for deleted photos (async, non-blocking)
        Task {
            ProcessedScreenshotStore.shared.cleanupDeletedAssets()
        }
    }

    // MARK: - Photo Permissions

    func requestPhotoAccess() async {
        photoPermissionStatus = await photoService.requestAuthorization()
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

    func cancelProcessing() {
        processingTask?.cancel()
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
        ocrSnapshots = [:]
        lastError = nil

        // Prevent device from sleeping during processing
        UIApplication.shared.isIdleTimerDisabled = true

        defer {
            // Re-enable sleep when done
            UIApplication.shared.isIdleTimerDisabled = false
            processingTask = nil
            isProcessing = false
            print("[ProcessingViewModel] Processing finished")
        }

        do {
            print("[ProcessingViewModel] Fetching screenshots...")
            // 1. Fetch screenshots (excluding already processed ones)
            let allScreenshots = try await photoService.fetchScreenshots()
            print("[ProcessingViewModel] Found \(allScreenshots.count) total screenshots")

            let screenshots = allScreenshots.filter { asset in
                guard let caption = photoService.getCaption(for: asset) else { return true }
                return !caption.hasPrefix(captionPrefix)
            }
            print("[ProcessingViewModel] \(screenshots.count) new screenshots to process")

            processingProgress = (0, screenshots.count)

            guard !screenshots.isEmpty else {
                lastError = "No new screenshots to process"
                return
            }

            print("[ProcessingViewModel] Getting/creating YouTube playlist...")
            // 2. Get/create YouTube playlist (for music)
            let playlistId = try await youtubeService.getOrCreatePlaylist(named: playlistName)
            print("[ProcessingViewModel] Playlist ID: \(playlistId)")

            print("[ProcessingViewModel] Creating albums...")
            // 3. Create all albums in parallel using TaskGroup
            try await withThrowingTaskGroup(of: Void.self) { group in
                for type in ScreenshotType.allCases {
                    group.addTask { [photoService] in
                        _ = try await photoService.createAlbumIfNeeded(named: type.albumName)
                    }
                }
                try await group.waitForAll()
            }
            print("[ProcessingViewModel] Albums created")

            // 4. Process each screenshot with cancellation support
            print("[ProcessingViewModel] Starting screenshot processing...")
            processingTask = Task {
                for (index, asset) in screenshots.enumerated() {
                    // Check cancellation BEFORE expensive work
                    guard !Task.isCancelled else {
                        print("[ProcessingViewModel] Processing cancelled at item \(index)")
                        break
                    }

                    processingProgress = (index + 1, screenshots.count)
                    print("[ProcessingViewModel] Processing \(index + 1)/\(screenshots.count)")
                    let result = await processScreenshot(asset: asset, playlistId: playlistId)
                    results.append(result)
                    print("[ProcessingViewModel] Result: \(result.contentType) - \(result.status)")
                }
            }

            await processingTask?.value

            // Update Google Doc URL if available
            googleDocURL = googleDocsService.documentURL

        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Screenshot Routing

    private func processScreenshot(asset: PHAsset, playlistId: String) async -> ProcessingResultItem {
        do {
            // 1. Run OCR once
            let observations = try await ocrService.recognizeText(from: asset, minimumConfidence: 0.0)

            // Store OCR snapshot for potential correction learning
            let ocrText = observations.map { $0.text }
            ocrSnapshots[asset.localIdentifier] = ocrText

            // 2. Classify the screenshot (using AI when available)
            let screenshotType = await classifier.classifyWithAI(textObservations: observations)

            // 3. Route to appropriate handler
            return switch screenshotType {
            case .music:
                await processMusicScreenshot(asset: asset, observations: observations, playlistId: playlistId)
            case .movie:
                await processMovieScreenshot(asset: asset, observations: observations)
            case .book:
                await processBookScreenshot(asset: asset, observations: observations)
            case .meme:
                await processMemeScreenshot(asset: asset)
            case .unknown:
                await processUnknownScreenshot(asset: asset)
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
            let metadata = try await musicExtractor.extractMusicMetadata(from: observations)

            let videoId = try await youtubeService.searchForSong(
                title: metadata.songTitle,
                artist: metadata.artist
            )

            try await youtubeService.addToPlaylist(videoId: videoId, playlistId: playlistId)

            let youtubeLink = "https://youtube.com/watch?v=\(videoId)"

            await logToGoogleDocs(
                type: .music,
                title: metadata.songTitle,
                creator: metadata.artist,
                serviceLink: youtubeLink,
                capturedAt: asset.creationDate ?? .now
            )

            try await photoService.addAsset(asset, toAlbum: ScreenshotType.music.albumName)

            let caption = buildCaption(type: "Music", title: metadata.songTitle, creator: metadata.artist, status: "Added to YouTube")
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
            let metadata = try await movieExtractor.extractMovieMetadata(from: observations)

            var serviceLink: String?
            if tmdbService.isConfigured {
                serviceLink = try? await tmdbService.searchMovie(title: metadata.title, year: metadata.year).tmdbURL
            }

            await logToGoogleDocs(
                type: .movie,
                title: metadata.title,
                creator: metadata.creator,
                serviceLink: serviceLink,
                capturedAt: asset.creationDate ?? .now
            )

            try await photoService.addAsset(asset, toAlbum: ScreenshotType.movie.albumName)

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
            let metadata = try await bookExtractor.extractBookMetadata(from: observations)

            let serviceLink = try? await googleBooksService.searchBook(title: metadata.title, author: metadata.author).infoLink

            await logToGoogleDocs(
                type: .book,
                title: metadata.title,
                creator: metadata.creator,
                serviceLink: serviceLink,
                capturedAt: asset.creationDate ?? .now
            )

            try await photoService.addAsset(asset, toAlbum: ScreenshotType.book.albumName)

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
        do {
            try await photoService.addAsset(asset, toAlbum: ScreenshotType.meme.albumName)

            let caption = buildCaption(type: "Meme", title: nil, creator: nil, status: "Saved to album")
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
        // Do NOT move to any album - leave in original location (ORG-01)
        let caption = buildCaption(type: "Unknown", title: nil, creator: nil, status: "Could not classify")
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
    }

    // MARK: - Error Handling

    private func handleExtractionError(
        asset: PHAsset,
        contentType: ScreenshotType,
        error: Error
    ) async -> ProcessingResultItem {
        // Do NOT move to any album - leave in original location (ORG-01)
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
        // Do NOT move to any album - leave in original location (ORG-01)
        let caption = buildCaption(type: "Unknown", title: nil, creator: nil, status: "Error: \(error.localizedDescription)")
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
            googleDocURL = googleDocsService.documentURL
            googleDocsStatus = wasAdded ? "Logged to Google Doc" : "Already in Google Doc"
            googleDocsError = nil
        } catch {
            googleDocsError = "Google Docs: \(error.localizedDescription)"
        }
    }

    // MARK: - Caption Building

    private func buildCaption(type: String, title: String?, creator: String?, status: String) -> String {
        var parts = ["\(captionPrefix): \(type)"]
        if let title { parts.append("Title: \(title)") }
        if let creator { parts.append("Creator: \(creator)") }
        parts.append("Status: \(status)")
        return parts.joined(separator: " | ")
    }
}

// MARK: - Result Item

struct ProcessingResultItem: Identifiable, Codable, Sendable {
    let id: UUID
    let assetId: String
    let status: Status
    let contentType: ScreenshotType
    let title: String?
    let creator: String?
    let message: String
    let serviceLink: String?

    init(
        assetId: String,
        status: Status,
        contentType: ScreenshotType,
        title: String?,
        creator: String?,
        message: String,
        serviceLink: String?
    ) {
        self.id = UUID()
        self.assetId = assetId
        self.status = status
        self.contentType = contentType
        self.title = title
        self.creator = creator
        self.message = message
        self.serviceLink = serviceLink
    }

    enum Status: String, Codable, Sendable {
        case success
        case flagged
        case failed
    }
}
