import Photos
import Foundation

@MainActor
class PhotoLibraryService: NSObject, PhotoLibraryServiceProtocol {
    // MARK: - Properties for change observation
    private var screenshotFetchResult: PHFetchResult<PHAsset>?
    private var continuation: AsyncStream<[PHAsset]>.Continuation?

    // MARK: - Authorization

    func authorizationStatus() -> PHAuthorizationStatus {
        return PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    func requestAuthorization() async -> PHAuthorizationStatus {
        return await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    }

    var hasFullAccess: Bool {
        return authorizationStatus() == .authorized
    }

    // MARK: - Screenshot Fetching

    func fetchScreenshots() async throws -> [PHAsset] {
        // Check authorization
        guard authorizationStatus() == .authorized || authorizationStatus() == .limited else {
            throw PhotoLibraryError.accessDenied
        }

        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(
            format: "(mediaSubtype & %d) != 0",
            PHAssetMediaSubtype.photoScreenshot.rawValue
        )
        fetchOptions.sortDescriptors = [
            NSSortDescriptor(key: "creationDate", ascending: false)
        ]

        let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        let assets = fetchResult.objects(at: IndexSet(integersIn: 0..<fetchResult.count))

        return assets
    }

    // MARK: - Album Management

    func createAlbumIfNeeded(named title: String) async throws -> PHAssetCollection {
        // Check if album exists
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title = %@", title)
        let existingAlbums = PHAssetCollection.fetchAssetCollections(
            with: .album,
            subtype: .albumRegular,
            options: fetchOptions
        )

        if let existingAlbum = existingAlbums.firstObject {
            return existingAlbum
        }

        // Create new album
        var localIdentifier: String?

        do {
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: title)
                localIdentifier = request.placeholderForCreatedAssetCollection.localIdentifier
            }
        } catch {
            throw PhotoLibraryError.albumCreationFailed(reason: error.localizedDescription)
        }

        // Fetch the newly created album
        guard let identifier = localIdentifier,
              let newAlbum = PHAssetCollection.fetchAssetCollections(
                withLocalIdentifiers: [identifier],
                options: nil
              ).firstObject else {
            throw PhotoLibraryError.albumCreationFailed(reason: "Failed to fetch newly created album")
        }

        return newAlbum
    }

    func addAsset(_ asset: PHAsset, toAlbum albumName: String) async throws {
        // Ensure album exists
        let album = try await createAlbumIfNeeded(named: albumName)

        // Add asset to album
        do {
            try await PHPhotoLibrary.shared().performChanges {
                guard let albumChangeRequest = PHAssetCollectionChangeRequest(for: album) else {
                    return
                }
                albumChangeRequest.addAssets([asset] as NSArray)
            }
        } catch {
            throw PhotoLibraryError.moveToAlbumFailed(reason: error.localizedDescription)
        }
    }

    // MARK: - Caption Management (undocumented API - personal use only)

    func setCaption(_ caption: String, for asset: PHAsset) async throws {
        do {
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetChangeRequest(for: asset)
                // Using undocumented accessibilityDescription property
                // This sets the caption visible in Photos app
                request.setValue(caption, forKey: "accessibilityDescription")
            }
        } catch {
            throw PhotoLibraryError.captionUpdateFailed(reason: error.localizedDescription)
        }
    }

    func getCaption(for asset: PHAsset) -> String? {
        // Using undocumented accessibilityDescription property
        return asset.value(forKey: "accessibilityDescription") as? String
    }

    // MARK: - Photo Library Change Observation

    func observeNewScreenshots() -> AsyncStream<[PHAsset]> {
        // Register as observer
        PHPhotoLibrary.shared().register(self)

        // Perform initial fetch and store
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(
            format: "(mediaSubtype & %d) != 0",
            PHAssetMediaSubtype.photoScreenshot.rawValue
        )
        fetchOptions.sortDescriptors = [
            NSSortDescriptor(key: "creationDate", ascending: false)
        ]

        self.screenshotFetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)

        // Create and return AsyncStream
        return AsyncStream { continuation in
            self.continuation = continuation

            // Set termination handler
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor in
                    self?.stopObserving()
                }
            }
        }
    }

    func stopObserving() {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
        continuation?.finish()
        continuation = nil
        screenshotFetchResult = nil
    }
}

// MARK: - PHPhotoLibraryChangeObserver

extension PhotoLibraryService: PHPhotoLibraryChangeObserver {
    nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor in
            guard let fetchResult = self.screenshotFetchResult,
                  let changes = changeInstance.changeDetails(for: fetchResult) else {
                return
            }

            // Update fetch result to latest state
            self.screenshotFetchResult = changes.fetchResultAfterChanges

            // Check for newly inserted assets
            if changes.hasIncrementalChanges, let insertedIndexes = changes.insertedIndexes, !insertedIndexes.isEmpty {
                let newAssets = insertedIndexes.map { changes.fetchResultAfterChanges.object(at: $0) }

                // Yield new assets to continuation
                self.continuation?.yield(newAssets)
            }
        }
    }
}
