//
//  ReviewStoreTests.swift
//  swipeoutTests
//

import XCTest
@testable import swipeout

@MainActor
final class ReviewStoreTests: XCTestCase {

    // MARK: Reviewed set

    func testReviewedIDsStartEmpty() {
        let store = ReviewStore(store: InMemoryKeyValueStore())
        XCTAssertTrue(store.reviewedIDs.isEmpty)
    }

    func testMarkAndUnmarkReviewed() {
        let store = ReviewStore(store: InMemoryKeyValueStore())
        store.markReviewed("a")
        store.markReviewed("b")
        XCTAssertEqual(store.reviewedIDs, ["a", "b"])
        store.unmarkReviewed("a")
        XCTAssertEqual(store.reviewedIDs, ["b"])
    }

    func testReviewedPersistsAcrossInstances() {
        let backing = InMemoryKeyValueStore()
        ReviewStore(store: backing).markReviewed("x")
        XCTAssertEqual(ReviewStore(store: backing).reviewedIDs, ["x"])
    }

    func testClearReviewHistory() {
        let store = ReviewStore(store: InMemoryKeyValueStore())
        store.markReviewed("a")
        store.markReviewed("b")
        store.clearReviewHistory()
        XCTAssertTrue(store.reviewedIDs.isEmpty)
    }

    // MARK: Pending deletions

    func testAddPendingNoDuplicates() {
        let store = ReviewStore(store: InMemoryKeyValueStore())
        store.addPending(PendingDeletion(id: "a", estimatedBytes: 100))
        store.addPending(PendingDeletion(id: "a", estimatedBytes: 999))
        XCTAssertEqual(store.pendingDeletions.count, 1)
        XCTAssertEqual(store.pendingDeletions.first?.estimatedBytes, 100)
    }

    func testRemovePending() {
        let store = ReviewStore(store: InMemoryKeyValueStore())
        store.addPending(PendingDeletion(id: "a", estimatedBytes: 1))
        store.addPending(PendingDeletion(id: "b", estimatedBytes: 2))
        store.removePending(ids: ["a"])
        XCTAssertEqual(store.pendingDeletions.map(\.id), ["b"])
    }

    func testPendingPersistsAcrossInstances() {
        let backing = InMemoryKeyValueStore()
        ReviewStore(store: backing).addPending(PendingDeletion(id: "z", estimatedBytes: 42))
        let reloaded = ReviewStore(store: backing).pendingDeletions
        XCTAssertEqual(reloaded, [PendingDeletion(id: "z", estimatedBytes: 42)])
    }

    func testClearPending() {
        let store = ReviewStore(store: InMemoryKeyValueStore())
        store.addPending(PendingDeletion(id: "a", estimatedBytes: 1))
        store.clearPending()
        XCTAssertTrue(store.pendingDeletions.isEmpty)
    }

    // MARK: Selected mode

    func testSelectedModeStartsNil() {
        XCTAssertNil(ReviewStore(store: InMemoryKeyValueStore()).selectedMode)
    }

    func testSelectedModeRoundTrips() {
        let backing = InMemoryKeyValueStore()
        let store = ReviewStore(store: backing)
        store.setSelectedMode(.album(id: "id1", title: "Vacation"))
        XCTAssertEqual(ReviewStore(store: backing).selectedMode,
                       .album(id: "id1", title: "Vacation"))
    }

    func testClearingSelectedMode() {
        let store = ReviewStore(store: InMemoryKeyValueStore())
        store.setSelectedMode(.random)
        store.setSelectedMode(nil)
        XCTAssertNil(store.selectedMode)
    }

    // MARK: Show already reviewed

    func testShowAlreadyReviewedDefaultsFalse() {
        XCTAssertFalse(ReviewStore(store: InMemoryKeyValueStore()).showAlreadyReviewed)
    }

    func testShowAlreadyReviewedRoundTrips() {
        let backing = InMemoryKeyValueStore()
        ReviewStore(store: backing).setShowAlreadyReviewed(true)
        XCTAssertTrue(ReviewStore(store: backing).showAlreadyReviewed)
    }
}
