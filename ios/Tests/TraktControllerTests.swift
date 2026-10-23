import XCTest
import TwilDiaryCore
@testable import TwilDiary

@MainActor final class TraktControllerTests: XCTestCase {
    func testScanPreparesReviewWithoutApplyingAnyChanges() async {
        let controller = TraktController(service: FixtureTraktService())
        await controller.refresh(); await controller.scan(start: true)
        XCTAssertEqual(controller.sync?.run?.state, "review")
        XCTAssertEqual(controller.sync?.pendingChanges, 8)
        XCTAssertTrue(controller.sync?.items.allSatisfy { $0.state == "pending" } == true)
        XCTAssertFalse(controller.busy)
    }
    func testBulkApplyLeavesConflictsForExplicitReview() async {
        let controller = TraktController(service: FixtureTraktService())
        await controller.refresh(); await controller.apply()
        XCTAssertEqual(controller.sync?.pendingChanges, 1)
        XCTAssertEqual(controller.sync?.readyChanges, 0)
        XCTAssertEqual(controller.sync?.items.filter { $0.state == "pending" }.count, 1)
        XCTAssertTrue(controller.sync?.items.first { $0.state == "pending" }?.review == true)
    }
    func testKeepLocalAndUseTraktAreSeparateExplicitChoices() async throws {
        for choice in [TraktChoice.local, .trakt] {
            let controller = TraktController(service: FixtureTraktService())
            await controller.refresh()
            let conflict = try XCTUnwrap(controller.sync?.items.first { $0.review })
            await controller.apply(change: conflict, choice: choice)
            XCTAssertEqual(controller.sync?.items.first { $0.id == conflict.id }?.state, "applied")
            XCTAssertEqual(controller.sync?.pendingChanges, 7)
            XCTAssertNil(controller.error)
        }
    }
    func testSkippingLeavesOtherItemsPendingAndFiltersDoNotChangeCounts() async throws {
        let controller = TraktController(service: FixtureTraktService())
        await controller.refresh()
        let item = try XCTUnwrap(controller.sync?.items.first)
        await controller.apply(change: item, choice: .skip)
        XCTAssertEqual(controller.sync?.items.first { $0.id == item.id }?.state, "skipped")
        XCTAssertEqual(controller.sync?.pendingChanges, 7)
        controller.kind = .rating; await controller.refresh()
        XCTAssertEqual(controller.visibleItems.count, 3)
        XCTAssertTrue(controller.visibleItems.allSatisfy { $0.kind == "rating" })
        XCTAssertEqual(controller.sync?.pendingChanges, 7)
    }
    func testDisconnectKeepsTheDiaryOutsideProviderState() async {
        let controller = TraktController(service: FixtureTraktService())
        await controller.refresh(); await controller.disconnect()
        XCTAssertFalse(controller.status?.connected ?? true)
        XCTAssertNil(controller.sync?.run)
        XCTAssertNil(controller.error)
    }
}
