import XCTest
import UIKit

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
        XCTAssertTrue(app.staticTexts["Episodes"].waitForExistence(timeout: 5))
        let track = app.otherElements["episode-progress"]
        XCTAssertTrue(track.waitForExistence(timeout: 5))
        XCTAssertEqual(track.value as? String, "8 of 16 episodes watched")
        assertEpisodePieces(track, app: app)
        capture("Title detail")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["title-quiet-orbit"].tap()
        XCTAssertTrue(app.progressIndicators["movie-progress"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.otherElements["episode-progress"].exists)
        capture("Movie detail")
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
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    private func assertEpisodePieces(_ track: XCUIElement, app: XCUIApplication) {
        guard let image = XCUIScreen.main.screenshot().image.cgImage else { XCTFail("Missing episode screenshot"); return }
        let scale = CGFloat(image.width) / app.frame.width
        let slot = track.frame.width / 16
        for index in 0..<16 {
            let piece = sample(image, at: CGPoint(x: track.frame.minX + (CGFloat(index) + 5.5 / 12) * slot, y: track.frame.midY), scale: scale)
            let gap = sample(image, at: CGPoint(x: track.frame.minX + (CGFloat(index) + 11.0 / 12) * slot, y: track.frame.midY), scale: scale)
            XCTAssertLessThan(gap[0], 35, "Each episode must have a visible gap after it")
            if index < 8 {
                XCTAssertGreaterThan(piece[0], 120, "Each watched episode must have its own filled piece")
                XCTAssertGreaterThan(piece[2], 180)
            } else {
                XCTAssertGreaterThan(piece[2], gap[2] + 10, "Unwatched pieces must remain visible")
                XCTAssertLessThan(piece[0], 120, "Unwatched episodes must not appear filled")
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
