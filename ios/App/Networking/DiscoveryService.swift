import Foundation
import Observation
import TwilDiaryCore

@MainActor protocol DiscoveryServing {
    func page(_ query: [String: String]) async throws -> CatalogPage
    func traktConnected() async throws -> Bool
}

@MainActor final class LiveDiscoveryService: DiscoveryServing {
    private let store: DiaryStore
    private var session: UUID?
    private var cache: [String: (at: Date, page: CatalogPage)] = [:]
    init(store: DiaryStore) { self.store = store }
    func page(_ query: [String: String]) async throws -> CatalogPage {
        guard !store.needsSignIn else { clear(); throw APIError.signIn }
        let revision = store.sessionRevision
        if session != revision { clear(); session = revision }
        let key = CatalogTools.apiPath("/api/discovery", query: query)
        if let saved = cache[key], Date.now.timeIntervalSince(saved.at) < 300 { return saved.page }
        let result: CatalogPage
        if store.isPreview { result = PreviewCatalog.discovery(query) }
        else { result = try await store.read(key) }
        try Task.checkCancellation()
        guard revision == store.sessionRevision, !store.needsSignIn else { throw CancellationError() }
        if cache.count >= 16, let oldest = cache.min(by: { $0.value.at < $1.value.at })?.key { cache.removeValue(forKey: oldest) }
        cache[key] = (.now, result)
        return result
    }
    func traktConnected() async throws -> Bool {
        guard !store.needsSignIn else { clear(); throw APIError.signIn }
        if store.isPreview { return false }
        let status: TraktStatus = try await store.read("/api/trakt/status")
        return status.connected
    }
    func clear() { cache.removeAll() }
}

/// Each grid/shelf owns a generation, so a late page never overwrites a newer filter.
@MainActor @Observable final class DiscoveryResults {
    private let service: any DiscoveryServing
    private var generation = UUID()
    private var scope: [String: String] = [:]
    private(set) var items: [CatalogItem] = []
    private(set) var page = 0
    private(set) var totalPages = 1
    private(set) var loading = false
    private(set) var error: String?
    init(service: any DiscoveryServing) { self.service = service }
    var hasMore: Bool { page > 0 && page < min(500, totalPages) }
    func clear() { generation = UUID(); scope = [:]; items = []; page = 0; totalPages = 1; loading = false; error = nil }
    func load(_ query: [String: String], more: Bool = false) async {
        if more && (loading || !hasMore) { return }
        var requested = query; requested.removeValue(forKey: "page")
        if more && requested != scope { return }
        if !more { clear(); scope = requested }
        let request = generation, number = more ? page + 1 : 1
        requested["page"] = String(number)
        loading = true; error = nil
        defer { if generation == request { loading = false } }
        do {
            let next = try await service.page(requested)
            guard generation == request, !Task.isCancelled else { return }
            guard next.page == number else { throw APIError.message("The catalog returned an unexpected page. Retry before continuing.") }
            items = CatalogTools.merging(more ? items : [], next.items)
            page = next.page; totalPages = next.totalPages
        } catch is CancellationError { }
        catch { if generation == request && !Task.isCancelled { self.error = error.localizedDescription } }
    }
}

@MainActor @Observable final class DiscoveryRecommendations {
    private let service: any DiscoveryServing
    private var generation = UUID()
    private(set) var items: [CatalogItem] = []
    private(set) var loading = false
    private(set) var connected = false
    private(set) var error: String?
    init(service: any DiscoveryServing) { self.service = service }
    func load(limit: Int = 8) async {
        let request = UUID(); generation = request; loading = true; error = nil
        defer { if generation == request { loading = false } }
        do {
            let available = try await service.traktConnected()
            guard generation == request, !Task.isCancelled else { return }
            connected = available
            guard available else { items = []; return }
            // Keep a successful media type if the other provider request fails.
            var successful: [CatalogItem] = [], failures = 0, lastError: String?
            for kind in [MediaKind.movie, .tv] {
                var filters = DiscoveryFilters(section: .recommended); filters.type = kind.rawValue
                do { let page = try await service.page(filters.query(section: .recommended, limit: limit)); successful += page.items }
                catch is CancellationError { throw CancellationError() }
                catch { failures += 1; lastError = error.localizedDescription }
                guard generation == request, !Task.isCancelled else { return }
            }
            items = CatalogTools.merging([], successful)
            error = failures == 2 ? lastError : failures == 1 ? "Some recommendations could not load." : nil
        } catch is CancellationError { }
        catch { if generation == request && !Task.isCancelled { self.error = error.localizedDescription } }
    }
}
