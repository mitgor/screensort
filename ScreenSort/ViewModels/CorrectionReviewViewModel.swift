import SwiftUI
import Photos
import Observation

/// Filter options for the review list
enum ReviewFilter: String, CaseIterable {
    case all = "All"
    case flagged = "Flagged"
    case music = "Music"
    case movies = "Movies"
    case books = "Books"
    case memes = "Memes"

    var screenshotType: ScreenshotType? {
        switch self {
        case .all: return nil
        case .flagged: return .unknown
        case .music: return .music
        case .movies: return .movie
        case .books: return .book
        case .memes: return .meme
        }
    }

    var iconName: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .flagged: return "flag.fill"
        case .music: return "music.note"
        case .movies: return "film"
        case .books: return "book"
        case .memes: return "face.smiling"
        }
    }
}

@MainActor
@Observable
final class CorrectionReviewViewModel {

    // MARK: - Observable State

    var results: [ProcessingResultItem] = []
    var selectedFilter: ReviewFilter = .all
    var selectedResult: ProcessingResultItem?
    var showingCorrectionSheet = false
    var isApplyingCorrection = false
    var lastError: String?

    // Assets cache
    private var assetsCache: [String: PHAsset] = [:]

    // OCR snapshots from processing
    private var ocrSnapshots: [String: [String]] = [:]

    // MARK: - Services

    private let photoService: PhotoLibraryServiceProtocol
    private let correctionStore: CorrectionStore

    // MARK: - Init

    init(
        photoService: PhotoLibraryServiceProtocol? = nil,
        correctionStore: CorrectionStore = .shared
    ) {
        self.photoService = photoService ?? PhotoLibraryService()
        self.correctionStore = correctionStore
    }

    // MARK: - Computed Properties

    var filteredResults: [ProcessingResultItem] {
        guard selectedFilter != .all else { return results }

        if selectedFilter == .flagged {
            return results.filter { $0.status == .flagged || $0.contentType == .unknown }
        }

        guard let type = selectedFilter.screenshotType else { return results }
        return results.filter { $0.contentType == type }
    }

    var filterCounts: [ReviewFilter: Int] {
        var counts: [ReviewFilter: Int] = [:]
        counts[.all] = results.count
        counts[.flagged] = results.filter { $0.status == .flagged || $0.contentType == .unknown }.count
        counts[.music] = results.filter { $0.contentType == .music }.count
        counts[.movies] = results.filter { $0.contentType == .movie }.count
        counts[.books] = results.filter { $0.contentType == .book }.count
        counts[.memes] = results.filter { $0.contentType == .meme }.count
        return counts
    }

    // MARK: - Public Methods

    /// Load results from a processing session
    func loadResults(_ processingResults: [ProcessingResultItem], ocrSnapshots: [String: [String]] = [:]) {
        self.results = processingResults
        self.ocrSnapshots = ocrSnapshots
        Task {
            await prefetchAssets()
        }
    }

    /// Get OCR snapshot for a result
    func getOCRSnapshot(for result: ProcessingResultItem) -> [String] {
        ocrSnapshots[result.assetId] ?? []
    }

    /// Get cached asset for a result
    func asset(for result: ProcessingResultItem) -> PHAsset? {
        assetsCache[result.assetId]
    }

    /// Check if result has a correction
    func hasCorrection(for result: ProcessingResultItem) -> Bool {
        correctionStore.hasCorrection(for: result.assetId)
    }

    /// Get existing correction for a result
    func getCorrection(for result: ProcessingResultItem) -> Correction? {
        correctionStore.loadCorrection(for: result.assetId)
    }

    /// Open correction sheet for a result
    func selectForCorrection(_ result: ProcessingResultItem) {
        selectedResult = result
        showingCorrectionSheet = true
    }

    /// Dismiss correction sheet
    func dismissCorrectionSheet() {
        showingCorrectionSheet = false
        selectedResult = nil
    }

    // MARK: - Private Methods

    private func prefetchAssets() async {
        let assetIds = results.map { $0.assetId }

        let fetchResult = PHAsset.fetchAssets(
            withLocalIdentifiers: assetIds,
            options: nil
        )

        let assets = fetchResult.objects(at: IndexSet(integersIn: 0..<fetchResult.count))

        for asset in assets {
            assetsCache[asset.localIdentifier] = asset
        }
    }
}
