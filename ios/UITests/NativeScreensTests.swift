import XCTest
import UIKit

@MainActor final class NativeScreensTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private func launch(mutations: Bool = false, scanner: Bool = false) -> XCUIApplication {
        let app = XCUIApplication(); app.launchArguments = ["--ui-testing"]
        if mutations || scanner { app.launchArguments.append("--ui-mutations") }
        if scanner { app.launchArguments.append("--ui-scanner") }
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
        XCTAssertTrue(app.staticTexts["Episodes"].waitForExistence(timeout: 5))
        let track = app.sliders["episode-progress"]
        XCTAssertTrue(track.waitForExistence(timeout: 5))
        XCTAssertEqual(track.value as? String, "8 of 16 episodes watched")
        capture("Title detail")
        assertEpisodePieces(track, app: app)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["title-quiet-orbit"].tap()
        XCTAssertTrue(app.progressIndicators["movie-progress"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.otherElements["episode-progress"].exists)
        capture("Movie detail")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["tab-stats"].tap()
        XCTAssertTrue(app.staticTexts["Watch time"].waitForExistence(timeout: 5)); capture("Stats")
        app.buttons["tab-more"].tap()
        XCTAssertTrue(app.staticTexts["Appearance & region"].waitForExistence(timeout: 5)); capture("More")
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
        let app = launch(); app.buttons["tab-home"].tap()
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "label == 'Search'")).count, 1, "Inactive tabs must not expose controls to VoiceOver")
        app.buttons["search-twildiary"].tap()
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
        XCTAssertTrue(app.buttons["1Y"].isSelected)
        capture("Stats year")
        assertRangeHighlight(app.buttons["1Y"], app: app)
        app.buttons["tab-home"].tap()
        app.buttons["home-stats"].tap()
        XCTAssertTrue(app.staticTexts["Today"].exists || app.buttons.containing(NSPredicate(format: "label CONTAINS 'Today'")).firstMatch.exists)
        XCTAssertTrue(app.buttons["7D"].exists)
        XCTAssertTrue(app.buttons["90D"].exists)
        XCTAssertFalse(app.buttons["1Y"].isSelected)
        capture("Stats from Home")
    }
    func testTraktReviewAppliesSafeChangesThenRequiresAnExplicitConflictChoice() {
        let app = launch(); app.buttons["tab-more"].tap()
        XCTAssertTrue(app.buttons["settings-trakt-summary"].waitForExistence(timeout: 5))
        app.buttons["settings-trakt-summary"].tap()
        XCTAssertTrue(app.staticTexts["Review changes"].waitForExistence(timeout: 10))
        capture("Trakt review")
        let filter = app.segmentedControls["trakt-kind"]
        if !filter.isHittable { app.swipeUp() }
        filter.buttons["Ratings"].tap()
        XCTAssertTrue(app.staticTexts["Showing 3 of 3 loaded changes"].waitForExistence(timeout: 5))
        capture("Trakt ratings")
        filter.buttons["All"].tap()
        let ready = app.buttons["trakt-apply-ready"]
        XCTAssertTrue(ready.waitForExistence(timeout: 5)); ready.tap()
        XCTAssertTrue(app.staticTexts["1 remaining"].waitForExistence(timeout: 5))
        let useTrakt = app.buttons["trakt-trakt-change-2"]
        for _ in 0..<8 { if useTrakt.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(useTrakt.isHittable); useTrakt.tap()
        XCTAssertTrue(app.staticTexts["You’re up to date"].waitForExistence(timeout: 5))
        capture("Trakt applied")
    }
    func testStatsCalendarRangesEmptyBucketsAndUndatedHistory() {
        let app = launch(); app.buttons["tab-stats"].tap()
        XCTAssertTrue(app.buttons["stats-calendar"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["30D"].isSelected, "Fresh Stats starts with Today, as on the web")
        app.buttons["30D"].tap(); XCTAssertTrue(app.buttons["30D"].isSelected)
        let firstDay = app.buttons["stats-bucket-0"]
        if !firstDay.isHittable { app.swipeUp() }
        XCTAssertTrue(firstDay.waitForExistence(timeout: 5)); firstDay.tap()
        XCTAssertTrue(app.staticTexts["1 Oct 2026"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["No watches logged in this period."].exists)
        capture("Stats empty day")
        app.buttons["Close"].tap(); app.swipeDown()
        app.buttons["stats-calendar"].tap()
        let week = app.buttons["This Week"]
        XCTAssertTrue(week.waitForExistence(timeout: 5)); week.tap()
        XCTAssertTrue(app.buttons["7D"].isSelected)
        XCTAssertFalse(app.buttons["30D"].isSelected)
        capture("Stats week")
        let review = app.buttons["Review dates"]
        if !review.isHittable { app.swipeDown() }
        review.tap()
        XCTAssertTrue(app.staticTexts["Recently watched"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["1 watches"].waitForExistence(timeout: 5))
        capture("Undated history")
    }
    func testLibraryBulkQueueTrashRestoreAndPermanentDeleteInIsolatedFixture() {
        let app = launch(mutations: true); app.buttons["tab-library"].tap()
        app.buttons["title-again"].press(forDuration: 1)
        app.buttons["Select"].tap()
        let other = app.buttons["select-title-after-rain"]
        XCTAssertTrue(other.waitForExistence(timeout: 5)); other.tap()
        XCTAssertTrue(app.staticTexts["2 selected"].exists)
        app.buttons["collection-action"].tap(); app.buttons["Queue"].tap()
        app.buttons["Apply selection action"].tap()
        let confirm = app.buttons["confirm-collection"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5)); capture("Bulk Queue review"); confirm.tap()
        XCTAssertTrue(app.buttons["title-again"].waitForExistence(timeout: 5))
        app.buttons["tab-home"].tap(); app.buttons["queue-shortcut"].tap()
        XCTAssertTrue(app.buttons["title-again"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["title-after-rain"].exists); XCTAssertFalse(app.buttons["title-frieren"].exists)
        app.buttons["title-again"].press(forDuration: 1); app.buttons["Move to Trash"].tap()
        XCTAssertTrue(confirm.waitForExistence(timeout: 5)); confirm.tap()
        let trash = app.buttons["Open Trash"]
        if !trash.isHittable { app.scrollViews.element(boundBy: 0).swipeLeft() }
        trash.tap()
        XCTAssertTrue(app.staticTexts["In Trash"].waitForExistence(timeout: 5)); capture("Trash populated")
        app.buttons["Restore"].tap(); XCTAssertTrue(confirm.waitForExistence(timeout: 5)); confirm.tap()
        XCTAssertTrue(app.staticTexts["Trash is clear"].waitForExistence(timeout: 5))
        app.buttons["Return to Library"].tap()
        XCTAssertTrue(app.buttons["title-again"].waitForExistence(timeout: 5))
        app.buttons["title-again"].press(forDuration: 1); app.buttons["Move to Trash"].tap()
        XCTAssertTrue(confirm.waitForExistence(timeout: 5)); confirm.tap()
        if !trash.isHittable { app.scrollViews.element(boundBy: 0).swipeLeft() }
        trash.tap(); app.buttons["Delete permanently"].tap()
        XCTAssertTrue(confirm.waitForExistence(timeout: 5)); confirm.tap()
        XCTAssertTrue(app.staticTexts["Trash is clear"].waitForExistence(timeout: 5)); capture("Trash after permanent delete")
    }
    func testFilesAndScannerMatchPublishLocationWithoutChangingWatchHistory() {
        let app = launch(scanner: true); app.buttons["tab-more"].tap()
        app.buttons["settings-files"].tap()
        XCTAssertTrue(app.staticTexts["Mapped folders"].waitForExistence(timeout: 5)); capture("Files and drives")
        let review = app.buttons["Fix mismatches →"]
        for _ in 0..<8 { if review.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(review.isHittable); review.tap()
        let match = app.buttons["match-scan-fixture-unmatched"]
        XCTAssertTrue(match.waitForExistence(timeout: 5)); capture("Unmatched scan"); match.tap()
        let search = app.textFields["Search library and online"]
        XCTAssertTrue(search.waitForExistence(timeout: 5)); search.tap(); search.typeText("18 Again\n")
        let chosen = app.buttons["match-title-again"]
        XCTAssertTrue(chosen.waitForExistence(timeout: 5)); chosen.tap()
        XCTAssertTrue(app.staticTexts["No unmatched scans"].waitForExistence(timeout: 5)); capture("Scanner resolved")
        app.buttons["Done"].tap()
        let path = app.staticTexts["R:\\Reference\\Unmatched Series"]
        for _ in 0..<10 { if path.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(path.exists); capture("Confirmed scanned location")
    }
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    private func assertEpisodePieces(_ track: XCUIElement, app: XCUIApplication) {
        guard let image = XCUIScreen.main.screenshot().image.cgImage else { XCTFail("Missing episode screenshot"); return }
        let scale = CGFloat(image.width) / app.frame.width
        // Accessibility reports the visible ink bounds, excluding the SVG's outer margins.
        // Count actual foreground runs instead of deriving slot positions from those bounds.
        let left = floor(track.frame.minX * scale)
        let width = Int(ceil(track.frame.maxX * scale) - left)
        guard width > 0, let row = image.cropping(to: CGRect(x: left, y: floor(track.frame.midY * scale), width: CGFloat(width), height: 1)) else { XCTFail("Missing episode row"); return }
        var bytes = [UInt8](repeating: 0, count: width * 4)
        let rendered = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: 1, bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(row, in: CGRect(x: 0, y: 0, width: CGFloat(width), height: 1)); return true
        }
        XCTAssertTrue(rendered)
        var pieces: [(start: Int, end: Int)] = []
        var insidePiece = false
        for x in 0..<width {
            let foreground = bytes[x * 4] > 35 || bytes[x * 4 + 1] > 35 || bytes[x * 4 + 2] > 40
            if foreground {
                if !insidePiece { pieces.append((start: x, end: x)) }
                else { pieces[pieces.count - 1].end = x }
            }
            insidePiece = foreground
        }
        guard pieces.count == 16 else { XCTFail("Expected 16 separate episode pieces; rendered \(pieces.count)"); return }
        for index in pieces.indices {
            let center = (pieces[index].start + pieces[index].end) / 2
            let piece = [Int(bytes[center * 4]), Int(bytes[center * 4 + 2])]
            if index > 0 { XCTAssertGreaterThan(pieces[index].start - pieces[index - 1].end, 2, "Every adjacent pair must have a visible gap") }
            if index < 8 {
                XCTAssertGreaterThan(piece[0], 120, "Each watched episode must have its own filled piece")
                XCTAssertGreaterThan(piece[1], 180)
            } else {
                XCTAssertLessThan(piece[0], 120, "Unwatched episodes must not appear filled")
                if index == 8 { XCTAssertGreaterThan(piece[1], 70, "Up next must have a softer accent tint") }
            }
        }
    }
    private func sample(_ image: CGImage, at point: CGPoint, scale: CGFloat) -> [Int] {
        guard let pixel = image.cropping(to: CGRect(x: floor(point.x * scale), y: floor(point.y * scale), width: 1, height: 1)) else { XCTFail("Missing pixel sample"); return [0, 0, 0, 0] }
        var bytes = [UInt8](repeating: 0, count: 4)
        let rendered = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(pixel, in: CGRect(x: 0, y: 0, width: 1, height: 1)); return true
        }
        XCTAssertTrue(rendered)
        return bytes.map(Int.init)
    }
    private func assertRangeHighlight(_ button: XCUIElement, app: XCUIApplication) {
        guard let source = XCUIScreen.main.screenshot().image.cgImage else { XCTFail("Missing screenshot"); return }
        let scale = CGFloat(source.width) / app.frame.width
        // Sample the clear left side of the segment, away from label glyphs and borders.
        let point = CGPoint(x: button.frame.minX + button.frame.width * 0.15, y: button.frame.midY)
        let bytes = sample(source, at: point, scale: scale)
        XCTAssertGreaterThan(bytes[0], 120, "The selected range must visibly use the accent fill")
        XCTAssertGreaterThan(bytes[2], 180, "A selected accessibility trait alone is insufficient")
    }
}
