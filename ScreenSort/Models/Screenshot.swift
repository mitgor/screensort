import Foundation
import Photos

/// Domain model representing a screenshot from the photo library
struct Screenshot: Identifiable {
    /// Unique identifier (PHAsset localIdentifier)
    let id: String

    /// Underlying PHAsset
    let asset: PHAsset

    /// Screenshot creation date
    let creationDate: Date?

    /// Detected type (nil if not yet classified)
    var type: ScreenshotType?

    init(asset: PHAsset, type: ScreenshotType? = nil) {
        self.id = asset.localIdentifier
        self.asset = asset
        self.creationDate = asset.creationDate
        self.type = type
    }
}
