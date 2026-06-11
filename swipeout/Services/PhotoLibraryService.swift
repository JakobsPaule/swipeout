//
//  PhotoLibraryService.swift
//  swipeout (SwipeClean)
//
//  All PhotoKit interaction lives here: permissions, fetching assets and
//  albums, efficient image loading with caching, byte-size estimation, and
//  safe deletion (assets go to iOS "Recently Deleted").
//
//  Everything happens locally on device. No network, no analytics.
//

import Foundation
import Photos
import UIKit

/// An album the user can browse.
struct AlbumInfo: Identifiable, Equatable {
    let id: String
    let title: String
    let estimatedCount: Int
    /// Backing collection used to fetch the album's assets.
    let collection: PHAssetCollection

    static func == (lhs: AlbumInfo, rhs: AlbumInfo) -> Bool { lhs.id == rhs.id }
}

enum PhotoLibraryError: LocalizedError {
    case accessDenied
    case deletionFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "SwipeClean doesn't have permission to access your photos."
        case .deletionFailed(let underlying):
            return "The photos couldn't be deleted: \(underlying.localizedDescription)"
        }
    }
}

/// Protocol so view models can be tested against a fake implementation.
protocol PhotoLibraryServicing: AnyObject {
    var currentAccess: LibraryAccess { get }
    func requestAccess() async -> LibraryAccess
    func fetchAlbums() -> [AlbumInfo]
    func fetchPhotos(for mode: BrowseMode) -> [PhotoItem]
    func fetchItems(withIDs ids: [String]) -> [PhotoItem]
    func loadImage(for item: PhotoItem, targetSize: CGSize) async -> UIImage?
    func estimatedBytes(for item: PhotoItem) -> Int64
    func deleteAssets(_ items: [PhotoItem]) async throws
    func startCaching(_ items: [PhotoItem])
    func stopCaching(_ items: [PhotoItem])
}

final class PhotoLibraryService: PhotoLibraryServicing {

    private let imageManager = PHCachingImageManager()
    private let cacheTargetSize: CGSize

    nonisolated init(cacheTargetSize: CGSize = CGSize(width: 1080, height: 1080)) {
        self.cacheTargetSize = cacheTargetSize
    }

    // MARK: - Permissions

    var currentAccess: LibraryAccess {
        LibraryAccess(status: PHPhotoLibrary.authorizationStatus(for: .readWrite))
    }

    func requestAccess() async -> LibraryAccess {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                continuation.resume(returning: LibraryAccess(status: status))
            }
        }
    }

    // MARK: - Fetching

    func fetchAlbums() -> [AlbumInfo] {
        var albums: [AlbumInfo] = []

        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "estimatedAssetCount > 0")

        // User-created albums.
        let userAlbums = PHAssetCollection.fetchAssetCollections(
            with: .album, subtype: .any, options: nil)
        userAlbums.enumerateObjects { collection, _, _ in
            albums.append(self.makeAlbumInfo(collection))
        }

        // Useful smart albums.
        let smartSubtypes: [PHAssetCollectionSubtype] = [
            .smartAlbumUserLibrary,
            .smartAlbumFavorites,
            .smartAlbumScreenshots,
            .smartAlbumSelfPortraits,
            .smartAlbumPanoramas,
            .smartAlbumVideos,
            .smartAlbumBursts,
            .smartAlbumRecentlyAdded
        ]
        for subtype in smartSubtypes {
            let smart = PHAssetCollection.fetchAssetCollections(
                with: .smartAlbum, subtype: subtype, options: nil)
            smart.enumerateObjects { collection, _, _ in
                let count = self.assetCount(in: collection)
                if count > 0 {
                    albums.append(self.makeAlbumInfo(collection, count: count))
                }
            }
        }

        return albums
    }

    func fetchPhotos(for mode: BrowseMode) -> [PhotoItem] {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "mediaType == %d",
                                        PHAssetMediaType.image.rawValue)

        switch mode {
        case .newestFirst:
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            return items(from: PHAsset.fetchAssets(with: options))

        case .oldestFirst:
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
            return items(from: PHAsset.fetchAssets(with: options))

        case .random:
            // Fetch then shuffle (PhotoKit can't sort randomly).
            let fetched = items(from: PHAsset.fetchAssets(with: options))
            return PhotoOrdering.order(fetched, for: .random)

        case .album(let id, _):
            guard let collection = PHAssetCollection.fetchAssetCollections(
                withLocalIdentifiers: [id], options: nil).firstObject else {
                return []
            }
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            return items(from: PHAsset.fetchAssets(in: collection, options: options))
        }
    }

    /// Fetches photo items for specific asset identifiers, preserving the order
    /// of `ids`. Missing assets (e.g. already deleted) are skipped.
    func fetchItems(withIDs ids: [String]) -> [PhotoItem] {
        guard !ids.isEmpty else { return [] }
        let result = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
        var byID: [String: PhotoItem] = [:]
        result.enumerateObjects { asset, _, _ in
            byID[asset.localIdentifier] = PhotoItem(asset: asset)
        }
        return ids.compactMap { byID[$0] }
    }

    // MARK: - Image loading (lazy, cached)

    func loadImage(for item: PhotoItem, targetSize: CGSize) async -> UIImage? {
        guard let asset = item.asset else { return nil }
        return await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .opportunistic
            options.resizeMode = .fast
            options.isNetworkAccessAllowed = true // allow iCloud download for review
            options.isSynchronous = false

            var hasResumed = false
            imageManager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFit,
                options: options
            ) { image, info in
                // opportunistic may call back twice; resume only once, on the
                // final (non-degraded) result or the first non-nil image.
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if !hasResumed && (!isDegraded || image != nil) {
                    if isDegraded { return } // wait for full-res
                    hasResumed = true
                    continuation.resume(returning: image)
                }
            }
        }
    }

    /// Prefetch images to keep swiping smooth on large libraries.
    func startCaching(_ items: [PhotoItem]) {
        let assets = items.compactMap { $0.asset }
        imageManager.startCachingImages(for: assets,
                                        targetSize: cacheTargetSize,
                                        contentMode: .aspectFit,
                                        options: nil)
    }

    func stopCaching(_ items: [PhotoItem]) {
        let assets = items.compactMap { $0.asset }
        imageManager.stopCachingImages(for: assets,
                                       targetSize: cacheTargetSize,
                                       contentMode: .aspectFit,
                                       options: nil)
    }

    // MARK: - Byte estimation

    func estimatedBytes(for item: PhotoItem) -> Int64 {
        guard let asset = item.asset else { return 0 }
        let resources = PHAssetResource.assetResources(for: asset)
        // Prefer the full-size photo resource; fall back to any resource.
        for resource in resources {
            if let size = resource.value(forKey: "fileSize") as? Int64 {
                return size
            }
            if let size = resource.value(forKey: "fileSize") as? Int {
                return Int64(size)
            }
        }
        return 0
    }

    // MARK: - Deletion (safe; goes to Recently Deleted)

    func deleteAssets(_ items: [PhotoItem]) async throws {
        let assets = items.compactMap { $0.asset }
        guard !assets.isEmpty else { return }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets(assets as NSArray)
            }
        } catch {
            throw PhotoLibraryError.deletionFailed(underlying: error)
        }
    }

    // MARK: - Helpers

    private func items(from result: PHFetchResult<PHAsset>) -> [PhotoItem] {
        var items: [PhotoItem] = []
        items.reserveCapacity(result.count)
        result.enumerateObjects { asset, _, _ in
            items.append(PhotoItem(asset: asset))
        }
        return items
    }

    private func assetCount(in collection: PHAssetCollection) -> Int {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "mediaType == %d",
                                        PHAssetMediaType.image.rawValue)
        return PHAsset.fetchAssets(in: collection, options: options).count
    }

    private func makeAlbumInfo(_ collection: PHAssetCollection, count: Int? = nil) -> AlbumInfo {
        AlbumInfo(
            id: collection.localIdentifier,
            title: collection.localizedTitle ?? "Untitled",
            estimatedCount: count ?? assetCount(in: collection),
            collection: collection
        )
    }
}
