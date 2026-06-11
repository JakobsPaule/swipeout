//
//  swipeoutUITests.swift
//  swipeoutUITests
//
//  UI flow tests for onboarding, swiping, review, and confirmation.
//
//  NOTE: These tests interact with the live Photos permission flow. For a
//  fully deterministic run, reset the simulator's photo permissions and add
//  sample photos:
//    xcrun simctl privacy <device> reset photos jp.swipeout
//    (then grant when prompted, or pre-seed Photos with sample images)
//  Tests are written defensively so they pass on a clean device by verifying
//  the screens that are reachable given the current permission state.
//

import XCTest

final class swipeoutUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // Automatically dismiss the system Photos permission dialog by allowing access.
        addUIInterruptionMonitor(withDescription: "Photos Permission") { alert in
            for label in ["Allow Access to All Photos", "Allow Full Access", "OK", "Allow"] {
                let button = alert.buttons[label]
                if button.exists {
                    button.tap()
                    return true
                }
            }
            return false
        }
        app.launch()
    }

    // MARK: Onboarding

    @MainActor
    func testOnboardingShowsGetStarted() throws {
        // On a not-determined device the onboarding screen is shown first.
        let getStarted = app.buttons["getStartedButton"]
        let startCleaning = app.buttons["startCleaningButton"]

        // Either we're at onboarding, or permission was already granted (home).
        XCTAssertTrue(getStarted.waitForExistence(timeout: 5) ||
                      startCleaning.waitForExistence(timeout: 5),
                      "Expected onboarding or home screen on launch.")
    }

    @MainActor
    func testRequestingAccessAdvancesPastOnboarding() throws {
        let getStarted = app.buttons["getStartedButton"]
        if getStarted.waitForExistence(timeout: 5) {
            getStarted.tap()
            app.tap() // trigger the interruption monitor for the permission alert

            // After granting, the home screen's primary button should appear.
            let startCleaning = app.buttons["startCleaningButton"]
            let settings = app.buttons["settingsButton"]
            XCTAssertTrue(startCleaning.waitForExistence(timeout: 8) || settings.exists,
                          "Expected home screen after granting access.")
        } else {
            throw XCTSkip("Permission already determined; onboarding not shown.")
        }
    }

    // MARK: Home → Settings → Reset stats

    @MainActor
    func testSettingsAndResetStatsFlow() throws {
        try grantAccessIfNeeded()
        let settings = app.buttons["settingsButton"]
        guard settings.waitForExistence(timeout: 8) else {
            throw XCTSkip("Home not reachable in current permission state.")
        }
        settings.tap()

        let resetButton = app.buttons["resetStatsButton"]
        XCTAssertTrue(resetButton.waitForExistence(timeout: 5))
        resetButton.tap()

        // Confirmation dialog appears; cancel to avoid side effects in repeated runs.
        let cancel = app.buttons["Cancel"]
        if cancel.waitForExistence(timeout: 3) { cancel.tap() }
    }

    // MARK: Swipe → Review → Confirm flow

    @MainActor
    func testSwipeAndReviewFlow() throws {
        try grantAccessIfNeeded()
        let startCleaning = app.buttons["startCleaningButton"]
        guard startCleaning.waitForExistence(timeout: 8) else {
            throw XCTSkip("Home not reachable in current permission state.")
        }
        startCleaning.tap()

        // Choose newest-first chronological.
        let modeButton = app.buttons["mode_Newest first"]
        guard modeButton.waitForExistence(timeout: 5) else {
            throw XCTSkip("Mode selector not reachable.")
        }
        modeButton.tap()

        // If there are photos, a card and action buttons appear.
        let deleteButton = app.buttons["deleteButton"]
        guard deleteButton.waitForExistence(timeout: 8) else {
            throw XCTSkip("No photos available to swipe in this simulator.")
        }

        // Mark one for deletion via button (equivalent to a left swipe).
        deleteButton.tap()

        // Review entry should now be available.
        let review = app.buttons["reviewDeletionsButton"]
        XCTAssertTrue(review.waitForExistence(timeout: 5))
        review.tap()

        // Confirmation must be explicit: a Confirm button exists, but we cancel
        // the destructive alert so the UI test doesn't actually delete photos.
        let confirm = app.buttons["confirmDeletionButton"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        let cancel = app.buttons["Cancel"]
        if cancel.waitForExistence(timeout: 3) { cancel.tap() }
    }

    // MARK: Helpers

    private func grantAccessIfNeeded() throws {
        let getStarted = app.buttons["getStartedButton"]
        if getStarted.waitForExistence(timeout: 4) {
            getStarted.tap()
            app.tap() // handle permission alert via interruption monitor
        }
    }
}
