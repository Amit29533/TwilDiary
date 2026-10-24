import Foundation
import Observation
import TwilDiaryCore

/// Device-session public scores. Personal diary ratings never enter this cache.
@MainActor @Observable final class CommunityRatingsController {
    private(set) var entries: [String: PublicRating] = [:]
    private(set) var pending = 0
    var loading: Bool { pending > 0 }
    var unavailable: Bool { entries.values.contains { $0.state == "unavailable" } }
    private var expires: [String: Date] = [:]
    private var inflight = Set<String>()
    private var generation = UUID()
    private let clock: () -> Date
    init(clock: @escaping () -> Date = { Date() }) { self.clock = clock }

    func reset() {
        generation = UUID(); entries = [:]; expires = [:]; inflight = []; pending = 0
    }
    func prepare(_ titleIDs: [String], fetch: ([String]) async throws -> [String: PublicRating]) async {
        var seen = Set<String>()
        let now = clock()
        let ids = titleIDs.filter { seen.insert($0).inserted && !inflight.contains($0) && (expires[$0].map { $0 <= now } ?? true) }
        guard !ids.isEmpty, !Task.isCancelled else { return }
        let session = generation
        inflight.formUnion(ids); pending += 1
        defer {
            if session == generation { inflight.subtract(ids); pending -= 1 }
        }
        for offset in stride(from: 0, to: ids.count, by: 24) {
            guard session == generation, !Task.isCancelled else { return }
            let batch = Array(ids[offset..<min(offset + 24, ids.count)])
            let results: [String: PublicRating]
            do { results = try await fetch(batch) }
            catch is CancellationError { return }
            catch { results = [:] }
            guard session == generation, !Task.isCancelled else { return }
            let received = clock()
            for id in batch {
                let rating = results[id] ?? PublicRating(score: nil, state: "unavailable")
                entries[id] = rating
                expires[id] = received.addingTimeInterval(rating.state == "unavailable" ? 60 : 86_400)
            }
        }
    }
}
