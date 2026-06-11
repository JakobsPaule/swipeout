//
//  PhotoOrderingTests.swift
//  swipeoutTests
//

import XCTest
@testable import swipeout

@MainActor
final class PhotoOrderingTests: XCTestCase {

    func testNewestFirstOrdering() {
        let items = makePhotoItems(5) // asset-0 oldest ... asset-4 newest
        let ordered = PhotoOrdering.order(items, for: .newestFirst)
        XCTAssertEqual(ordered.map(\.id), ["asset-4", "asset-3", "asset-2", "asset-1", "asset-0"])
    }

    func testOldestFirstOrdering() {
        let items = makePhotoItems(5)
        let ordered = PhotoOrdering.order(items, for: .oldestFirst)
        XCTAssertEqual(ordered.map(\.id), ["asset-0", "asset-1", "asset-2", "asset-3", "asset-4"])
    }

    func testRandomModeContainsAllItemsWithoutRepeats() {
        let items = makePhotoItems(100)
        var gen = SeededGenerator(seed: 42)
        let ordered = PhotoOrdering.order(items, for: .random, using: &gen)

        XCTAssertEqual(ordered.count, items.count)
        // No repeats: unique IDs equal to original set.
        XCTAssertEqual(Set(ordered.map(\.id)), Set(items.map(\.id)))
        XCTAssertEqual(Set(ordered.map(\.id)).count, items.count)
    }

    func testRandomModeIsDeterministicWithSeed() {
        let items = makePhotoItems(20)
        var a = SeededGenerator(seed: 7)
        var b = SeededGenerator(seed: 7)
        let first = PhotoOrdering.order(items, for: .random, using: &a)
        let second = PhotoOrdering.order(items, for: .random, using: &b)
        XCTAssertEqual(first.map(\.id), second.map(\.id))
    }

    func testItemsWithoutCreationDateSortToEndNewestFirst() {
        var items = makePhotoItems(3)
        items.append(PhotoItem(id: "no-date", creationDate: nil))
        let ordered = PhotoOrdering.order(items, for: .newestFirst)
        XCTAssertEqual(ordered.last?.id, "no-date")
    }
}
