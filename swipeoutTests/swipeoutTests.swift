//
//  swipeoutTests.swift
//  swipeoutTests
//
//  Test suite entry point. Concrete tests live in:
//    - PhotoOrderingTests
//    - SwipeSessionViewModelTests
//    - StatsStoreTests
//    - LibraryViewModelTests
//

import XCTest
@testable import swipeout

@MainActor
final class swipeoutTests: XCTestCase {

    func testModelSmoke() {
        let item = PhotoItem(id: "x", creationDate: Date())
        XCTAssertEqual(item.id, "x")
    }
}
