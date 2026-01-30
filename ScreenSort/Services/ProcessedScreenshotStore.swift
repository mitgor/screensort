import Foundation
import Photos

/// Persists processed screenshot IDs and cached results to UserDefaults
/// Follows the same pattern as CorrectionStore
final class ProcessedScreenshotStore: Sendable {

    // MARK: - Configuration

    private static let processedIDsKey = "ScreenSort.ProcessedIDs"
    private static let cachedResultsKey = "ScreenSort.CachedResults"

    // MARK: - Singleton

    static let shared = ProcessedScreenshotStore()

    private init() {}

    // MARK: - ID Tracking

    /// Mark an asset as processed
    func markAsProcessed(_ assetId: String) {
        var ids = loadProcessedIDs()
        ids.insert(assetId)
        saveProcessedIDs(ids)
    }

    /// Check if an asset has been processed
    func isProcessed(_ assetId: String) -> Bool {
        loadProcessedIDs().contains(assetId)
    }

    /// Load all processed asset IDs
    func loadProcessedIDs() -> Set<String> {
        guard let array = UserDefaults.standard.array(forKey: Self.processedIDsKey) as? [String] else {
            return []
        }
        return Set(array)
    }

    /// Save processed IDs to UserDefaults
    private func saveProcessedIDs(_ ids: Set<String>) {
        let array = Array(ids)
        UserDefaults.standard.set(array, forKey: Self.processedIDsKey)
    }

    // MARK: - Results Persistence

    /// Save processing results to UserDefaults
    func saveResults(_ results: [ProcessingResultItem]) {
        do {
            let data = try JSONEncoder().encode(results)
            UserDefaults.standard.set(data, forKey: Self.cachedResultsKey)
        } catch {
            print("⚠️ ProcessedScreenshotStore: Failed to encode results: \(error)")
        }
    }

    /// Load cached processing results
    func loadResults() -> [ProcessingResultItem] {
        guard let data = UserDefaults.standard.data(forKey: Self.cachedResultsKey) else {
            return []
        }

        do {
            return try JSONDecoder().decode([ProcessingResultItem].self, from: data)
        } catch {
            print("⚠️ ProcessedScreenshotStore: Failed to decode results: \(error)")
            return []
        }
    }

    // MARK: - Cache Invalidation

    /// Remove IDs and results for assets that no longer exist in the photo library
    func cleanupDeletedAssets() {
        let processedIDs = loadProcessedIDs()
        guard !processedIDs.isEmpty else { return }

        // Fetch existing assets
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: Array(processedIDs), options: nil)
        var existingIDs = Set<String>()
        fetchResult.enumerateObjects { asset, _, _ in
            existingIDs.insert(asset.localIdentifier)
        }

        // Find stale IDs
        let staleIDs = processedIDs.subtracting(existingIDs)
        guard !staleIDs.isEmpty else { return }

        // Remove stale IDs from processed set
        let updatedIDs = processedIDs.subtracting(staleIDs)
        saveProcessedIDs(updatedIDs)

        // Remove stale results
        var results = loadResults()
        results.removeAll { staleIDs.contains($0.assetId) }
        saveResults(results)

        print("⚠️ ProcessedScreenshotStore: Cleaned up \(staleIDs.count) deleted assets")
    }
}
