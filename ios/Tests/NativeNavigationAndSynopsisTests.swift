import XCTest
import SwiftUI
@testable import TwilDiary

@MainActor final class NativeNavigationAndSynopsisTests: XCTestCase {
    func testDonePopsOnlyTheOwningStackAndKeepsOtherTabHistory() {
        let router = AppRouter()
        router.paths[.home] = NavigationPath([AppDestination.explore, AppDestination.history])
        router.paths[.more] = NavigationPath([AppDestination.files])
        router.selectedTab = .home
        XCTAssertTrue(router.goBack(tab: .more))
        XCTAssertEqual(router.paths[.more]?.count, 0)
        XCTAssertEqual(router.paths[.home]?.count, 2)
        XCTAssertEqual(router.selectedTab, .home)
    }
    func testDoneRemovesExactlyOneRouteAndAnEmptyStackUsesDismissFallback() {
        let router = AppRouter(); router.selectedTab = .library
        var path = NavigationPath(); path.append("again"); path.append(AppDestination.files)
        router.paths[.library] = path
        XCTAssertTrue(router.goBack()); XCTAssertEqual(router.paths[.library]?.count, 1)
        XCTAssertTrue(router.goBack()); XCTAssertEqual(router.paths[.library]?.count, 0)
        XCTAssertFalse(router.goBack()); XCTAssertFalse(router.goBack(tab: .stats))
    }
    func testNestedDoneActionUsesItsOwnStackInsteadOfTheParent() {
        let router = AppRouter(); router.paths[.more] = NavigationPath([AppDestination.files])
        let sheet = AppRouter(); sheet.paths[.home] = NavigationPath([AppDestination.explore, AppDestination.history])
        let action = DiaryBackAction { sheet.goBack(tab: .home) }
        XCTAssertTrue(action.perform()); XCTAssertEqual(sheet.paths[.home]?.count, 1)
        XCTAssertEqual(router.paths[.more]?.count, 1)
    }
    func testShortSynopsisStaysBesideTheCoverWithoutAContinuation() {
        let text = "A short story."
        let parts = SynopsisTextLayout.split(text, width: 200)
        XCTAssertEqual(parts.leading, text); XCTAssertEqual(parts.continuation, "")
    }
    func testSynopsisOverflowPreservesEveryCharacterAndUsesTheMeasuredWidth() {
        let text = String(repeating: "A father gets an unexpected chance to see his family from a new perspective. ", count: 8)
        let narrow = SynopsisTextLayout.split(text, width: 130), wide = SynopsisTextLayout.split(text, width: 250)
        for value in [narrow, wide] {
            XCTAssertFalse(value.leading.isEmpty); XCTAssertFalse(value.continuation.isEmpty)
            XCTAssertEqual(value.leading + value.continuation, text)
        }
        XCTAssertGreaterThan(wide.leading.count, narrow.leading.count)
    }
    func testSynopsisContinuationDoesNotSplitComposedEmojiOrAccentedCharacters() {
        let text = String(repeating: "👩🏽‍🚀 家族 e\u{301} 👨‍👩‍👧‍👦 Wednesday — a story. ", count: 20)
        for width in [CGFloat(80), 130, 200] {
            let parts = SynopsisTextLayout.split(text, width: width)
            XCTAssertEqual(parts.leading + parts.continuation, text)
            XCTAssertEqual(Array(parts.leading) + Array(parts.continuation), Array(text))
            XCTAssertFalse(parts.continuation.isEmpty)
        }
    }
    func testEmptyAndUnmeasuredSynopsisRemainLossless() {
        XCTAssertEqual(SynopsisTextLayout.split("", width: 100), .init(leading: "", continuation: ""))
        XCTAssertEqual(SynopsisTextLayout.split("Not measured", width: 0), .init(leading: "Not measured", continuation: ""))
    }
}
