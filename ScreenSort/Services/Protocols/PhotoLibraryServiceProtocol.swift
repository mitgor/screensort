import Photos

@MainActor
protocol PhotoLibraryServiceProtocol {
    /// Check current authorization status
    func authorizationStatus() -> PHAuthorizationStatus

    /// Request photo library access, returns granted status
    func requestAuthorization() async -> PHAuthorizationStatus

    /// Fetch all screenshots from library, sorted by creation date descending
    func fetchScreenshots() async throws -> [PHAsset]

    /// Create album if it doesn't exist, returns the album
    func createAlbumIfNeeded(named: String) async throws -> PHAssetCollection

    /// Add asset to specified album
    func addAsset(_ asset: PHAsset, toAlbum albumName: String) async throws

    /// Check if we have full or limited access
    var hasFullAccess: Bool { get }

    /// Start observing photo library for new screenshots
    /// Returns AsyncStream that emits arrays of new PHAssets
    func observeNewScreenshots() -> AsyncStream<[PHAsset]>

    /// Stop observing (cleanup)
    func stopObserving()
}
