import SwiftUI
import TwilDiaryCore

@MainActor @Observable final class DiaryStore {
    var workspace = Workspace() { didSet { indexTitles() } }
    private var titleIndex: [String: MediaTitle] = [:]
    var cachedPeople: [Int: (at: Date, value: PersonResponse)] = [:]
    var loading = false
    var busy = false
    var needsSignIn = true
    var hasLoadedWorkspace = false
    var error: String?
    var undoLabel: String?
    private(set) var showingCachedSnapshot = false
    private(set) var lastRefreshedAt: Date?
    private(set) var cacheWarning: String?
    private var undoAction: (() async throws -> Void)?
    private let api: DiaryAPI
    private let cache: any WorkspaceCaching
    private var sessionGeneration = UUID()
    var sessionRevision: UUID { sessionGeneration }
    private var snapshotGeneration = UUID()
    private var pendingWatches: [String: [String: Any]] = [:]
    private var pendingProgress: [String: [String: Any]] = [:]
    private var pendingRemovals: [String: WatchCard.Previous] = [:]
    var pendingSeasonAdjustments: [String: SeasonEditTransaction] = [:]
    let isPreview: Bool
    #if DEBUG
    private var fixture: FixtureDiaryBackend?
    #endif
    var canMutate: Bool {
        #if DEBUG
        if isPreview { return fixture != nil }
        #endif
        return !isPreview
    }
    var now: Date { isPreview ? DiaryDate.parse("2026-10-23T12:00:00Z")! : .now }
    init(api: DiaryAPI? = nil, cache: (any WorkspaceCaching)? = nil) {
        self.api = api ?? DiaryAPI()
        if let cache { self.cache = cache }
        else if api == nil { self.cache = ProtectedWorkspaceCache() }
        else { self.cache = MemoryWorkspaceCache() }
        #if DEBUG
        isPreview = ProcessInfo.processInfo.arguments.contains("--ui-testing")
        #else
        isPreview = false
        #endif
        if isPreview {
            workspace = PreviewData.workspace; needsSignIn = false; hasLoadedWorkspace = true
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--ui-empty") { workspace = Workspace() }
            if ProcessInfo.processInfo.arguments.contains("--ui-title-metadata") { workspace = PreviewData.metadataWorkspace }
            #endif
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--ui-mutations") { fixture = FixtureDiaryBackend(workspace: workspace, scanner: ProcessInfo.processInfo.arguments.contains("--ui-scanner")) }
            #endif
        }
        else {
            needsSignIn = self.api.credential == nil
            restoreCachedWorkspace()
        }
        indexTitles()
    }
    func connect(_ credential: AccessCredential) async {
        let previousScope = api.credential?.cacheScope
        let generation = UUID(); sessionGeneration = generation; snapshotGeneration = UUID()
        do {
            try await api.authenticate(credential)
            guard generation == sessionGeneration else { return }
            communityRatings.reset(); cachedPeople = [:]
            if previousScope != credential.cacheScope {
                workspace = Workspace(); hasLoadedWorkspace = false; showingCachedSnapshot = false; lastRefreshedAt = nil; cacheWarning = nil
                pendingWatches.removeAll(); pendingProgress.removeAll(); pendingRemovals.removeAll(); pendingSeasonAdjustments.removeAll()
                undoLabel = nil; undoAction = nil
            }
            loading = false; busy = false
            needsSignIn = false; error = nil; restoreCachedWorkspace(); await refresh()
        } catch { if generation == sessionGeneration { fail(error) } }
    }
    func signOut() {
        #if DEBUG
        fixture = nil
        #endif
        sessionGeneration = UUID(); snapshotGeneration = UUID()
        api.signOut(); workspace = Workspace(); communityRatings.reset(); cachedPeople = [:]; hasLoadedWorkspace = false; error = nil
        showingCachedSnapshot = false; lastRefreshedAt = nil; loading = false; busy = false
        do { try cache.removeAll(); cacheWarning = nil }
        catch { cacheWarning = "The saved diary could not be removed. It remains encrypted on this device." }
        pendingWatches.removeAll(); pendingProgress.removeAll(); pendingRemovals.removeAll(); undoAction = nil; undoLabel = nil
        pendingSeasonAdjustments.removeAll()
        needsSignIn = true
    }
    func refresh() async {
        guard !isPreview, !loading, !needsSignIn else { return }
        let session = sessionGeneration
        loading = true; defer { if session == sessionGeneration { loading = false } }
        do { try await reload(); if session == sessionGeneration { error = nil } }
        catch is CancellationError { }
        catch { if session == sessionGeneration { fail(error) } }
    }
    func reload() async throws {
        #if DEBUG
        if let fixture { workspace = fixture.workspace; hasLoadedWorkspace = true; return }
        #endif
        let session = sessionGeneration, revision = UUID()
        snapshotGeneration = revision
        // Publish only a complete snapshot. A failed page cannot replace good data with a partial diary.
        let titles = try await api.allPages("titles", as: MediaTitle.self)
        let episodes = try await api.allPages("episodes", as: Episode.self)
        let events = try await api.allPages("events", as: WatchEvent.self)
        let locations = try await api.allPages("locations", as: FileLocation.self)
        guard session == sessionGeneration, revision == snapshotGeneration, !needsSignIn else { throw CancellationError() }
        let snapshot = Workspace(titles: titles, episodes: episodes, events: events, locations: locations)
        workspace = snapshot; hasLoadedWorkspace = true; showingCachedSnapshot = false; lastRefreshedAt = .now
        if let scope = api.credential?.cacheScope {
            do { try cache.save(snapshot, scope: scope, at: .now); cacheWarning = nil }
            catch { cacheWarning = "Your diary is loaded, but its protected offline copy could not be updated." }
        }
    }
    private func restoreCachedWorkspace() {
        guard let credential = api.credential, credential.isValid, let snapshot = cache.load(scope: credential.cacheScope) else { return }
        workspace = snapshot.workspace; hasLoadedWorkspace = true
        showingCachedSnapshot = true; lastRefreshedAt = snapshot.savedAt
    }
    private func indexTitles() { titleIndex = Dictionary(workspace.titles.map { ($0.id, $0) }, uniquingKeysWith: { _, latest in latest }) }
    func title(_ id: String) -> MediaTitle? { titleIndex[id] }
    func browserCredential() -> AccessCredential? { api.credential }
    func read<T: Decodable>(_ path: String, method: String = "GET", body: [String: Any]? = nil) async throws -> T {
        #if DEBUG
        if let fixture { return try fixture.request(path, method: method, body: body) }
        if isPreview { throw APIError.message("The browsing fixture is read-only.") }
        #endif
        let generation = sessionGeneration
        do {
            let value: T = try await api.request(path, method: method, body: body)
            guard generation == sessionGeneration else { throw CancellationError() }
            return value
        }
        catch {
            guard generation == sessionGeneration else { throw CancellationError() }
            if case APIError.signIn = error { fail(error) }
            throw error
        }
    }
    @discardableResult func trash(_ title: MediaTitle) async -> Bool {
        await perform {
            let result: TitleReceipt = try await self.read("/api/titles/\(title.id)", method: "DELETE", body: ["expectedVersion": title.version ?? 1])
            self.undoLabel = "Moved to Trash"
            self.undoAction = {
                let _: TitleReceipt = try await self.read("/api/titles/\(title.id)/restore", method: "POST", body: ["expectedVersion": result.title.version])
            }
        }
    }
    @discardableResult func restore(_ title: MediaTitle) async -> Bool {
        await perform {
            let _: TitleReceipt = try await self.read("/api/titles/\(title.id)/restore", method: "POST", body: ["expectedVersion": title.version ?? 1])
        }
    }
    let communityRatings = CommunityRatingsController()
    func publicScore(_ title: MediaTitle, source: PublicRatingSource) -> Double? {
        CommunityScore.value(tmdb: title.communityScore, trakt: communityRatings.entries[title.id], source: source)
    }
    func loadPublicRatings(_ titles: [MediaTitle], source: PublicRatingSource) async {
        guard source == .trakt, !needsSignIn else { return }
        await communityRatings.prepare(titles.map(\.id)) { ids in
            #if DEBUG
            if self.isPreview {
                if ProcessInfo.processInfo.arguments.contains("--ui-ratings-unavailable") { return [:] }
                return Dictionary(uniqueKeysWithValues: ids.map { id in
                    (id, PublicRating(score: id == "again" ? 7.7 : nil, state: id == "again" ? "rated" : "unrated"))
                })
            }
            #endif
            let page: PublicRatingsPage = try await self.read(CatalogTools.apiPath("/api/library/ratings", query: ["ids": ids.joined(separator: ",")]))
            return page.ratings
        }
    }
    func card(_ title: MediaTitle, season: Int? = nil) async throws -> WatchCard {
        if isPreview { return PreviewData.card(title, workspace: workspace, season: season) }
        var query = "?day=\(DiaryDate.day())"
        if let season { query += "&season=\(season)" }
        return try await read("/api/glance/\(title.id)" + query)
    }
    func loadSeason(_ title: MediaTitle, number: Int) async {
        await perform {
            let _: EmptyResponse = try await self.read("/api/titles/\(title.id)/seasons/\(number)/metadata", method: "POST")
        }
    }
    func markNext(_ title: MediaTitle, season: Int? = nil, expectedEpisode: String? = nil) async {
        await perform {
            let key = title.id
            if self.pendingWatches[key] == nil {
                let card = try await self.card(title, season: season)
                if let expectedEpisode, card.next?.id != expectedEpisode { throw APIError.message("Progress changed. Refresh this title before marking another episode.") }
                if title.isSeries && card.next == nil { throw APIError.message("No aired episode is ready to mark. Load this season’s episodes or choose another season.") }
                self.pendingWatches[key] = ["operationId": UUID().uuidString, "episodeId": card.next?.id as Any? ?? NSNull(), "watchedAt": self.now.ISO8601Format(), "rewatch": false]
            }
            let operation = self.pendingWatches[key]!
            let result: WatchReceipt
            do { result = try await self.read("/api/titles/\(title.id)/watches", method: "POST", body: operation) }
            catch { if Self.definitivelyRejected(error) { self.pendingWatches.removeValue(forKey: key) }; throw error }
            self.pendingWatches.removeValue(forKey: key)
            // Do not undo somebody else's pre-existing watch returned by an idempotent server response.
            if result.added || (result.event.operationId == operation["operationId"] as? String && result.event.version == 1 && result.event.revokedAt == nil) {
                self.undoLabel = "Watch marked"
                self.undoAction = { try await self.changeEvent(result.event, action: "revoke") }
            }
        }
    }
    func removeLatest(_ title: MediaTitle, season: Int? = nil, expected: WatchCard.Previous? = nil) async {
        await perform {
            if self.pendingRemovals[title.id] == nil {
                let card = try await self.card(title, season: season)
                guard let previous = card.previous else { return }
                if let expected, previous != expected { throw APIError.message("Watch history changed. Refresh this title before removing a watch.") }
                self.pendingRemovals[title.id] = previous
            }
            let event = self.pendingRemovals[title.id]!
            let result: EventReceipt
            do { result = try await self.read("/api/watch-events/\(event.id)", method: "PATCH", body: ["action": "revoke", "expectedVersion": event.version]) }
            catch { if Self.definitivelyRejected(error) { self.pendingRemovals.removeValue(forKey: title.id) }; throw error }
            self.pendingRemovals.removeValue(forKey: title.id)
            self.undoLabel = "Watch removed"
            self.undoAction = { try await self.changeEvent(result.event, action: "restore") }
        }
    }
    private func changeEvent(_ event: WatchEvent, action: String) async throws {
        let _: EventReceipt = try await read("/api/watch-events/\(event.id)", method: "PATCH", body: ["action": action, "expectedVersion": event.version ?? 1])
    }
    func pendingViewing(key: String, episode: String?, date: Date, rewatch: Bool) -> [String: Any] {
        if pendingWatches[key] == nil { pendingWatches[key] = ["operationId": UUID().uuidString, "episodeId": episode as Any? ?? NSNull(), "watchedAt": date.ISO8601Format(), "rewatch": rewatch] }
        return pendingWatches[key]!
    }
    func clearPendingViewing(key: String) { pendingWatches.removeValue(forKey: key) }
    func rejectPendingViewing(key: String, error: Error) { if Self.definitivelyRejected(error) { pendingWatches.removeValue(forKey: key) } }
    func rejectPendingSeason(key: String, error: Error) { if Self.definitivelyRejected(error) { pendingSeasonAdjustments.removeValue(forKey: key) } }
    @discardableResult func patch(_ title: MediaTitle, values: [String: Any], expectedVersion: Int? = nil) async -> Bool {
        await perform {
            var body = values; body["expectedVersion"] = expectedVersion ?? title.version
            let _: EmptyResponse = try await self.read("/api/titles/\(title.id)", method: "PATCH", body: body)
        }
    }
    func setStatus(_ title: MediaTitle, status: String, watchedAt: Date? = nil) async {
        if status != "planned" && status != "completed" { await patch(title, values: ["status": status]); return }
        await perform { try await self.applyProgress([title], status: status, watchedAt: watchedAt ?? self.now) }
    }
    @discardableResult func manage(_ reviewed: [MediaTitle], change: CollectionChange) async -> Bool {
        await perform {
            let request = try CollectionRequest(titles: reviewed, change: change)
            if case .status(let status) = change, ["planned", "completed"].contains(status) {
                try await self.applyProgress(reviewed, status: status, watchedAt: self.now)
            } else {
                guard let body = try JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Any] else { throw APIError.message("Invalid collection change.") }
                let receipt: CollectionReceipt = try await self.read("/api/titles/bulk", method: "POST", body: body)
                guard receipt.count == reviewed.count, Set(receipt.ids) == Set(reviewed.map(\.id)), receipt.action == change.action else { throw APIError.message("The selection response was incomplete. Refresh before trying again.") }
            }
        }
    }
    @discardableResult func emptyTrash() async -> Bool {
        await perform { let _: EmptyResponse = try await self.read("/api/trash", method: "DELETE", body: ["confirmation": "EMPTY_TRASH"]) }
    }
    private func applyProgress(_ reviewed: [MediaTitle], status: String, watchedAt: Date) async throws {
        let request = try CollectionRequest(titles: reviewed, change: .status(status))
        let ids = Set(reviewed.map(\.id)), key = status + ":" + ids.sorted().joined(separator: ",")
        if pendingProgress[key] == nil {
            if status == "completed" {
                for title in reviewed where title.isSeries {
                    for season in title.seasons ?? [] where season.number > 0 {
                        let fresh = title.tmdbId == nil || ((season.metadataVersion ?? 1) >= 2 && (DiaryDate.parse(season.metadataLoadedAt).map { self.now.timeIntervalSince($0) < 6 * 60 * 60 } ?? false))
                        if season.metadataLoadedAt == nil || !fresh {
                            let _: EmptyResponse = try await read("/api/titles/\(title.id)/seasons/\(season.number)/metadata", method: "POST")
                        }
                    }
                }
            }
            pendingProgress[key] = ["operationId": UUID().uuidString, "items": request.items.map { ["id": $0.id, "expectedVersion": $0.expectedVersion] as [String: Any] }, "status": status, "watchedAt": watchedAt.ISO8601Format(), "today": DiaryDate.day(now)]
        }
        let receipt: ProgressReceipt
        do { receipt = try await read("/api/progress/status", method: "POST", body: pendingProgress[key]) }
        catch { if Self.definitivelyRejected(error) { pendingProgress.removeValue(forKey: key) }; throw error }
        guard receipt.operationId == pendingProgress[key]?["operationId"] as? String else { throw APIError.message("The progress receipt did not match your request. Refresh before retrying.") }
        pendingProgress.removeValue(forKey: key)
        for id in ids {
            pendingWatches = pendingWatches.filter { $0.key != id && !$0.key.hasPrefix("viewing:" + id + ":") }
            pendingSeasonAdjustments = pendingSeasonAdjustments.filter { !$0.key.hasPrefix(id + ":") }; pendingRemovals.removeValue(forKey: id)
        }
        undoLabel = status == "planned" ? "Progress reset" : "Marked completed"
        let undoBody: [String: Any] = ["operationId": UUID().uuidString, "undoOf": receipt.operationId]
        undoAction = { let _: ProgressReceipt = try await self.read("/api/progress/status", method: "POST", body: undoBody) }
    }
    func undo() async {
        guard let action = undoAction else { return }
        await perform { try await action(); self.undoAction = nil; self.undoLabel = nil }
    }
    func dismissUndo() { undoLabel = nil; undoAction = nil }
    func installUndo(_ actions: [(event: WatchEvent, action: String)], label: String) {
        guard !actions.isEmpty else { return }
        undoLabel = label
        var remaining = actions
        undoAction = {
            while let next = remaining.first {
                try await self.changeEvent(next.event, action: next.action)
                remaining.removeFirst()
            }
        }
    }
    @discardableResult func perform(_ action: () async throws -> Void) async -> Bool {
        guard !busy, canMutate else { return false }
        let generation = sessionGeneration
        snapshotGeneration = UUID()
        busy = true; defer { if generation == sessionGeneration { busy = false } }
        do {
            try await action()
            guard generation == sessionGeneration else { return false }
            try await reload(); error = nil; return true
        } catch is CancellationError { return false }
        catch {
            if generation == sessionGeneration {
                let failure = error
                if case APIError.signIn = failure { fail(failure) }
                else { try? await reload(); if generation == sessionGeneration { fail(failure) } }
            }
            return false
        }
    }
    private func fail(_ cause: Error) {
        if case APIError.signIn = cause { needsSignIn = true }
        error = cause.localizedDescription
    }
    private static func definitivelyRejected(_ cause: Error) -> Bool {
        guard let apiError = cause as? APIError, case .rejected(let status, _) = apiError else { return false }
        return (400..<500).contains(status) && ![408, 425, 429].contains(status)
    }
    private struct WatchReceipt: Decodable { let event: WatchEvent; let added: Bool }
    private struct EventReceipt: Decodable { let event: WatchEvent }
    private struct ProgressReceipt: Decodable { let operationId: String }
    private struct CollectionReceipt: Decodable { let ids: [String]; let action: String; let count: Int }
    private struct PublicRatingsPage: Decodable { let ratings: [String: PublicRating] }
    private struct TitleReceipt: Decodable {
        struct Identity: Decodable { let id: String; let version: Int }
        let title: Identity
    }
}
