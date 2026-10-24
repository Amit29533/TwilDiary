import XCTest

/// Reused by the pinned base, compact and large simulator destinations.
@MainActor final class LayoutScreensTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private func launch() -> XCUIApplication {
        let app = XCUIApplication(); app.launchArguments = ["--ui-testing"]
        app.launchEnvironment["TZ"] = "Asia/Kolkata"; app.launch()
        XCTAssertTrue(app.buttons["tab-home"].waitForExistence(timeout: 15)); return app
    }
    func testPhoneChromeGridSearchAndEpisodeTrackStayInsideTheViewport() {
        let app = launch()
        app.buttons["tab-home"].tap(); capture("Home", app: app)
        app.buttons["tab-library"].tap()
        let titles = ["after-rain", "again", "frieren"].map { app.buttons["title-" + $0] }
        for title in titles { XCTAssertTrue(title.waitForExistence(timeout: 5)); XCTAssertGreaterThanOrEqual(title.frame.minX, 10); XCTAssertLessThanOrEqual(title.frame.maxX, app.frame.width - 10) }
        XCTAssertLessThan(titles[0].frame.maxX, titles[1].frame.minX); XCTAssertLessThan(titles[1].frame.maxX, titles[2].frame.minX)
        // Match the phone web grid and controls; measure layout, not text-ink widths.
        XCTAssertEqual(titles[0].frame.minX, 14, accuracy: 1)
        XCTAssertEqual(titles[0].frame.width, (app.frame.width - 48) / 3, accuracy: 1)
        XCTAssertEqual(titles[1].frame.minX - titles[0].frame.maxX, 10, accuracy: 1)
        XCTAssertEqual(titles[2].frame.minX - titles[1].frame.maxX, 10, accuracy: 1)
        let order = app.buttons["library-order"], layout = app.buttons["library-layout"], genres = app.buttons["library-genres"]
        XCTAssertEqual(order.frame.width, app.frame.width < 359 ? 150 : 185, accuracy: 1)
        XCTAssertEqual(order.frame.height, 46, accuracy: 1)
        XCTAssertEqual(layout.frame.width, 42, accuracy: 1); XCTAssertEqual(layout.frame.height, 44, accuracy: 1)
        XCTAssertEqual(genres.frame.width, 36, accuracy: 1); XCTAssertEqual(genres.frame.height, 44, accuracy: 1)
        XCTAssertEqual(app.buttons["category-all"].frame.minX, 14, accuracy: 1)
        XCTAssertEqual(titles[0].frame.minY - app.buttons["random-pick-logo"].frame.minY, 204, accuracy: 2)
        capture("Library", app: app)
        titles[1].tap()
        let track = app.sliders["episode-progress"]
        XCTAssertTrue(track.waitForExistence(timeout: 5)); XCTAssertEqual(track.value as? String, "8 of 16 episodes watched")
        XCTAssertGreaterThanOrEqual(track.frame.minX, 14); XCTAssertLessThanOrEqual(track.frame.maxX, app.frame.width - 14)
        capture("Title", app: app)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["Search library"].tap()
        let field = app.textFields["Search library and online"]
        XCTAssertTrue(field.waitForExistence(timeout: 5)); field.typeText("Frieren\n")
        XCTAssertTrue(app.buttons["search-library-frieren"].exists); XCTAssertFalse(app.buttons["search-library-again"].exists)
        capture("Search", app: app)
        app.buttons["tab-stats"].tap(); XCTAssertTrue(app.buttons["stats-calendar"].waitForExistence(timeout: 5)); capture("Stats", app: app)
        for tab in ["home", "library", "glance", "stats", "more"] {
            let button = app.buttons["tab-" + tab]
            XCTAssertTrue(button.isHittable); XCTAssertGreaterThanOrEqual(button.frame.minX, 0); XCTAssertLessThanOrEqual(button.frame.maxX, app.frame.width)
        }
    }
    func testEveryThemeIsSelectableAndGlassSearchKeepsOneContainedField() {
        let app = launch(); app.buttons["tab-more"].tap(); openThemes(app)
        let first = app.buttons["theme-twilight"], second = app.buttons["theme-ocean"]
        XCTAssertTrue(first.waitForExistence(timeout: 5)); XCTAssertTrue(second.exists)
        XCTAssertLessThan(first.frame.maxX, second.frame.minX)
        XCTAssertEqual(first.frame.minY, second.frame.minY, accuracy: 1)
        XCTAssertGreaterThan(app.buttons["theme-jade"].frame.minY, first.frame.maxY)
        capture("Appearance two-column grid", app: app)
        for theme in ["twilight", "ocean", "jade", "rose", "amber", "glass"] {
            let item = app.buttons["theme-" + theme]
            for _ in 0..<4 { if item.isHittable { break }; app.swipeUp() }
            for _ in 0..<4 { if item.isHittable { break }; app.swipeDown() }
            XCTAssertTrue(item.isHittable); item.tap(); XCTAssertTrue(item.isSelected); capture("Theme " + theme, app: app)
        }
        app.buttons["appearance-done"].tap(); app.buttons["tab-library"].tap(); app.buttons["Search library"].tap()
        let search = app.textFields["Search library and online"]
        XCTAssertTrue(search.waitForExistence(timeout: 5)); XCTAssertGreaterThanOrEqual(search.frame.minX, 14); XCTAssertLessThanOrEqual(search.frame.maxX, app.frame.width - 14)
        search.typeText("Frieren\n"); capture("Glass search", app: app)
        app.buttons["tab-more"].tap(); openThemes(app)
        let twilight = app.buttons["theme-twilight"]
        for _ in 0..<5 { if twilight.isHittable { break }; app.swipeDown() }
        XCTAssertTrue(twilight.isHittable); twilight.tap(); XCTAssertTrue(twilight.isSelected)
    }
    func testExpandedSummaryAndWatchDateRemainInsideEveryPhone() {
        let app = launch(); app.buttons["tab-library"].tap(); app.buttons["title-frieren"].tap()
        XCTAssertTrue(app.buttons["More"].waitForExistence(timeout: 5)); app.buttons["More"].tap()
        let summary = app.staticTexts["title-synopsis-text"]
        XCTAssertTrue(summary.exists); XCTAssertGreaterThan(summary.frame.width, app.frame.width * 0.8)
        XCTAssertLessThan(summary.frame.minX, 24)
        capture("Expanded synopsis full width", app: app)
        let watched = app.buttons["watch-date"]
        for _ in 0..<5 { if watched.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(watched.isHittable); watched.tap()
        let value = app.buttons["title-watch-date-value"]
        for _ in 0..<3 { if value.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(value.isHittable); XCTAssertGreaterThanOrEqual(value.frame.minX, 14); XCTAssertLessThanOrEqual(value.frame.maxX, app.frame.width - 14)
        capture("Watch date contained", app: app)
        value.tap(); XCTAssertTrue(app.datePickers.firstMatch.waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
    }
    private func openThemes(_ app: XCUIApplication) {
        let theme = app.buttons["settings-theme"]
        for _ in 0..<8 { if theme.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(theme.isHittable); theme.tap()
    }
    private func capture(_ label: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "Layout " + String(Int(app.frame.width)) + " " + label; attachment.lifetime = .keepAlways; add(attachment)
    }
}
