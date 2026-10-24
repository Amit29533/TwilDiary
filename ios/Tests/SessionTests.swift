import XCTest
import TwilDiaryCore
@testable import TwilDiary

@MainActor private final class MemorySessionStorage: SessionStoring {
    var credential: AccessCredential?
    var rejectSave = false
    func read() -> AccessCredential? { credential }
    func save(_ value: AccessCredential) throws {
        if rejectSave { throw APIError.message("Test storage unavailable") }
        credential = value
    }
    func delete() { credential = nil }
}

private final class StubProtocol: URLProtocol, @unchecked Sendable {
    struct Reply: Sendable {
        let status: Int
        let contentType: String
        let body: String
        var delay: TimeInterval = 0
        init(_ body: String) { self.init(200, body) }
        init(_ status: Int, _ body: String, contentType: String = "application/json") {
            self.status = status; self.body = body; self.contentType = contentType
        }
    }
    final class State: @unchecked Sendable {
        let lock = NSLock()
        private var handler: @Sendable (URLRequest) -> Reply = { _ in Reply(500, "{}") }
        private var requests: [URLRequest] = []
        func reset(_ handler: @escaping @Sendable (URLRequest) -> Reply) {
            lock.lock(); defer { lock.unlock() }
            self.handler = handler; requests = []
        }
        func reply(_ request: URLRequest) -> Reply {
            var recorded = request
            if recorded.httpBody == nil, let stream = recorded.httpBodyStream {
                stream.open(); defer { stream.close() }
                var data = Data(), buffer = [UInt8](repeating: 0, count: 4096)
                while stream.hasBytesAvailable { let count = stream.read(&buffer, maxLength: buffer.count); if count <= 0 { break }; data.append(contentsOf: buffer.prefix(count)) }
                recorded.httpBody = data
            }
            lock.lock(); requests.append(recorded); let handler = handler; lock.unlock()
            return handler(recorded)
        }
        func recorded() -> [URLRequest] {
            lock.lock(); defer { lock.unlock() }; return requests
        }
    }
    static let state = State()
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let reply = Self.state.reply(request)
        if reply.delay > 0 {
            DispatchQueue.global().asyncAfter(deadline: .now() + reply.delay) { self.deliver(reply) }
        } else { deliver(reply) }
    }
    private func deliver(_ reply: Reply) {
        let response = HTTPURLResponse(url: request.url!, statusCode: reply.status, httpVersion: nil,
                                       headerFields: ["Content-Type": reply.contentType])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(reply.body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@MainActor final class SessionTests: XCTestCase {
    private let credential = AccessCredential(token: "synthetic-test-session", expires: .distantFuture)
    private func api(_ storage: MemorySessionStorage) -> DiaryAPI {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubProtocol.self]
        return DiaryAPI(configuration: configuration, storage: storage)
    }

    func testCatalogSeasonUsesReadOnlyEndpointAndExplicitSpoilerChoice() async throws {
        let storage = MemorySessionStorage(); storage.credential = credential
        StubProtocol.state.reset { _ in .init(#"{"items":[{"number":1,"name":"","overview":"","airedOn":null,"stillPath":null,"communityScore":8.1}]}"#) }
        let store = DiaryStore(api: api(storage))
        let result = try await store.catalogEpisodes(CatalogRoute(kind: .tv, id: 900001), season: 2, reveal: false)
        XCTAssertEqual(result.items.first?.name, "")
        _ = try await store.catalogEpisodes(CatalogRoute(kind: .tv, id: 900001), season: 2, reveal: true)
        let requests = StubProtocol.state.recorded()
        XCTAssertEqual(requests.count, 2)
        for request in requests { XCTAssertEqual(request.httpMethod, "GET"); XCTAssertEqual(request.url?.path, "/api/metadata/season") }
        let firstQuery = URLComponents(url: try XCTUnwrap(requests.first?.url), resolvingAgainstBaseURL: false)?.queryItems
        XCTAssertEqual(firstQuery?.first { $0.name == "season" }?.value, "2")
        XCTAssertEqual(firstQuery?.first { $0.name == "reveal" }?.value, "0")
        let lastQuery = URLComponents(url: try XCTUnwrap(requests.last?.url), resolvingAgainstBaseURL: false)?.queryItems
        XCTAssertEqual(lastQuery?.first { $0.name == "reveal" }?.value, "1")
        do { _ = try await store.catalogEpisodes(CatalogRoute(kind: .movie, id: 900001), season: 1, reveal: false); XCTFail("Movies must not fetch seasons") } catch { }
        XCTAssertEqual(StubProtocol.state.recorded().count, 2)
    }
    func testCatalogImportRefreshFailureKeepsConfirmedIdentityRetrySafe() async throws {
        let storage = MemorySessionStorage(); storage.credential = credential
        StubProtocol.state.reset { request in
            if request.url?.path == "/api/metadata/import" { return .init(#"{"title":{"id":"tmdb-tv-900001"}}"#) }
            return .init(503, #"{"error":{"message":"Synthetic read outage"}}"#)
        }
        let store = DiaryStore(api: api(storage)), details = PreviewCatalog.browse(CatalogRoute(kind: .tv, id: 900001)).details
        let first = await store.importTitle(details, category: details.suggestedCategory)
        XCTAssertNil(first); XCTAssertFalse(store.busy)
        XCTAssertTrue(store.error?.contains("a second copy will not be created") == true)
        let request = try XCTUnwrap(StubProtocol.state.recorded().first)
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: try XCTUnwrap(request.httpBody)) as? [String: Any])
        XCTAssertEqual(request.httpMethod, "POST"); XCTAssertEqual(body["mediaType"] as? String, "tv"); XCTAssertEqual(body["tmdbId"] as? Int, 900001)
        XCTAssertEqual(body["status"] as? String, "planned"); XCTAssertTrue(body["score"] is NSNull)
    }

    func testManualCreateRefreshFailureRetainsCallerIdentityAndExplicitNulls() async throws {
        let storage = MemorySessionStorage(); storage.credential = credential
        StubProtocol.state.reset { request in
            if request.url?.path == "/api/titles" { return .init(#"{"title":{"id":"manual-reference"}}"#) }
            return .init(503, #"{"error":{"message":"Synthetic read outage"}}"#)
        }
        let store = DiaryStore(api: api(storage)); var draft = ManualTitleDraft(); draft.name = "Reference"
        do { _ = try await store.createManualTitle(draft.validated(id: "manual-reference")); XCTFail("A failed refresh must remain retryable") }
        catch { XCTAssertTrue(error.localizedDescription.contains("a second copy will not be created")) }
        XCTAssertFalse(store.busy)
        let request = try XCTUnwrap(StubProtocol.state.recorded().first)
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: try XCTUnwrap(request.httpBody)) as? [String: Any])
        XCTAssertEqual(body["id"] as? String, "manual-reference"); XCTAssertTrue(body["score"] is NSNull); XCTAssertTrue(body["year"] is NSNull)
    }

    func testLateCatalogImportCannotPublishAnErrorAfterSignOut() async {
        let storage = MemorySessionStorage(); storage.credential = credential
        StubProtocol.state.reset { _ in var reply = StubProtocol.Reply(#"{"title":{"id":"tmdb-tv-900001"}}"#); reply.delay = 0.15; return reply }
        let store = DiaryStore(api: api(storage)), details = PreviewCatalog.browse(CatalogRoute(kind: .tv, id: 900001)).details
        let task = Task { await store.importTitle(details, category: details.suggestedCategory) }
        while StubProtocol.state.recorded().isEmpty { await Task.yield() }
        store.signOut(); let result = await task.value
        XCTAssertNil(result); XCTAssertNil(store.error); XCTAssertTrue(store.needsSignIn); XCTAssertFalse(store.busy)
        XCTAssertTrue(store.workspace.titles.isEmpty)
    }

    func testSignInSurvivesDatabaseQuotaAndDoesNotProbeWorkspaceForAuthentication() async {
        StubProtocol.state.reset { request in
            if request.url?.path == "/api/session" { return .init(#"{"authenticated":true}"#) }
            return .init(503, #"{"error":{"code":"database_read_limit","message":"Quota exhausted","resetAt":"2026-10-24T00:00:00.000Z"}}"#)
        }
        let storage = MemorySessionStorage(), api = api(storage)
        let store = DiaryStore(api: api)
        await store.connect(credential)
        XCTAssertFalse(store.needsSignIn)
        XCTAssertFalse(store.hasLoadedWorkspace)
        XCTAssertFalse(store.loading)
        XCTAssertEqual(storage.credential?.token, credential.token)
        XCTAssertEqual(api.credential?.token, credential.token)
        XCTAssertTrue(store.error?.contains("daily database limit") == true)
        let requests = StubProtocol.state.recorded()
        XCTAssertEqual(requests.map { $0.url?.path }, ["/api/session", "/api/workspace"])
        XCTAssertEqual(requests.last?.url?.query, "section=titles")
        XCTAssertEqual(requests.first?.value(forHTTPHeaderField: "Cookie"), "CF_Authorization=synthetic-test-session")
    }

    func testSuccessfulConnectionLoadsEachSectionOnceAndAllowsEmptyDiaries() async {
        StubProtocol.state.reset { request in
            .init(request.url?.path == "/api/session" ? #"{"authenticated":true}"# : #"{"items":[],"next":null}"#)
        }
        let storage = MemorySessionStorage(), store = DiaryStore(api: api(storage))
        await store.connect(credential)
        XCTAssertFalse(store.needsSignIn)
        XCTAssertTrue(store.hasLoadedWorkspace)
        XCTAssertNil(store.error)
        XCTAssertEqual(StubProtocol.state.recorded().count, 5)
        store.signOut()
        XCTAssertTrue(store.needsSignIn)
        XCTAssertFalse(store.hasLoadedWorkspace)
        XCTAssertNil(storage.credential)
    }

    func testFailedRefreshPreservesPreviouslyLoadedDiaryAndSession() async {
        StubProtocol.state.reset { _ in .init(503, "Service temporarily unavailable", contentType: "text/plain") }
        let storage = MemorySessionStorage(); storage.credential = credential
        let store = DiaryStore(api: api(storage))
        store.workspace = PreviewData.workspace; store.hasLoadedWorkspace = true
        let ids = store.workspace.titles.map(\.id)
        await store.refresh()
        XCTAssertFalse(store.needsSignIn)
        XCTAssertTrue(store.hasLoadedWorkspace)
        XCTAssertEqual(store.workspace.titles.map(\.id), ids)
        XCTAssertNotNil(store.error)
    }

    func testAuthenticationRejectionDoesNotSaveCredential() async {
        StubProtocol.state.reset { _ in .init(401, "Access denied", contentType: "text/plain") }
        let storage = MemorySessionStorage(), store = DiaryStore(api: api(storage))
        await store.connect(credential)
        XCTAssertTrue(store.needsSignIn)
        XCTAssertNil(storage.credential)
        XCTAssertFalse(store.hasLoadedWorkspace)
    }

    func testStorageFailureDoesNotPretendSignInSucceeded() async {
        StubProtocol.state.reset { _ in .init(#"{"authenticated":true}"#) }
        let storage = MemorySessionStorage(); storage.rejectSave = true
        let api = api(storage), store = DiaryStore(api: api)
        await store.connect(credential)
        XCTAssertTrue(store.needsSignIn)
        XCTAssertNil(api.credential)
        XCTAssertNil(storage.credential)
        XCTAssertEqual(store.error, "Test storage unavailable")
    }

    func testWriteQuotaParsesResetWithoutSigningOut() async throws {
        StubProtocol.state.reset { _ in
            .init(503, #"{"error":{"code":"database_write_limit","message":"Quota exhausted","resetAt":"2026-10-24T00:00:00Z"}}"#)
        }
        let storage = MemorySessionStorage(); storage.credential = credential
        do {
            let _: EmptyResponse = try await api(storage).request("/api/workspace")
            XCTFail("Expected quota error")
        } catch APIError.databaseLimit(let reset) {
            XCTAssertEqual(reset, ISO8601DateFormatter().date(from: "2026-10-24T00:00:00Z"))
        } catch { XCTFail("Unexpected error: \(error)") }
    }

    func testUnexpectedSuccessfulHTMLIsNotReportedAsExpiredSession() async {
        StubProtocol.state.reset { _ in .init(200, "<html>Unavailable</html>", contentType: "text/html") }
        let storage = MemorySessionStorage(); storage.credential = credential
        do {
            let _: EmptyResponse = try await api(storage).request("/api/workspace")
            XCTFail("Expected response error")
        } catch APIError.message(let message) {
            XCTAssertTrue(message.contains("unexpected response"))
        } catch { XCTFail("Unexpected error: \(error)") }
    }
    func testCachedDiaryRestoresOnlyForCurrentSessionAndSignOutErasesIt() async throws {
        let cache = MemoryWorkspaceCache()
        try cache.save(PreviewData.workspace, scope: credential.cacheScope, at: .now)
        let storage = MemorySessionStorage(); storage.credential = credential
        let store = DiaryStore(api: api(storage), cache: cache)
        XCTAssertTrue(store.hasLoadedWorkspace); XCTAssertTrue(store.showingCachedSnapshot)
        XCTAssertEqual(store.workspace.titles.count, PreviewData.workspace.titles.count)
        StubProtocol.state.reset { _ in .init(503, "Offline", contentType: "text/plain") }
        await store.refresh()
        XCTAssertTrue(store.showingCachedSnapshot)
        XCTAssertFalse(store.workspace.titles.isEmpty)
        store.signOut()
        XCTAssertTrue(store.workspace.titles.isEmpty)
        XCTAssertNil(cache.load(scope: credential.cacheScope))
    }
    func testSignOutWhileLoadingCannotResurrectSessionOrDiary() async throws {
        StubProtocol.state.reset { _ in
            var reply = StubProtocol.Reply(#"{"items":[],"next":null}"#); reply.delay = 0.15; return reply
        }
        let storage = MemorySessionStorage(); storage.credential = credential
        let cache = MemoryWorkspaceCache(), store = DiaryStore(api: api(storage), cache: cache)
        let refresh = Task { await store.refresh() }
        for _ in 0..<100 {
            if !StubProtocol.state.recorded().isEmpty { break }
            try await Task.sleep(for: .milliseconds(5))
        }
        XCTAssertFalse(StubProtocol.state.recorded().isEmpty)
        store.signOut(); await refresh.value
        XCTAssertTrue(store.needsSignIn)
        XCTAssertFalse(store.hasLoadedWorkspace)
        XCTAssertTrue(store.workspace.titles.isEmpty)
        XCTAssertNil(cache.load(scope: credential.cacheScope))
        XCTAssertNil(storage.credential)
    }
    func testSignOutDuringAuthenticationCannotSaveALateCredential() async throws {
        StubProtocol.state.reset { _ in
            var reply = StubProtocol.Reply(#"{"authenticated":true}"#); reply.delay = 0.15; return reply
        }
        let storage = MemorySessionStorage(), store = DiaryStore(api: api(storage))
        let connection = Task { await store.connect(credential) }
        for _ in 0..<100 {
            if !StubProtocol.state.recorded().isEmpty { break }
            try await Task.sleep(for: .milliseconds(5))
        }
        store.signOut(); await connection.value
        XCTAssertTrue(store.needsSignIn)
        XCTAssertNil(storage.credential)
        XCTAssertEqual(StubProtocol.state.recorded().count, 1)
    }
    func testSlowerRefreshCannotOverwriteNewerCompleteSnapshot() async throws {
        let original = PreviewData.workspace.titles
        var edited = original; edited[0].name = "Newer confirmed title"
        func page(_ titles: [MediaTitle]) throws -> String {
            let items = try JSONSerialization.jsonObject(with: JSONEncoder().encode(titles))
            return String(decoding: try JSONSerialization.data(withJSONObject: ["items": items, "next": NSNull()]), as: UTF8.self)
        }
        let oldPage = try page(original), newPage = try page(edited)
        StubProtocol.state.reset { request in
            if request.url?.query == "section=titles" {
                let first = StubProtocol.state.recorded().filter { $0.url?.query == "section=titles" }.count == 1
                var reply = StubProtocol.Reply(first ? oldPage : newPage)
                if first { reply.delay = 0.2 }
                return reply
            }
            return .init(#"{"items":[],"next":null}"#)
        }
        let storage = MemorySessionStorage(); storage.credential = credential
        let store = DiaryStore(api: api(storage))
        let earlier = Task { await store.refresh() }
        for _ in 0..<100 {
            if !StubProtocol.state.recorded().isEmpty { break }
            try await Task.sleep(for: .milliseconds(5))
        }
        try await store.reload(); await earlier.value
        XCTAssertEqual(store.workspace.titles.first?.name, "Newer confirmed title")
        XCTAssertTrue(store.hasLoadedWorkspace)
        XCTAssertNil(store.error)
    }
    func testEpisodeToggleUsesEpisodeIdentityAndRetainsUndoReceipt() async throws {
        let workspace = PreviewData.workspace
        let title = try XCTUnwrap(workspace.titles.first { $0.id == "again" })
        let episode = try XCTUnwrap(workspace.episodes.first { $0.titleId == title.id && $0.number == 9 })
        let date = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-10-23T12:00:00Z"))
        let event: [String: Any] = ["id": "fixture-new-watch", "operationId": "fixture-operation", "titleId": title.id, "episodeId": episode.id, "watchedAt": date.ISO8601Format(), "recordedAt": date.ISO8601Format(), "revokedAt": NSNull(), "origin": "manual", "version": 1]
        let receipt = String(decoding: try JSONSerialization.data(withJSONObject: ["event": event, "added": true]), as: UTF8.self)
        let pages = try workspacePages(workspace)
        StubProtocol.state.reset { request in
            if request.httpMethod == "POST" { return .init(receipt) }
            if request.httpMethod == "PATCH" { return .init(receipt) }
            return .init(pages[request.url?.query ?? ""] ?? #"{"items":[],"next":null}"#)
        }
        let storage = MemorySessionStorage(); storage.credential = credential
        let store = DiaryStore(api: api(storage)); store.workspace = workspace; store.hasLoadedWorkspace = true
        let success = await store.recordViewing(title, episode: episode, watchedAt: date)
        XCTAssertTrue(success); XCTAssertEqual(store.undoLabel, "Watch marked")
        let write = try XCTUnwrap(StubProtocol.state.recorded().first { $0.httpMethod == "POST" })
        let body = try bodyObject(write)
        XCTAssertEqual(body["episodeId"] as? String, episode.id)
        XCTAssertEqual(body["rewatch"] as? Bool, false)
        await store.undo()
        XCTAssertNil(store.undoLabel)
        XCTAssertEqual(StubProtocol.state.recorded().filter { $0.httpMethod == "PATCH" }.map { $0.url?.path }, ["/api/watch-events/fixture-new-watch"])
    }
    func testUncertainViewingRetryKeepsItsOperationIdentityAndOriginalDate() async throws {
        let workspace = PreviewData.workspace, title = try XCTUnwrap(PreviewData.workspace.titles.first { !$0.isSeries })
        let date = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-10-23T12:00:00Z"))
        let event: [String: Any] = ["id": "fixture-viewing", "operationId": "fixture-operation", "titleId": title.id, "episodeId": NSNull(), "watchedAt": date.ISO8601Format(), "recordedAt": date.ISO8601Format(), "revokedAt": NSNull(), "origin": "manual", "version": 1]
        let receipt = String(decoding: try JSONSerialization.data(withJSONObject: ["event": event, "added": true]), as: UTF8.self)
        let pages = try workspacePages(workspace)
        StubProtocol.state.reset { request in
            if request.httpMethod == "POST" {
                return StubProtocol.state.recorded().filter { $0.httpMethod == "POST" }.count == 1 ? .init(503, #"{"error":{"message":"Response uncertain"}}"#) : .init(receipt)
            }
            return .init(pages[request.url?.query ?? ""] ?? #"{"items":[],"next":null}"#)
        }
        let storage = MemorySessionStorage(); storage.credential = credential
        let store = DiaryStore(api: api(storage)); store.workspace = workspace; store.hasLoadedWorkspace = true
        let first = await store.recordViewing(title, rewatch: true, watchedAt: date)
        XCTAssertFalse(first)
        let second = await store.recordViewing(title, rewatch: true, watchedAt: date.addingTimeInterval(1))
        XCTAssertTrue(second)
        let writes = StubProtocol.state.recorded().filter { $0.httpMethod == "POST" }
        XCTAssertEqual(writes.count, 2)
        let firstBody = try bodyObject(writes[0]), secondBody = try bodyObject(writes[1])
        XCTAssertEqual(firstBody["operationId"] as? String, secondBody["operationId"] as? String)
        XCTAssertEqual(firstBody["watchedAt"] as? String, secondBody["watchedAt"] as? String)
        XCTAssertEqual(secondBody["rewatch"] as? Bool, true)
    }
    func testRemovingLatestRejectsChangedDisplayedEventBeforeAnyWrite() async throws {
        let workspace = PreviewData.workspace, title = try XCTUnwrap(PreviewData.workspace.titles.first { $0.id == "again" })
        let displayed = PreviewData.card(title, workspace: workspace).previous
        StubProtocol.state.reset { _ in .init(#"{"progress":{"watched":9,"total":16},"previous":{"id":"different-watch","version":1,"episodeId":"different-episode","number":9},"next":null,"season":null}"#) }
        let storage = MemorySessionStorage(); storage.credential = credential
        let store = DiaryStore(api: api(storage)); store.workspace = workspace; store.hasLoadedWorkspace = true
        await store.removeLatest(title, expected: displayed)
        XCTAssertTrue(store.error?.contains("history changed") == true)
        XCTAssertFalse(StubProtocol.state.recorded().contains { $0.httpMethod == "PATCH" })
    }
    func testTraktWireContractCarriesEveryExplicitDirectionChoice() async throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "trakt-sync", withExtension: "json"))
        let response = try String(contentsOf: url, encoding: .utf8)
        StubProtocol.state.reset { _ in .init(response) }
        let storage = MemorySessionStorage(); storage.credential = credential
        let service = LiveTraktService(store: DiaryStore(api: api(storage)))
        for choice in [TraktChoice.apply, .local, .trakt, .skip] {
            _ = try await service.apply(id: "fixture-run", change: "fixture-change", choice: choice)
        }
        let writes = StubProtocol.state.recorded()
        XCTAssertEqual(writes.count, 4)
        let bodies = try writes.map(bodyObject)
        XCTAssertEqual(bodies.map { $0["choice"] as? String }, ["apply", "local", "trakt", "skip"])
        XCTAssertTrue(writes.allSatisfy { $0.url?.path == "/api/trakt/sync/fixture-run/apply" && $0.httpMethod == "POST" })
        XCTAssertTrue(bodies.allSatisfy { $0["changeId"] as? String == "fixture-change" })
    }
    func testBulkCollectionUsesOneAtomicRequestWithFrozenReviewedVersions() async throws {
        let workspace = PreviewData.workspace, reviewed = Array(PreviewData.workspace.activeTitles.prefix(2))
        let pages = try workspacePages(workspace)
        let response = String(decoding: try JSONSerialization.data(withJSONObject: ["ids": reviewed.map(\.id), "count": reviewed.count, "action": "queue"]), as: UTF8.self)
        StubProtocol.state.reset { request in
            if request.httpMethod == "POST" { return .init(response) }
            return .init(pages[request.url?.query ?? ""] ?? #"{"items":[],"next":null}"#)
        }
        let storage = MemorySessionStorage(); storage.credential = credential
        let store = DiaryStore(api: api(storage)); store.workspace = workspace; store.hasLoadedWorkspace = true
        let success = await store.manage(reviewed, change: .queue(true))
        XCTAssertTrue(success)
        let writes = StubProtocol.state.recorded().filter { $0.httpMethod == "POST" }
        XCTAssertEqual(writes.count, 1); XCTAssertEqual(writes.first?.url?.path, "/api/titles/bulk")
        let body = try bodyObject(XCTUnwrap(writes.first))
        XCTAssertEqual(Set(body.keys), ["action", "items", "queued"])
        let items = try XCTUnwrap(body["items"] as? [[String: Any]])
        XCTAssertEqual(items.compactMap { $0["id"] as? String }, reviewed.map(\.id))
        XCTAssertEqual(items.compactMap { $0["expectedVersion"] as? Int }, reviewed.compactMap(\.version))
    }
    func testBulkResetRetriesItsOriginalOperationAndUsesProgressUndoEndpoint() async throws {
        let workspace = PreviewData.workspace, reviewed = Array(PreviewData.workspace.activeTitles.prefix(2))
        let pages = try workspacePages(workspace)
        StubProtocol.state.reset { request in
            if request.httpMethod == "POST" {
                let count = StubProtocol.state.recorded().filter { $0.httpMethod == "POST" }.count
                if count == 1 { return .init(503, #"{"error":{"message":"Unconfirmed progress"}}"#) }
                let body = (try? JSONSerialization.jsonObject(with: request.httpBody ?? Data())) as? [String: Any]
                let json: [String: Any] = ["operationId": body?["operationId"] as? String ?? "invalid"]
                return .init(String(decoding: (try? JSONSerialization.data(withJSONObject: json)) ?? Data(), as: UTF8.self))
            }
            return .init(pages[request.url?.query ?? ""] ?? #"{"items":[],"next":null}"#)
        }
        let storage = MemorySessionStorage(); storage.credential = credential
        let store = DiaryStore(api: api(storage)); store.workspace = workspace; store.hasLoadedWorkspace = true
        let first = await store.manage(reviewed, change: .status("planned"))
        XCTAssertFalse(first)
        let second = await store.manage(reviewed, change: .status("planned"))
        XCTAssertTrue(second); XCTAssertEqual(store.undoLabel, "Progress reset")
        var writes = StubProtocol.state.recorded().filter { $0.httpMethod == "POST" }
        XCTAssertEqual(writes.count, 2)
        let a = try bodyObject(writes[0]), b = try bodyObject(writes[1])
        XCTAssertEqual(a["operationId"] as? String, b["operationId"] as? String)
        XCTAssertEqual(a["watchedAt"] as? String, b["watchedAt"] as? String)
        XCTAssertTrue(writes.allSatisfy { $0.url?.path == "/api/progress/status" })
        await store.undo(); XCTAssertNil(store.undoLabel)
        writes = StubProtocol.state.recorded().filter { $0.httpMethod == "POST" }
        XCTAssertEqual(writes.count, 3)
        let undo = try bodyObject(writes[2])
        XCTAssertEqual(undo["undoOf"] as? String, b["operationId"] as? String)
        XCTAssertNotEqual(undo["operationId"] as? String, undo["undoOf"] as? String)
    }
    func testUnifiedSearchUsesExistingDiaryEndpointAndPreservesProviderFailureAsPartialData() async throws {
        StubProtocol.state.reset { _ in .init(#"{"library":[{"id":"known","name":"Identity match","year":2020,"category":"show","posterPath":null}],"online":[],"page":2,"totalPages":4,"onlineError":"Online search temporarily unavailable"}"#) }
        let storage = MemorySessionStorage(); storage.credential = credential
        let store = DiaryStore(api: api(storage))
        let result = try await store.searchDiary(DiarySearchTools.normalize("https://imdb.com/title/TT1234567/"), page: 2)
        XCTAssertEqual(result.library.first?.id, "known"); XCTAssertEqual(result.page, 2); XCTAssertFalse(result.onlineError.isEmpty)
        let request = try XCTUnwrap(StubProtocol.state.recorded().first)
        XCTAssertEqual(request.url?.path, "/api/search")
        let parts = URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)
        let query = Dictionary(uniqueKeysWithValues: (parts?.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        XCTAssertEqual(query, ["q": "tt1234567", "scope": "online", "page": "2"])
        XCTAssertEqual(request.value(forHTTPHeaderField: "Cookie"), "CF_Authorization=synthetic-test-session")
    }
    func testDiscoveryCacheUsesCompleteQueryAndCannotServeAfterSignOut() async throws {
        StubProtocol.state.reset { _ in .init(#"{"items":[],"page":1,"totalPages":1}"#) }
        let storage = MemorySessionStorage(); storage.credential = credential
        let store = DiaryStore(api: api(storage)), query = DiscoveryFilters(section: .ratedShows).query(section: .ratedShows)
        let service = LiveDiscoveryService(store: store)
        _ = try await service.page(query); _ = try await service.page(query)
        XCTAssertEqual(StubProtocol.state.recorded().count, 1)
        _ = try await service.page(DiscoveryFilters(section: .ratedMovies).query(section: .ratedMovies))
        XCTAssertEqual(StubProtocol.state.recorded().count, 2)
        store.signOut()
        do { _ = try await service.page(query); XCTFail("Signed-out discovery must not open cached private data") }
        catch { XCTAssertTrue(store.needsSignIn) }
        XCTAssertEqual(StubProtocol.state.recorded().count, 2)
    }
    func testSignOutDiscardsLateProgressCardWithoutPublishingAnError() async throws {
        StubProtocol.state.reset { _ in
            var reply = StubProtocol.Reply(#"{"progress":{"watched":1,"total":16},"season":null,"next":null,"previous":null}"#)
            reply.delay = 0.15; return reply
        }
        let storage = MemorySessionStorage(); storage.credential = credential
        let store = DiaryStore(api: api(storage)), title = try XCTUnwrap(PreviewData.workspace.activeTitles.first)
        let pending = Task { () -> Bool in
            do { _ = try await store.card(title); return true }
            catch is CancellationError { return false }
            catch { XCTFail("Expected session cancellation, received \(error)"); return false }
        }
        for _ in 0..<100 {
            if !StubProtocol.state.recorded().isEmpty { break }
            try await Task.sleep(for: .milliseconds(5))
        }
        store.signOut()
        let accepted = await pending.value
        XCTAssertFalse(accepted); XCTAssertTrue(store.needsSignIn); XCTAssertNil(store.error)
    }
    func testLateUnauthorizedReadAfterSignOutIsCancellationNotANewLoginError() async throws {
        StubProtocol.state.reset { _ in
            var reply = StubProtocol.Reply(401, #"{"error":{"message":"Expired synthetic session"}}"#)
            reply.delay = 0.15; return reply
        }
        let storage = MemorySessionStorage(); storage.credential = credential
        let store = DiaryStore(api: api(storage))
        let pending = Task { () -> Bool in
            do { let _: EmptyResponse = try await store.read("/api/metadata/status"); return false }
            catch is CancellationError { return true }
            catch { return false }
        }
        for _ in 0..<100 {
            if !StubProtocol.state.recorded().isEmpty { break }
            try await Task.sleep(for: .milliseconds(5))
        }
        store.signOut()
        let cancelled = await pending.value
        XCTAssertTrue(cancelled); XCTAssertTrue(store.needsSignIn); XCTAssertNil(store.error)
    }
    func testPublicRatingsUseExistingEndpointAndKeepProviderFailureOutOfTheGlobalError() async throws {
        StubProtocol.state.reset { _ in .init(503, #"{"error":{"message":"Synthetic provider unavailable"}}"#) }
        let storage = MemorySessionStorage(); storage.credential = credential
        let store = DiaryStore(api: api(storage)), title = try XCTUnwrap(PreviewData.workspace.activeTitles.first)
        await store.loadPublicRatings([title, title], source: .tmdb)
        XCTAssertTrue(StubProtocol.state.recorded().isEmpty)
        await store.loadPublicRatings([title, title], source: .trakt)
        XCTAssertEqual(StubProtocol.state.recorded().count, 1)
        XCTAssertEqual(StubProtocol.state.recorded().first?.url?.path, "/api/library/ratings")
        XCTAssertEqual(store.communityRatings.entries[title.id]?.state, "unavailable")
        XCTAssertNil(store.error); XCTAssertFalse(store.needsSignIn)
        await store.loadPublicRatings([title], source: .trakt)
        XCTAssertEqual(StubProtocol.state.recorded().count, 1)
    }
    func testSignOutClearsPublicScoresAndIgnoresLateProviderResponse() async throws {
        StubProtocol.state.reset { _ in
            var reply = StubProtocol.Reply(#"{"source":"trakt","ratings":{"again":{"score":7.7,"state":"rated"}}}"#)
            reply.delay = 0.15; return reply
        }
        let storage = MemorySessionStorage(); storage.credential = credential
        let store = DiaryStore(api: api(storage)), title = try XCTUnwrap(PreviewData.workspace.activeTitles.first { $0.id == "again" })
        let pending = Task { await store.loadPublicRatings([title], source: .trakt) }
        for _ in 0..<100 { if !StubProtocol.state.recorded().isEmpty { break }; try await Task.sleep(for: .milliseconds(5)) }
        store.signOut(); await pending.value
        XCTAssertTrue(store.communityRatings.entries.isEmpty); XCTAssertFalse(store.communityRatings.loading)
        XCTAssertNil(store.error)
        await store.loadPublicRatings([title], source: .trakt)
        XCTAssertEqual(StubProtocol.state.recorded().count, 1)
    }
    func testDifferentAccountCannotKeepThePreviousWorkspaceWhenItsReloadFails() async throws {
        let cache = MemoryWorkspaceCache()
        try cache.save(PreviewData.workspace, scope: credential.cacheScope, at: .now)
        let storage = MemorySessionStorage(); storage.credential = credential
        let store = DiaryStore(api: api(storage), cache: cache)
        XCTAssertFalse(store.workspace.titles.isEmpty)
        StubProtocol.state.reset { request in
            request.url?.path == "/api/session" ? .init(#"{"authenticated":true}"#) : .init(503, #"{"error":{"message":"Synthetic offline"}}"#)
        }
        await store.connect(AccessCredential(token: "synthetic-other-owner", expires: .distantFuture))
        XCTAssertFalse(store.needsSignIn); XCTAssertFalse(store.hasLoadedWorkspace)
        XCTAssertTrue(store.workspace.titles.isEmpty); XCTAssertFalse(store.showingCachedSnapshot)
        XCTAssertNil(store.lastRefreshedAt); XCTAssertNil(store.undoLabel)
        XCTAssertEqual(storage.credential?.token, "synthetic-other-owner")
        XCTAssertNotNil(cache.load(scope: credential.cacheScope), "Owner-scoped encrypted copies may remain, but must never be published for a different account")
    }
    func testDiscoveryCannotReusePreviousSessionsRecommendationCacheAfterReconnect() async throws {
        StubProtocol.state.reset { request in
            if request.url?.path == "/api/session" { return .init(#"{"authenticated":true}"#) }
            if request.url?.path == "/api/workspace" { return .init(#"{"items":[],"next":null}"#) }
            return .init(#"{"items":[],"page":1,"totalPages":1}"#)
        }
        let storage = MemorySessionStorage(); storage.credential = credential
        let store = DiaryStore(api: api(storage)), service = LiveDiscoveryService(store: store)
        let query = DiscoveryFilters(section: .recommended).query(section: .recommended)
        _ = try await service.page(query)
        await store.connect(AccessCredential(token: "synthetic-other-owner", expires: .distantFuture))
        _ = try await service.page(query)
        let pages = StubProtocol.state.recorded().filter { $0.url?.path == "/api/discovery" }
        XCTAssertEqual(pages.count, 2)
        XCTAssertEqual(pages.last?.value(forHTTPHeaderField: "Cookie"), "CF_Authorization=synthetic-other-owner")
    }
    func testPersonMetadataUsesBoundedSharedCacheAndNeverSurvivesSignOut() async throws {
        let data = try Data(contentsOf: XCTUnwrap(Bundle.main.url(forResource: "catalog-person", withExtension: "json")))
        let json = String(decoding: data, as: UTF8.self)
        StubProtocol.state.reset { _ in .init(json) }
        let storage = MemorySessionStorage(); storage.credential = credential
        let store = DiaryStore(api: api(storage))
        _ = try await store.person(700001); _ = try await store.person(700001)
        XCTAssertEqual(StubProtocol.state.recorded().count, 1)
        for id in 700002...700034 { _ = try await store.person(id) }
        XCTAssertEqual(store.cachedPeople.count, 32); XCTAssertNil(store.cachedPeople[700001])
        store.signOut(); XCTAssertTrue(store.cachedPeople.isEmpty)
        do { _ = try await store.person(700034); XCTFail("A signed-out view cannot read cached metadata") } catch { XCTAssertTrue(store.needsSignIn) }
        XCTAssertEqual(StubProtocol.state.recorded().count, 34)
    }
    private func workspacePages(_ workspace: Workspace) throws -> [String: String] {
        let sections: [String: Any] = ["titles": try JSONSerialization.jsonObject(with: JSONEncoder().encode(workspace.titles)),
                                       "episodes": try JSONSerialization.jsonObject(with: JSONEncoder().encode(workspace.episodes)),
                                       "events": try JSONSerialization.jsonObject(with: JSONEncoder().encode(workspace.events)),
                                       "locations": try JSONSerialization.jsonObject(with: JSONEncoder().encode(workspace.locations))]
        return try Dictionary(uniqueKeysWithValues: sections.map { key, value in
            ("section=" + key, String(decoding: try JSONSerialization.data(withJSONObject: ["items": value, "next": NSNull()]), as: UTF8.self))
        })
    }
    private func bodyObject(_ request: URLRequest) throws -> [String: Any] {
        var data = request.httpBody ?? Data()
        if data.isEmpty, let stream = request.httpBodyStream {
            stream.open(); defer { stream.close() }
            var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable { let size = stream.read(&buffer, maxLength: buffer.count); if size <= 0 { break }; data.append(contentsOf: buffer.prefix(size)) }
        }
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}
