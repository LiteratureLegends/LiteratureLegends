//
//  DiscoverNavigationUITests.swift
//  LiteratureLegendsUITests
//
//  Regression test: opening a paper from Discover search results used to bounce back to the
//  Discover page right after the detail appeared (Back then showed the detail).
//  Launches DiscoverUITestHarness (DEBUG only, mock services, no login, no network).
//

import XCTest

final class DiscoverNavigationUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITestDiscover"]
        app.launch()
    }

    func testLogoutFromDiscoverProfileReturnsToLogin() {
        app.buttons["Open profile"].tap()
        let logout = app.buttons["Log out"]
        XCTAssertTrue(logout.waitForExistence(timeout: 5))
        if !logout.isHittable { app.swipeUp() }
        logout.tap()
        XCTAssertTrue(app.navigationBars["Log in"].waitForExistence(timeout: 5))
    }

    func testProfileUsesSignedInAccountAndSavesEditedName() {
        app.buttons["Open profile"].tap()
        XCTAssertTrue(app.staticTexts["Test User"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["test@example.com"].firstMatch.exists)
        app.buttons["Edit profile"].tap()
        let field = app.textFields["profileFullName"]
        field.tap()
        field.typeText(" Jr")
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["Test User Jr"].firstMatch.waitForExistence(timeout: 5))
    }

    func testAppearanceSelectionPersistsAfterRelaunch() {
        app.buttons["Open profile"].tap()
        app.buttons["Settings"].tap()
        let choices = app.segmentedControls.firstMatch
        let original = ["System", "Light", "Dark"].first { choices.buttons[$0].isSelected } ?? "System"
        defer { choices.buttons[original].tap() }
        for mode in ["Light", "Dark"] {
            choices.buttons[mode].tap()
            XCTAssertTrue(choices.buttons[mode].isSelected)
        }

        app.terminate()
        app.launch()
        app.buttons["Open profile"].tap()
        app.buttons["Settings"].tap()
        XCTAssertTrue(choices.buttons["Dark"].isSelected)
        choices.buttons["System"].tap()
        XCTAssertTrue(choices.buttons["System"].isSelected)
    }

    func testOpeningAPaperStaysOnDetailAndBackReturnsToResults() {
        let discoverBar = app.navigationBars["Find your next idea"]
        XCTAssertTrue(discoverBar.waitForExistence(timeout: 5))

        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Recent Projects"].exists)
        XCTAssertFalse(app.segmentedControls.firstMatch.exists)
        search.tap()
        XCTAssertTrue(app.segmentedControls.firstMatch.waitForExistence(timeout: 5))
        search.typeText("Geoffrey Hinton\n")

        let firstResult = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Geoffrey Hinton study #1,")).firstMatch
        XCTAssertTrue(firstResult.waitForExistence(timeout: 5), "Search results did not appear")
        firstResult.tap()

        let detailBar = app.navigationBars["Paper"]
        XCTAssertTrue(detailBar.waitForExistence(timeout: 5), "Paper detail did not open")

        // The bug pushed Discover back on top within a moment; give it time to happen.
        let stillOnDetail = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: detailBar)
        stillOnDetail.isInverted = true
        wait(for: [stillOnDetail], timeout: 3)
        XCTAssertTrue(detailBar.exists, "Detail screen was replaced")
        XCTAssertFalse(discoverBar.exists, "Discover page was pushed on top of the detail")

        detailBar.buttons.firstMatch.tap()  // Back
        XCTAssertTrue(discoverBar.waitForExistence(timeout: 5), "Back did not return to Discover")
        XCTAssertTrue(firstResult.waitForExistence(timeout: 5), "Back did not return to the results")
        XCTAssertFalse(detailBar.exists)
    }
}
