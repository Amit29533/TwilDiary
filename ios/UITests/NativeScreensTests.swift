import XCTest

@MainActor final class NativeScreensTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private func launch() -> XCUIApplication {
        let app = XCUIApplication(); app.launchArguments = ["--ui-testing"]
        app.launchEnvironment["TZ"] = "Asia/Kolkata"
        app.launch(); XCTAssertTrue(app.buttons["tab-home"].waitForExistence(timeout: 15)); return app
    }
    func testNativeTabsAndTitleNavigation() {
        let app = launch()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'complete'")).firstMatch.waitForExistence(timeout: 5))
        capture("Glance")
        app.buttons["tab-home"].tap()
        XCTAssertTrue(app.staticTexts["Pick up where you left off"].waitForExistence(timeout: 5)); capture("Home")
        app.buttons["tab-library"].tap()
        XCTAssertTrue(app.buttons["Search library"].waitForExistence(timeout: 5)); capture("Library")
        XCTAssertEqual(app.tabBars.count, 0, "The custom capsule must be the only tab bar")
        let first = app.buttons["title-after-rain"].frame, second = app.buttons["title-again"].frame, third = app.buttons["title-frieren"].frame
        XCTAssertLessThan(first.maxX, second.minX)
        XCTAssertLessThan(second.maxX, third.minX)
        XCTAssertLessThanOrEqual(third.maxX, app.frame.width - 10)
        app.buttons["title-again"].tap()
        XCTAssertTrue(app.staticTexts["Episodes"].waitForExistence(timeout: 5)); capture("Title detail")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["tab-stats"].tap()
        XCTAssertTrue(app.staticTexts["Watch time"].waitForExistence(timeout: 5)); capture("Stats")
        app.buttons["tab-more"].tap()
        XCTAssertTrue(app.staticTexts["Appearance"].waitForExistence(timeout: 5)); capture("More")
    }
    func testLibrarySearchAndSelectionPersistAcrossTabs() {
        let app = launch()
        app.buttons["tab-library"].tap(); app.buttons["Search library"].tap()
        let search = app.textFields["library-search"]
        XCTAssertTrue(search.waitForExistence(timeout: 5)); search.tap(); search.typeText("Frieren\n")
        XCTAssertTrue(app.buttons["title-frieren"].exists); XCTAssertFalse(app.buttons["title-again"].exists)
        capture("Library search")
        app.buttons["tab-home"].tap(); app.buttons["tab-library"].tap()
        XCTAssertEqual(search.value as? String, "Frieren")
        app.buttons["Clear search"].tap(); app.buttons["List layout"].tap(); capture("Library list")
        app.buttons["Genre sections"].tap(); capture("Library genres")
    }
    func testCatalogSearchReviewAndCastProfile() {
        let app = launch(); app.buttons["tab-home"].tap(); app.buttons["Search"].tap()
        let search = app.textFields["Search library and online"]
        XCTAssertTrue(search.waitForExistence(timeout: 5)); search.tap(); search.typeText("Clockmaker\n")
        let result = app.buttons["search-movie:900001"]
        XCTAssertTrue(result.waitForExistence(timeout: 10)); capture("Catalog search"); result.tap()
        XCTAssertTrue(app.buttons["Add to Planned"].waitForExistence(timeout: 10)); capture("Catalog review")
        let actor = app.buttons.containing(NSPredicate(format: "label CONTAINS 'Reference Actor 1'")).firstMatch
        if !actor.isHittable { app.swipeUp() }
        XCTAssertTrue(actor.waitForExistence(timeout: 5)); actor.tap()
        XCTAssertTrue(app.staticTexts["Filmography"].waitForExistence(timeout: 10)); capture("Cast profile")
    }
    func testExploreAndHomeStatsShortcut() {
        let app = launch(); app.buttons["tab-home"].tap()
        let explore = app.buttons["explore-shortcut"]
        XCTAssertTrue(explore.waitForExistence(timeout: 5)); explore.tap()
        XCTAssertTrue(app.buttons["catalog-tv:900002"].waitForExistence(timeout: 10)); capture("Explore")
    }
    func testHomeStatsUsesTodayAndKeepsTheOriginalRangeBar() {
        let app = launch(); app.buttons["tab-stats"].tap()
        XCTAssertTrue(app.buttons["30D"].waitForExistence(timeout: 5))
        app.buttons["1Y"].tap()
        capture("Stats year")
        app.buttons["tab-home"].tap()
        app.buttons["home-stats"].tap()
        XCTAssertTrue(app.staticTexts["Today"].exists || app.buttons.containing(NSPredicate(format: "label CONTAINS 'Today'")).firstMatch.exists)
        XCTAssertTrue(app.buttons["7D"].exists)
        XCTAssertTrue(app.buttons["90D"].exists)
        capture("Stats from Home")
    }
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
