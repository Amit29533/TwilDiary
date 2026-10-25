#if DEBUG
import Foundation
import TwilDiaryCore

/// Isolated simulator provider. No HTTP requests or real-account changes are possible here.
@MainActor final class FixtureTraktService: TraktServicing {
    private var connection: TraktStatus
    private var snapshot: TraktSync
    private let unavailable: Bool
    init(scenario: String = "review") {
        unavailable = scenario == "unavailable"
        let statusURL = Bundle.main.url(forResource: "trakt-status", withExtension: "json")!
        let syncURL = Bundle.main.url(forResource: "trakt-sync", withExtension: "json")!
        connection = try! JSONDecoder().decode(TraktStatus.self, from: Data(contentsOf: statusURL))
        snapshot = try! JSONDecoder().decode(TraktSync.self, from: Data(contentsOf: syncURL))
        if scenario == "disconnected" {
            connection = TraktStatus(configured: true, connected: false)
            snapshot.run = nil; snapshot.items = []; snapshot.counts = [:]
        } else if scenario == "reconnect" { connection = TraktStatus(configured: true, connected: true, username: "reference-user", needsReconnect: true) }
        else if scenario == "scanning" { snapshot.run?.state = "building" }
        else if scenario == "comparing" {
            snapshot.run = try! JSONDecoder().decode(TraktSync.Run.self, from: Data(#"{"id":"fixture-comparing","state":"building","stage":"plan-remote-batch","page":481,"progress":2185,"retryAfter":0}"#.utf8))
            snapshot.counts = ["pending": 720, "links": 2]
        }
    }
    func status() async throws -> TraktStatus { if unavailable { throw APIError.message("The connection is temporarily unavailable. Try again.") }; return connection }
    func review(kind: TraktKind, query: String, after: String?) async throws -> TraktSync {
        var result = snapshot
        result.items = result.items.filter { (kind == .all || $0.kind == kind.rawValue) && (query.isEmpty || $0.name.localizedCaseInsensitiveContains(query)) }
        return result
    }
    func start(mode: TraktRatingMode) async throws -> String {
        self.snapshot = FixtureTraktService().snapshot
        snapshot.run?.state = "building"
        return snapshot.run!.id
    }
    func step(id: String) async throws -> TraktSync { snapshot.run?.state = "review"; return snapshot }
    func apply(id: String, change: String?, choice: TraktChoice) async throws -> TraktSync {
        for index in snapshot.items.indices {
            let item = snapshot.items[index]
            guard item.state == "pending", change.map({ $0 == item.id }) ?? (!item.review && !item.blocked) else { continue }
            if item.review && choice == .apply { throw APIError.message("Choose Keep TwilDiary or Use Trakt for this conflict.") }
            if item.blocked && choice != .skip { throw APIError.message("This item needs to be skipped.") }
            snapshot.items[index].state = choice == .skip ? "skipped" : "applied"
        }
        snapshot.counts["pending"] = snapshot.items.filter { $0.state == "pending" }.count
        snapshot.counts["safe"] = snapshot.items.filter { $0.state == "pending" && !$0.review && !$0.blocked }.count
        snapshot.counts["skipped"] = snapshot.items.filter { $0.state == "skipped" }.count
        if snapshot.counts["pending"] == 0 { snapshot.run?.state = "complete" }
        return snapshot
    }
    func cancel(id: String) async throws { snapshot.run?.state = "cancelled" }
    func disconnect() async throws { connection.connected = false; snapshot.run = nil; snapshot.items = []; snapshot.counts = [:] }
}
#endif

@MainActor func makeTraktService(store: DiaryStore) -> any TraktServicing {
    #if DEBUG
    if store.isPreview {
        let prefix = "--ui-trakt="
        let scenario = ProcessInfo.processInfo.arguments.first { $0.hasPrefix(prefix) }.map { String($0.dropFirst(prefix.count)) } ?? "review"
        return FixtureTraktService(scenario: scenario)
    }
    #endif
    return LiveTraktService(store: store)
}
