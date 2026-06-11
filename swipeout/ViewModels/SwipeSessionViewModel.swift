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

    init(mode: BrowseMode, items: [PhotoItem], service: PhotoLibraryServicing) {
        self.mode = mode
        self.items = items
        self.service = service
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

    var estimatedBytesQueued: Int64 {
        deletionQueue.reduce(0) { $0 + $1.estimatedBytes }
    }

    // MARK: Actions

    /// Swipe right / Keep button.
    func keepCurrent() {
        guard let item = currentItem else { return }
        history.append(SwipeAction(item: item, decision: .keep, index: currentIndex))
        currentIndex += 1
    }

    /// Swipe left / Delete button: queue for deletion (not deleted yet).
    func markCurrentForDeletion() {
        guard let item = currentItem else { return }
        let bytes = service.estimatedBytes(for: item)
        deletionQueue.append(DeletionItem(photo: item, estimatedBytes: bytes))
        history.append(SwipeAction(item: item, decision: .delete, index: currentIndex))
        currentIndex += 1
    }

    /// Undo the most recent keep/delete action.
    func undo() {
        guard let last = history.popLast() else { return }
        if last.decision == .delete {
            deletionQueue.removeAll { $0.id == last.item.id }
        }
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
