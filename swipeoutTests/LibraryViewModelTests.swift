//
//  LibraryViewModelTests.swift
//  swipeoutTests
//

import XCTest
@testable import swipeout

@MainActor
final class LibraryViewModelTests: XCTestCase {

    private func makeVM() -> (LibraryViewModel, FakePhotoLibraryService, StatsStore) {
        let service = FakePhotoLibraryService()
        let stats = StatsStore(store: InMemoryKeyValueStore())
        let vm = LibraryViewModel(service: service, statsStore: stats)
        return (vm, service, stats)
    }

    private func makeVMWithReview()
        -> (LibraryViewModel, FakePhotoLibraryService, InMemoryReviewTracker) {
        let service = FakePhotoLibraryService()
        let stats = StatsStore(store: InMemoryKeyValueStore())
        let review = InMemoryReviewTracker()
        let vm = LibraryViewModel(service: service, statsStore: stats, reviewStore: review)
        return (vm, service, review)
    }

    private func makeQueuedSession(_ service: FakePhotoLibraryService,
                                   count: Int,
                                   bytes: Int64) -> SwipeSessionViewModel {
        let items = makePhotoItems(count)
        for item in items { service.bytesPerItem[item.id] = bytes }
        let session = SwipeSessionViewModel(mode: .newestFirst, items: items, service: service)
        for _ in 0..<count { session.markCurrentForDeletion() }
        return session
    }

    func testConfirmDeletionCallsPhotoKitAndUpdatesStats() async {
        let (vm, service, _) = makeVM()
        let session = makeQueuedSession(service, count: 3, bytes: 1_000_000)

        await vm.confirmDeletion(for: session)

        XCTAssertEqual(service.deletedIDs.count, 3)
        XCTAssertEqual(vm.lifetimeStats.totalPhotosDeleted, 3)
        XCTAssertEqual(vm.lifetimeStats.totalBytesFreed, 3_000_000)
        XCTAssertEqual(vm.lastDeletionResult?.photosDeleted, 3)
        // Deleted photos no longer in the active session.
        XCTAssertTrue(session.items.isEmpty)
        XCTAssertNil(vm.errorMessage)
    }

    func testFailedDeletionShowsErrorAndDoesNotUpdateStats() async {
        let (vm, service, _) = makeVM()
        service.deleteShouldThrow = PhotoLibraryError.deletionFailed(
            underlying: NSError(domain: "test", code: 1))
        let session = makeQueuedSession(service, count: 2, bytes: 1_000_000)

        await vm.confirmDeletion(for: session)

        XCTAssertNotNil(vm.errorMessage)
        XCTAssertEqual(vm.lifetimeStats.totalPhotosDeleted, 0)
        XCTAssertEqual(vm.lifetimeStats.totalBytesFreed, 0)
        XCTAssertNil(vm.lastDeletionResult)
        // Session unchanged on failure.
        XCTAssertEqual(session.items.count, 2)
    }

    func testEmptyQueueDeletionIsNoOp() async {
        let (vm, service, _) = makeVM()
        let session = SwipeSessionViewModel(mode: .newestFirst, items: makePhotoItems(2), service: service)
        await vm.confirmDeletion(for: session)
        XCTAssertTrue(service.deletedIDs.isEmpty)
        XCTAssertNil(vm.lastDeletionResult)
    }

    // MARK: Review state

    func testSelectModePersistsAndIsReadable() {
        let (vm, _, review) = makeVMWithReview()
        XCTAssertNil(vm.selectedMode)
        vm.selectMode(.random)
        XCTAssertEqual(vm.selectedMode, .random)
        XCTAssertEqual(review.selectedMode, .random)
    }

    func testMakeSessionFiltersAlreadyReviewedByDefault() {
        let (vm, service, review) = makeVMWithReview()
        let items = makePhotoItems(5) // asset-0 ... asset-4
        service.photosByMode[BrowseMode.newestFirst.title] = items
        review.markReviewed("asset-0")
        review.markReviewed("asset-2")

        let session = vm.makeSession(for: .newestFirst)
        XCTAssertEqual(Set(session.items.map(\.id)), ["asset-1", "asset-3", "asset-4"])
    }

    func testMakeSessionIncludesReviewedWhenOptedIn() {
        let (vm, service, review) = makeVMWithReview()
        let items = makePhotoItems(3)
        service.photosByMode[BrowseMode.newestFirst.title] = items
        review.markReviewed("asset-0")
        vm.setShowAlreadyReviewed(true)

        let session = vm.makeSession(for: .newestFirst)
        XCTAssertEqual(session.items.count, 3)
    }

    func testMakeSessionExcludesPendingItems() {
        let (vm, service, review) = makeVMWithReview()
        let items = makePhotoItems(3)
        service.photosByMode[BrowseMode.newestFirst.title] = items
        review.addPending(PendingDeletion(id: "asset-1", estimatedBytes: 0))

        let session = vm.makeSession(for: .newestFirst)
        XCTAssertFalse(session.items.contains { $0.id == "asset-1" })
    }

    func testClearReviewHistoryResetsCount() {
        let (vm, _, review) = makeVMWithReview()
        review.markReviewed("a")
        review.markReviewed("b")
        vm.clearReviewHistory()
        XCTAssertTrue(review.reviewedIDs.isEmpty)
        XCTAssertEqual(vm.reviewedCount, 0)
    }

    func testConfirmPendingDeletionDeletesAndClearsPending() async {
        let (vm, service, review) = makeVMWithReview()
        let items = makePhotoItems(2)
        service.photosByMode[BrowseMode.newestFirst.title] = items
        for item in items { service.bytesPerItem[item.id] = 1_000_000 }
        review.addPending(PendingDeletion(id: "asset-0", estimatedBytes: 1_000_000))
        review.addPending(PendingDeletion(id: "asset-1", estimatedBytes: 1_000_000))

        await vm.confirmPendingDeletion()

        XCTAssertEqual(service.deletedIDs.count, 2)
        XCTAssertTrue(review.pendingDeletions.isEmpty)
        XCTAssertEqual(vm.lifetimeStats.totalPhotosDeleted, 2)
        XCTAssertEqual(vm.lifetimeStats.totalBytesFreed, 2_000_000)
        XCTAssertEqual(vm.pendingCount, 0)
    }

    func testResetStatsClearsLifetimeCounters() async {
        let (vm, service, _) = makeVM()
        let session = makeQueuedSession(service, count: 1, bytes: 1_000_000)
        await vm.confirmDeletion(for: session)
        XCTAssertEqual(vm.lifetimeStats.totalPhotosDeleted, 1)

        vm.resetStats()
        XCTAssertEqual(vm.lifetimeStats.totalPhotosDeleted, 0)
        XCTAssertEqual(vm.lifetimeStats.totalBytesFreed, 0)
    }
}
