//
//  TestHelpers.swift
//  swipeoutTests
//
//  Shared fakes and helpers for unit tests.
//

import Foundation
import UIKit
@testable import swipeout

/// Deterministic RNG so shuffle-based tests are reproducible.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed != 0 ? seed : 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        // xorshift64*
        state ^= state >> 12
        state ^= state << 25
        state ^= state >> 27
        return state &* 0x2545F4914F6CDD1D
    }
}

/// In-memory fake of the PhotoKit-backed service.
final class FakePhotoLibraryService: PhotoLibraryServicing {
    var accessToReturn: LibraryAccess
    var photosByMode: [String: [PhotoItem]] = [:]
    var albumsToReturn: [AlbumInfo] = []
    var bytesPerItem: [String: Int64] = [:]
    var deleteShouldThrow: Error?
    private(set) var deletedIDs: [String] = []

    init(access: LibraryAccess = .authorized) {
        self.accessToReturn = access
    }

    var currentAccess: LibraryAccess { accessToReturn }

    func requestAccess() async -> LibraryAccess { accessToReturn }

    func fetchAlbums() -> [AlbumInfo] { albumsToReturn }

    func fetchPhotos(for mode: BrowseMode) -> [PhotoItem] {
        photosByMode[mode.title] ?? []
    }

    var monthBucketsToReturn: [MonthBucket] = []
    func photoMonthBuckets() -> [MonthBucket] { monthBucketsToReturn }

    func fetchItems(withIDs ids: [String]) -> [PhotoItem] {
        let all = photosByMode.values.flatMap { $0 }
        var byID: [String: PhotoItem] = [:]
        for item in all { byID[item.id] = item }
        return ids.compactMap { byID[$0] }
    }

    func loadImage(for item: PhotoItem, targetSize: CGSize) async -> UIImage? { nil }

    func estimatedBytes(for item: PhotoItem) -> Int64 {
        bytesPerItem[item.id] ?? 0
    }

    func deleteAssets(_ items: [PhotoItem]) async throws {
        if let deleteShouldThrow { throw deleteShouldThrow }
        deletedIDs.append(contentsOf: items.map(\.id))
    }

    func startCaching(_ items: [PhotoItem]) {}
    func stopCaching(_ items: [PhotoItem]) {}
}

/// Builds N photo items with sequential creation dates (oldest = index 0).
func makePhotoItems(_ count: Int,
                    startDate: Date = Date(timeIntervalSince1970: 1_000_000),
                    intervalSeconds: TimeInterval = 60) -> [PhotoItem] {
    (0..<count).map { i in
        PhotoItem(id: "asset-\(i)",
                  creationDate: startDate.addingTimeInterval(Double(i) * intervalSeconds))
    }
}
