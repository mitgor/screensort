import Photos
import Foundation
import ImageIO
import UniformTypeIdentifiers

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

    func removeAsset(_ asset: PHAsset, fromAlbum albumName: String) async throws {
        // Find the album
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title = %@", albumName)
        let albums = PHAssetCollection.fetchAssetCollections(
            with: .album,
            subtype: .albumRegular,
            options: fetchOptions
        )

        guard let album = albums.firstObject else {
            // Album doesn't exist, nothing to remove from
            return
        }

        // Remove asset from album (does not delete the photo)
        do {
            try await PHPhotoLibrary.shared().performChanges {
                guard let albumChangeRequest = PHAssetCollectionChangeRequest(for: album) else {
                    return
                }
                albumChangeRequest.removeAssets([asset] as NSArray)
            }
        } catch {
            throw PhotoLibraryError.moveToAlbumFailed(reason: "Failed to remove from album: \(error.localizedDescription)")
        }
    }

    // MARK: - Caption Management (stored in UserDefaults)

    private static let captionStorageKey = "ScreenSort.ProcessedCaptions"

    func setCaption(_ caption: String, for asset: PHAsset) async throws {
        var captions = Self.loadCaptions()
        captions[asset.localIdentifier] = caption
        Self.saveCaptions(captions)
    }

    func getCaption(for asset: PHAsset) -> String? {
        let captions = Self.loadCaptions()
        return captions[asset.localIdentifier]
    }

    private static func loadCaptions() -> [String: String] {
        UserDefaults.standard.dictionary(forKey: captionStorageKey) as? [String: String] ?? [:]
    }

    private static func saveCaptions(_ captions: [String: String]) {
        UserDefaults.standard.set(captions, forKey: captionStorageKey)
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
