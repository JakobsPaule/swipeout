//
//  StatsStoreTests.swift
//  swipeoutTests
//

import XCTest
@testable import swipeout

@MainActor
final class StatsStoreTests: XCTestCase {

    func testInitialStatsAreZero() {
        let store = StatsStore(store: InMemoryKeyValueStore())
        let stats = store.load()
        XCTAssertEqual(stats.totalPhotosDeleted, 0)
        XCTAssertEqual(stats.totalBytesFreed, 0)
    }

    func testRecordDeletionUpdatesCounts() {
        let store = StatsStore(store: InMemoryKeyValueStore())
        let updated = store.recordDeletion(photoCount: 3, bytesFreed: 5_000_000)
        XCTAssertEqual(updated.totalPhotosDeleted, 3)
        XCTAssertEqual(updated.totalBytesFreed, 5_000_000)
    }

    func testRecordDeletionAccumulates() {
        let store = StatsStore(store: InMemoryKeyValueStore())
        store.recordDeletion(photoCount: 2, bytesFreed: 1_000_000)
        let updated = store.recordDeletion(photoCount: 4, bytesFreed: 3_000_000)
        XCTAssertEqual(updated.totalPhotosDeleted, 6)
        XCTAssertEqual(updated.totalBytesFreed, 4_000_000)
    }

    func testStatsPersistAcrossInstances() {
        // Shared backing store simulates app restart.
        let backing = InMemoryKeyValueStore()
        let first = StatsStore(store: backing)
        first.recordDeletion(photoCount: 7, bytesFreed: 9_999_999)

        let second = StatsStore(store: backing)
        let stats = second.load()
        XCTAssertEqual(stats.totalPhotosDeleted, 7)
        XCTAssertEqual(stats.totalBytesFreed, 9_999_999)
    }

    func testResetClearsCountersOnly() {
        let store = StatsStore(store: InMemoryKeyValueStore())
        store.recordDeletion(photoCount: 5, bytesFreed: 2_000_000)
        store.reset()
        let stats = store.load()
        XCTAssertEqual(stats.totalPhotosDeleted, 0)
        XCTAssertEqual(stats.totalBytesFreed, 0)
    }

    func testGigabytesFreedComputation() {
        let stats = LifetimeStats(totalPhotosDeleted: 0, totalBytesFreed: 2_500_000_000)
        XCTAssertEqual(stats.gigabytesFreed, 2.5, accuracy: 0.0001)
    }

    func testGigabytesFormattingTwoDecimals() {
        XCTAssertEqual(StorageFormat.gigabytes(Int64(1_234_000_000)), "1.23 GB")
        XCTAssertEqual(StorageFormat.gigabytes(Int64(0)), "0.00 GB")
    }

    func testNegativeValuesIgnored() {
        let store = StatsStore(store: InMemoryKeyValueStore())
        let updated = store.recordDeletion(photoCount: -5, bytesFreed: -100)
        XCTAssertEqual(updated.totalPhotosDeleted, 0)
        XCTAssertEqual(updated.totalBytesFreed, 0)
    }
}
