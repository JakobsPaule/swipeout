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
