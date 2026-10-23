import XCTest

@MainActor
final class FoundationUITests: XCTestCase {
    func testFoundationLaunchAndInteraction() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["foundation-title"].waitForExistence(timeout: 10))
        capture("Foundation launch")
        app.buttons["foundation-verify"].tap()
        XCTAssertEqual(app.buttons["foundation-verify"].label, "Interaction verified")
        capture("Foundation interaction")
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
