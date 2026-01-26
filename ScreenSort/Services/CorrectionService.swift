import Foundation
import Photos

/// Errors that can occur during correction application
enum CorrectionError: Error, LocalizedError {
    case assetNotFound
    case albumOperationFailed(String)
    case captionUpdateFailed(String)

    var errorDescription: String? {
        switch self {
        case .assetNotFound:
            return "The screenshot could not be found in your photo library"
        case .albumOperationFailed(let reason):
            return "Failed to update album: \(reason)"
        case .captionUpdateFailed(let reason):
            return "Failed to update caption: \(reason)"
        }
    }
}

/// Service that applies user corrections to the photo library
/// Moves photos between albums and updates captions
@MainActor
final class CorrectionService {

    // MARK: - Configuration

    private let captionPrefix = "ScreenSort"

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

    // MARK: - Public API

    /// Apply a correction to move photo to correct album and update caption
    /// - Parameters:
    ///   - correction: The correction to apply
    ///   - asset: The PHAsset to correct
    func applyCorrection(_ correction: Correction, for asset: PHAsset) async throws {
        print("🔄 [CorrectionService] Applying correction for asset: \(asset.localIdentifier)")

        // 1. Remove from old album (if category changed)
        if correction.categoryChanged {
            let oldAlbum = correction.originalType.albumName
            try await photoService.removeAsset(asset, fromAlbum: oldAlbum)
            print("📁 [CorrectionService] Removed from: \(oldAlbum)")
        }

        // 2. Add to new album
        let newAlbum = correction.correctedType.albumName
        try await photoService.addAsset(asset, toAlbum: newAlbum)
        print("📁 [CorrectionService] Added to: \(newAlbum)")

        // 3. Update caption
        let caption = buildCorrectedCaption(correction)
        try await photoService.setCaption(caption, for: asset)
        print("📝 [CorrectionService] Updated caption: \(caption)")

        // 4. Save correction to store (mark as applied)
        let appliedCorrection = correction.asApplied()
        correctionStore.saveCorrection(appliedCorrection)
        print("✅ [CorrectionService] Correction saved and applied")
    }

    /// Revert a correction (move photo back to original album)
    /// - Parameter assetId: The asset ID to revert
    func revertCorrection(for assetId: String) async throws {
        guard let correction = correctionStore.loadCorrection(for: assetId) else {
            return
        }

        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
        guard let asset = fetchResult.firstObject else {
            throw CorrectionError.assetNotFound
        }

        // Remove from corrected album
        try await photoService.removeAsset(asset, fromAlbum: correction.correctedType.albumName)

        // Add back to original album
        try await photoService.addAsset(asset, toAlbum: correction.originalType.albumName)

        // Update caption to original
        let caption = buildOriginalCaption(correction)
        try await photoService.setCaption(caption, for: asset)

        // Remove correction from store
        correctionStore.deleteCorrection(for: assetId)
    }

    /// Get all pending (unapplied) corrections
    func pendingCorrections() -> [Correction] {
        correctionStore.loadAllCorrections().filter { !$0.isApplied }
    }

    /// Get count of pending corrections
    func pendingCount() -> Int {
        correctionStore.unappliedCount()
    }

    // MARK: - Caption Building

    private func buildCorrectedCaption(_ correction: Correction) -> String {
        var parts = ["\(captionPrefix): \(correction.correctedType.displayName)"]

        if let title = correction.correctedTitle {
            parts.append("Title: \(title)")
        }

        if let creator = correction.correctedCreator {
            parts.append("Creator: \(creator)")
        }

        parts.append("Status: User Corrected")

        return parts.joined(separator: " | ")
    }

    private func buildOriginalCaption(_ correction: Correction) -> String {
        var parts = ["\(captionPrefix): \(correction.originalType.displayName)"]

        if let title = correction.originalTitle {
            parts.append("Title: \(title)")
        }

        if let creator = correction.originalCreator {
            parts.append("Creator: \(creator)")
        }

        parts.append("Status: Reverted")

        return parts.joined(separator: " | ")
    }
}
