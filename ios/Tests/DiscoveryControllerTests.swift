import XCTest
import TwilDiaryCore
@testable import TwilDiary

@MainActor private final class DiscoveryStub: DiscoveryServing {
    var connected = true
    var requests: [[String: String]] = []
    var delayed: CheckedContinuation<CatalogPage, any Error>?
    var failMovies = false
    var failTV = false
    var wrongPage = false
    func traktConnected() async throws -> Bool { connected }
    func page(_ query: [String: String]) async throws -> CatalogPage {
        requests.append(query)
        if query["genre"] == "Delayed" { return try await withCheckedThrowingContinuation { delayed = $0 } }
        if (query["type"] == "movie" && failMovies) || (query["type"] == "tv" && failTV) { throw APIError.message("Synthetic provider unavailable") }
        let kind = MediaKind(rawValue: query["type"] ?? "tv") ?? .tv, page = Int(query["page"] ?? "1") ?? 1
        let first = CatalogItem(id: 1, mediaType: kind, name: "First"), second = CatalogItem(id: 2, mediaType: kind, name: "Second")
        return CatalogPage(items: page == 1 ? [first] : [first, second], page: wrongPage ? 1 : page, totalPages: 2)
    }
}

@MainActor final class DiscoveryControllerTests: XCTestCase {
    func testPagingRetainsFirstIdentityAndRejectsAnotherFilterScope() async {
        let service = DiscoveryStub()
        let results = DiscoveryResults(service: service)
        var filters = DiscoveryFilters(section: .genres); filters.genre = "Drama"
        await results.load(filters.query(section: .genres))
        XCTAssertTrue(results.hasMore)
        await results.load(filters.query(section: .genres), more: true)
        XCTAssertEqual(results.items.map(\.key), ["tv:1", "tv:2"])
        XCTAssertFalse(results.hasMore)
        filters.genre = "Animation"
        await results.load(filters.query(section: .genres), more: true)
        XCTAssertEqual(service.requests.count, 2)
    }
    func testLateFilterResponseCannotReplaceTheLatestGrid() async {
        let service = DiscoveryStub()
        let model = DiscoveryResults(service: service)
        var old = DiscoveryFilters(section: .genres); old.genre = "Delayed"
        let query = old.query(section: .genres)
        let pending = Task { await model.load(query) }
        while service.delayed == nil { await Task.yield() }
        var fresh = DiscoveryFilters(section: .genres); fresh.type = "movie"
        await model.load(fresh.query(section: .genres))
        service.delayed?.resume(returning: CatalogPage(items: [CatalogItem(id: 99, mediaType: .tv, name: "Stale")], page: 1, totalPages: 1))
        await pending.value
        XCTAssertEqual(model.items.map(\.key), ["movie:1"])
        XCTAssertFalse(model.loading)
    }
    func testAppendFailureKeepsTheConfirmedPageAndCanRetryIt() async {
        let service = DiscoveryStub()
        let results = DiscoveryResults(service: service), query = DiscoveryFilters(section: .ratedShows).query(section: .ratedShows)
        await results.load(query)
        service.failTV = true; await results.load(query, more: true)
        XCTAssertEqual(results.items.map(\.id), [1]); XCTAssertEqual(results.page, 1); XCTAssertNotNil(results.error)
        service.failTV = false; await results.load(query, more: true)
        XCTAssertEqual(results.items.map(\.id), [1, 2]); XCTAssertNil(results.error)
    }
    func testUnexpectedProviderPageDoesNotPublishOrAdvance() async {
        let service = DiscoveryStub()
        let results = DiscoveryResults(service: service), query = DiscoveryFilters(section: .ratedShows).query(section: .ratedShows)
        await results.load(query)
        service.wrongPage = true; await results.load(query, more: true)
        XCTAssertEqual(results.page, 1); XCTAssertEqual(results.items.count, 1); XCTAssertNotNil(results.error)
    }
    func testRecommendationsKeepSuccessfulTypeAndDoNotRequestDisconnectedProvider() async {
        let service = DiscoveryStub()
        let model = DiscoveryRecommendations(service: service)
        service.failMovies = true; await model.load(limit: 24)
        XCTAssertEqual(model.items.map(\.key), ["tv:1"])
        XCTAssertEqual(model.error, "Some recommendations could not load.")
        XCTAssertTrue(service.requests.allSatisfy { $0["source"] == "trakt" && $0["limit"] == "24" && $0["page"] == "1" })
        service.requests = []; service.connected = false; await model.load()
        XCTAssertTrue(service.requests.isEmpty); XCTAssertTrue(model.items.isEmpty); XCTAssertFalse(model.connected)
    }
}
