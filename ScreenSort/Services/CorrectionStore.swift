import Foundation

/// Persists user corrections to UserDefaults
/// Follows the same pattern as caption storage in PhotoLibraryService
final class CorrectionStore: Sendable {

    // MARK: - Configuration

    private static let storageKey = "ScreenSort.UserCorrections"

    // MARK: - Singleton

    static let shared = CorrectionStore()

    private init() {}

    // MARK: - Public API

    /// Save a correction (creates new or updates existing)
    func saveCorrection(_ correction: Correction) {
        var corrections = loadAllCorrectionsDict()
        corrections[correction.assetId] = correction
        saveCorrectionsDict(corrections)
    }

    /// Load correction for a specific asset
    func loadCorrection(for assetId: String) -> Correction? {
        let corrections = loadAllCorrectionsDict()
        return corrections[assetId]
    }

    /// Load all corrections as an array
    func loadAllCorrections() -> [Correction] {
        return Array(loadAllCorrectionsDict().values)
            .sorted { $0.createdAt > $1.createdAt }
    }

    /// Check if asset has been corrected
    func hasCorrection(for assetId: String) -> Bool {
        return loadCorrection(for: assetId) != nil
    }

    /// Delete a correction
    func deleteCorrection(for assetId: String) {
        var corrections = loadAllCorrectionsDict()
        corrections.removeValue(forKey: assetId)
        saveCorrectionsDict(corrections)
    }

    /// Delete all corrections
    func deleteAllCorrections() {
        UserDefaults.standard.removeObject(forKey: Self.storageKey)
    }

    /// Mark a correction as applied
    func markAsApplied(assetId: String) {
        guard var correction = loadCorrection(for: assetId) else { return }
        correction.isApplied = true
        saveCorrection(correction)
    }

    /// Get count of unapplied corrections
    func unappliedCount() -> Int {
        loadAllCorrections().filter { !$0.isApplied }.count
    }

    // MARK: - Private Helpers

    private func loadAllCorrectionsDict() -> [String: Correction] {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey) else {
            return [:]
        }

        do {
            let corrections = try JSONDecoder().decode([String: Correction].self, from: data)
            return corrections
        } catch {
            print("⚠️ CorrectionStore: Failed to decode corrections: \(error)")
            return [:]
        }
    }

    private func saveCorrectionsDict(_ corrections: [String: Correction]) {
        do {
            let data = try JSONEncoder().encode(corrections)
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        } catch {
            print("⚠️ CorrectionStore: Failed to encode corrections: \(error)")
        }
    }
}

// MARK: - Correction Extension for Mutability

extension Correction {
    /// Create a copy with isApplied set to true
    func asApplied() -> Correction {
        var copy = self
        copy.isApplied = true
        return copy
    }
}
