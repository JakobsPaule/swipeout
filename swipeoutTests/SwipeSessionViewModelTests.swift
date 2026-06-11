//
//  SwipeSessionViewModelTests.swift
//  swipeoutTests
//

import XCTest
@testable import swipeout

@MainActor
final class SwipeSessionViewModelTests: XCTestCase {

    private func makeSession(_ count: Int = 5,
                             bytes: Int64 = 1_000_000) -> (SwipeSessionViewModel, FakePhotoLibraryService) {
        let items = makePhotoItems(count)
        let service = FakePhotoLibraryService()
        for item in items { service.bytesPerItem[item.id] = bytes }
        let vm = SwipeSessionViewModel(mode: .newestFirst, items: items, service: service)
        return (vm, service)
    }

    func testLeftSwipeAddsToDeletionQueue() {
        let (vm, _) = makeSession()
        let first = vm.currentItem
        vm.markCurrentForDeletion()
        XCTAssertEqual(vm.deletionCount, 1)
        XCTAssertEqual(vm.deletionQueue.first?.id, first?.id)
        XCTAssertEqual(vm.currentIndex, 1)
    }

    func testRightSwipeDoesNotAddToDeletionQueue() {
        let (vm, _) = makeSession()
        vm.keepCurrent()
        XCTAssertEqual(vm.deletionCount, 0)
        XCTAssertEqual(vm.currentIndex, 1)
    }

    func testUndoReversesDeleteAction() {
        let (vm, _) = makeSession()
        vm.markCurrentForDeletion()
        XCTAssertEqual(vm.deletionCount, 1)
        vm.undo()
        XCTAssertEqual(vm.deletionCount, 0)
        XCTAssertEqual(vm.currentIndex, 0)
        XCTAssertFalse(vm.canUndo)
    }

    func testUndoReversesKeepAction() {
        let (vm, _) = makeSession()
        vm.keepCurrent()
        XCTAssertEqual(vm.currentIndex, 1)
        vm.undo()
        XCTAssertEqual(vm.currentIndex, 0)
    }

    func testButtonsBehaveSameAsGestures() {
        // Buttons call the same methods; assert sequence equivalence.
        let (vm, _) = makeSession(3)
        vm.markCurrentForDeletion() // delete asset 0
        vm.keepCurrent()            // keep asset 1
        XCTAssertEqual(vm.currentIndex, 2)
        XCTAssertEqual(vm.deletionCount, 1)
    }

    func testEstimatedBytesQueuedSumsResources() {
        let (vm, _) = makeSession(3, bytes: 2_000_000)
        vm.markCurrentForDeletion()
        vm.markCurrentForDeletion()
        XCTAssertEqual(vm.estimatedBytesQueued, 4_000_000)
    }

    func testProgressDisplay() {
        let (vm, _) = makeSession(10)
        XCTAssertEqual(vm.displayPosition, 1)
        XCTAssertEqual(vm.totalCount, 10)
        vm.keepCurrent()
        XCTAssertEqual(vm.displayPosition, 2)
    }

    func testFinishedWhenAllReviewed() {
        let (vm, _) = makeSession(2)
        vm.keepCurrent()
        vm.keepCurrent()
        XCTAssertTrue(vm.isFinished)
        XCTAssertNil(vm.currentItem)
    }

    func testPurgeDeletedRemovesFromSession() {
        let (vm, _) = makeSession(3)
        let firstID = vm.currentItem!.id
        vm.markCurrentForDeletion()
        vm.purgeDeletedFromSession(ids: [firstID])
        XCTAssertEqual(vm.totalCount, 2)
        XCTAssertFalse(vm.items.contains { $0.id == firstID })
        XCTAssertEqual(vm.deletionCount, 0)
    }

    func testRemoveFromQueueKeepsOtherItems() {
        let (vm, _) = makeSession(3)
        vm.markCurrentForDeletion()
        vm.markCurrentForDeletion()
        let toRemove = vm.deletionQueue.first!
        vm.removeFromQueue(toRemove)
        XCTAssertEqual(vm.deletionCount, 1)
    }

    // MARK: Review tracking integration

    private func makeTrackedSession(_ count: Int = 5, bytes: Int64 = 1_000_000)
        -> (SwipeSessionViewModel, InMemoryReviewTracker) {
        let items = makePhotoItems(count)
        let service = FakePhotoLibraryService()
        for item in items { service.bytesPerItem[item.id] = bytes }
        let tracker = InMemoryReviewTracker()
        let vm = SwipeSessionViewModel(mode: .newestFirst, items: items,
                                       service: service, tracker: tracker)
        return (vm, tracker)
    }

    func testKeepMarksReviewedInTracker() {
        let (vm, tracker) = makeTrackedSession(3)
        let id = vm.currentItem!.id
        vm.keepCurrent()
        XCTAssertTrue(tracker.reviewedIDs.contains(id))
        XCTAssertTrue(tracker.pendingDeletions.isEmpty)
    }

    func testDeleteMarksReviewedAndAddsPending() {
        let (vm, tracker) = makeTrackedSession(3, bytes: 500)
        let id = vm.currentItem!.id
        vm.markCurrentForDeletion()
        XCTAssertTrue(tracker.reviewedIDs.contains(id))
        XCTAssertEqual(tracker.pendingDeletions, [PendingDeletion(id: id, estimatedBytes: 500)])
    }

    func testUndoDeleteRemovesReviewedAndPending() {
        let (vm, tracker) = makeTrackedSession(3)
        let id = vm.currentItem!.id
        vm.markCurrentForDeletion()
        vm.undo()
        XCTAssertFalse(tracker.reviewedIDs.contains(id))
        XCTAssertTrue(tracker.pendingDeletions.isEmpty)
    }

    func testUndoKeepRemovesReviewed() {
        let (vm, tracker) = makeTrackedSession(3)
        let id = vm.currentItem!.id
        vm.keepCurrent()
        vm.undo()
        XCTAssertFalse(tracker.reviewedIDs.contains(id))
    }
}
