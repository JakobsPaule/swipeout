//
//  SwipeSessionViewModel.swift
//  swipeout (SwipeClean)
//
//  Owns the ordered photo list for a session, the deletion queue, the
//  swipe/undo state, and progress. Queue + undo logic is independent of
//  PhotoKit so it can be unit-tested directly.
//

import Foundation
import SwiftUI
import Observation

@MainActor
@Observable
final class SwipeSessionViewModel {

    // MARK: Observed state
    private(set) var items: [PhotoItem] = []
    private(set) var currentIndex: Int = 0
    private(set) var deletionQueue: [DeletionItem] = []
    /// Stack of actions, most recent last, for undo.
    private(set) var history: [SwipeAction] = []

    let mode: BrowseMode
    @ObservationIgnored private let service: PhotoLibraryServicing
    @ObservationIgnored private let tracker: ReviewTracking

    init(mode: BrowseMode,
         items: [PhotoItem],
         service: PhotoLibraryServicing,
         tracker: ReviewTracking = InMemoryReviewTracker()) {
        self.mode = mode
        self.items = items
        self.service = service
        self.tracker = tracker
    }

    // MARK: Derived state

    var totalCount: Int { items.count }

    /// 1-based position for display, capped at totalCount.
    var displayPosition: Int { min(currentIndex + 1, totalCount) }

    var isFinished: Bool { currentIndex >= items.count }

    var currentItem: PhotoItem? {
        guard currentIndex < items.count else { return nil }
        return items[currentIndex]
    }

    var canUndo: Bool { !history.isEmpty }

    var deletionCount: Int { deletionQueue.count }

    /// Photos favorited ("super liked") so far in this session.
    var favoriteCount: Int { history.filter { $0.decision == .favorite }.count }

    var estimatedBytesQueued: Int64 {
        deletionQueue.reduce(0) { $0 + $1.estimatedBytes }
    }

    // MARK: Actions

    /// Swipe right / Keep button.
    func keepCurrent() {
        guard let item = currentItem else { return }
        history.append(SwipeAction(item: item, decision: .keep, index: currentIndex))
        tracker.markReviewed(item.id)
        currentIndex += 1
    }

    /// Swipe left / Delete button: queue for deletion (not deleted yet).
    /// The item is added to both the in-session queue and the persistent
    /// pending-deletion folder so it survives stopping and resuming.
    func markCurrentForDeletion() {
        guard let item = currentItem else { return }
        let bytes = service.estimatedBytes(for: item)
        deletionQueue.append(DeletionItem(photo: item, estimatedBytes: bytes))
        history.append(SwipeAction(item: item, decision: .delete, index: currentIndex))
        tracker.markReviewed(item.id)
        tracker.addPending(PendingDeletion(id: item.id, estimatedBytes: bytes))
        currentIndex += 1
    }

    /// Swipe up / Favorite button: a "super like" — keeps the photo and pushes
    /// it to the top of the persistent Favorites folder.
    func favoriteCurrent() {
        guard let item = currentItem else { return }
        history.append(SwipeAction(item: item, decision: .favorite, index: currentIndex))
        tracker.markReviewed(item.id)
        tracker.addFavorite(item.id)
        currentIndex += 1
    }

    /// Undo the most recent keep/delete/favorite action.
    func undo() {
        guard let last = history.popLast() else { return }
        switch last.decision {
        case .delete:
            deletionQueue.removeAll { $0.id == last.item.id }
            tracker.removePending(ids: [last.item.id])
        case .favorite:
            tracker.removeFavorite(last.item.id)
        case .keep:
            break
        }
        tracker.unmarkReviewed(last.item.id)
        currentIndex = last.index
    }

    /// Remove a single item from the deletion queue (used in the review screen).
    func removeFromQueue(_ item: DeletionItem) {
        deletionQueue.removeAll { $0.id == item.id }
    }

    /// Called after a successful PhotoKit deletion: drop deleted items from the
    /// active session so they're not shown again.
    func purgeDeletedFromSession(ids: Set<String>) {
        items.removeAll { ids.contains($0.id) }
        deletionQueue.removeAll { ids.contains($0.id) }
        history.removeAll { ids.contains($0.item.id) }
        if currentIndex > items.count { currentIndex = items.count }
    }

    func clearQueue() {
        deletionQueue.removeAll()
    }

    // MARK: Image loading / prefetch (delegates to the service)

    func loadImage(for item: PhotoItem, targetSize: CGSize) async -> UIImage? {
        await service.loadImage(for: item, targetSize: targetSize)
    }

    /// Prefetch a window of upcoming images to keep swiping smooth on large libraries.
    func prefetchAround(currentIndex index: Int, window: Int = 5) {
        let lower = max(0, index)
        let upper = min(items.count, index + window)
        guard lower < upper else { return }
        service.startCaching(Array(items[lower..<upper]))
    }
}
