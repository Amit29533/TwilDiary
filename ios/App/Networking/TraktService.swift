import Foundation
import Observation
import TwilDiaryCore

@MainActor protocol TraktServicing {
    func status() async throws -> TraktStatus
    func review(kind: TraktKind, query: String, after: String?) async throws -> TraktSync
    func start(mode: TraktRatingMode) async throws -> String
    func step(id: String) async throws -> TraktSync
    func apply(id: String, change: String?, choice: TraktChoice) async throws -> TraktSync
    func cancel(id: String) async throws
    func disconnect() async throws
}

@MainActor struct LiveTraktService: TraktServicing {
    let store: DiaryStore
    func status() async throws -> TraktStatus { try await store.read("/api/trakt/status") }
    func review(kind: TraktKind, query: String, after: String?) async throws -> TraktSync {
        try await store.read(CatalogTools.apiPath("/api/trakt/sync", query: ["kind": kind.rawValue, "query": query, "after": after ?? ""]))
    }
    func start(mode: TraktRatingMode) async throws -> String {
        struct Receipt: Decodable { let id: String }
        let result: Receipt = try await store.read("/api/trakt/sync", method: "POST", body: ["ratingMode": mode.rawValue])
        return result.id
    }
    func step(id: String) async throws -> TraktSync { try await store.read("/api/trakt/sync/\(id)/step", method: "POST", body: [:]) }
    func apply(id: String, change: String?, choice: TraktChoice) async throws -> TraktSync {
        var body: [String: Any] = ["choice": choice.rawValue]
        if let change { body["changeId"] = change }
        return try await store.read("/api/trakt/sync/\(id)/apply", method: "POST", body: body)
    }
    func cancel(id: String) async throws { let _: EmptyResponse = try await store.read("/api/trakt/sync/\(id)/cancel", method: "POST", body: [:]) }
    func disconnect() async throws { let _: EmptyResponse = try await store.read("/api/trakt/disconnect", method: "POST", body: [:]) }
}

@MainActor @Observable final class TraktController {
    private let service: any TraktServicing
    private(set) var status: TraktStatus?
    private(set) var sync: TraktSync?
    private(set) var busy = false
    private(set) var loading = false
    private(set) var cooldownUntil = Date.distantPast
    private(set) var limit = 6
    var kind = TraktKind.all
    var query = ""
    var mode = TraktRatingMode.round
    var error: String?
    var paused = false
    private var refreshID = UUID()
    private var receivedMode = false
    init(service: any TraktServicing) { self.service = service }
    var visibleItems: [TraktChange] { sync?.items.filter { (kind == .all || $0.kind == kind.rawValue) && (query.isEmpty || $0.name.localizedCaseInsensitiveContains(query)) } ?? [] }
    func refresh() async {
        let request = UUID(); refreshID = request; loading = true
        defer { if refreshID == request { loading = false } }
        do {
            let connection = try await service.status()
            let review = try await service.review(kind: kind, query: query, after: nil)
            guard request == refreshID, !Task.isCancelled else { return }
            status = connection; accept(review); limit = 6; error = nil
            if !receivedMode, let raw = review.run?.ratingMode, let value = TraktRatingMode(rawValue: raw) { mode = value; receivedMode = true }
        } catch is CancellationError { }
        catch { if request == refreshID, !Task.isCancelled { self.error = error.localizedDescription } }
    }
    func loadMore() async {
        guard !busy, let current = sync else { return }
        if limit < current.items.count { limit += 6; return }
        guard let cursor = current.next else { return }
        let request = refreshID, selectedKind = kind, search = query
        busy = true; defer { busy = false }
        do {
            let next = try await service.review(kind: selectedKind, query: search, after: cursor)
            guard request == refreshID, kind == selectedKind, query == search else { return }
            accept(current.appending(next)); limit += 6
        } catch is CancellationError { }
        catch { if request == refreshID, kind == selectedKind, query == search, !Task.isCancelled { self.error = error.localizedDescription } }
    }
    func scan(start: Bool) async {
        guard !busy, cooldownUntil <= .now else { return }
        refreshID = UUID(); loading = false; busy = true; paused = false; error = nil
        defer { busy = false }
        do {
            var id = sync?.run?.id
            if start || id == nil {
                if let run = sync?.run, ["building", "review", "applying"].contains(run.state) { try await service.cancel(id: run.id) }
                id = try await service.start(mode: mode)
            }
            guard let id else { return }
            var previousStep: String?
            var steps = 0
            repeat {
                try Task.checkCancellation()
                let result = try await service.step(id: id); accept(result)
                steps += 1
                if paused || result.run?.state != "building" || cooldownUntil > .now { break }
                let signature = "\(result.run?.stage ?? ""):\(result.run?.page ?? 0):\(result.run?.progress ?? 0)"
                if signature == previousStep || steps >= 100 { paused = true; break }
                previousStep = signature
            } while true
        } catch is CancellationError { paused = true }
        catch { self.error = error.localizedDescription }
    }
    func apply(change: TraktChange? = nil, choice: TraktChoice = .apply) async {
        guard !busy, let current = sync, current.reviewing, let id = current.run?.id, choice == .skip || cooldownUntil <= .now else { return }
        refreshID = UUID(); loading = false; busy = true; paused = false; error = nil
        defer { busy = false }
        do {
            var steps = 0
            repeat {
                try Task.checkCancellation()
                let result = try await service.apply(id: id, change: change?.id, choice: choice); accept(result)
                steps += 1
                if change != nil || paused || !result.reviewing || (result.counts["safe"] ?? 0) == 0 || cooldownUntil > .now { break }
                if steps >= 100 { paused = true; break }
            } while true
            if !paused, let result = sync, result.reviewing,
               (result.counts["safe"] ?? 0) == 0, result.unresolved == 0 {
                accept(try await service.apply(id: id, change: nil, choice: .apply))
            }
            await refresh()
        } catch is CancellationError { paused = true }
        catch { self.error = error.localizedDescription }
    }
    func cancel() async {
        guard !busy, let id = sync?.run?.id else { return }
        busy = true; defer { busy = false }
        do { try await service.cancel(id: id); await refresh() } catch { self.error = error.localizedDescription }
    }
    func disconnect() async {
        guard !busy else { return }
        busy = true; defer { busy = false }
        do { try await service.disconnect(); await refresh() } catch { self.error = error.localizedDescription }
    }
    private func accept(_ value: TraktSync) { sync = value; cooldownUntil = .now.addingTimeInterval(Double(value.run?.retryAfter ?? 0)) }
}
