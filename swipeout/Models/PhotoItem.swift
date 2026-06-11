//
//  PhotoItem.swift
//  swipeout (SwipeClean)
//
//  A lightweight, value-type wrapper around a PHAsset.
//  Keeping a value type at the view-model layer makes the
//  queue / ordering / undo logic fully unit-testable without
//  depending on PhotoKit.
//

import Foundation
import Photos

struct PhotoItem: Identifiable, Equatable, Hashable {
    /// PHAsset.localIdentifier — stable across the session.
    let id: String
    let creationDate: Date?
    let pixelWidth: Int
    let pixelHeight: Int

    /// The backing PHAsset. Optional so tests can construct items freely.
    let asset: PHAsset?

    init(id: String,
         creationDate: Date?,
         pixelWidth: Int = 0,
         pixelHeight: Int = 0,
         asset: PHAsset? = nil) {
        self.id = id
        self.creationDate = creationDate
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.asset = asset
    }

    init(asset: PHAsset) {
        self.id = asset.localIdentifier
        self.creationDate = asset.creationDate
        self.pixelWidth = asset.pixelWidth
        self.pixelHeight = asset.pixelHeight
        self.asset = asset
    }

    static func == (lhs: PhotoItem, rhs: PhotoItem) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// The decision a user made about a photo during a session.
enum SwipeDecision: Equatable {
    case keep
    case delete
}

/// A record of a single swipe, used to support undo.
struct SwipeAction: Equatable {
    let item: PhotoItem
    let decision: SwipeDecision
    /// Index the item occupied in the ordered session list.
    let index: Int
}

/// An item queued for deletion, carrying an estimated on-disk size.
struct DeletionItem: Identifiable, Equatable {
    var id: String { photo.id }
    let photo: PhotoItem
    /// Estimated bytes this asset occupies, where available.
    var estimatedBytes: Int64
}
