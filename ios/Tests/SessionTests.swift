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
            lock.lock(); requests.append(request); let handler = handler; lock.unlock()
            return handler(request)
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
}
