#if DEBUG
import Foundation
import TwilDiaryCore

/// Opt-in simulator write fixture. It cannot construct or send a network request.
/// Real transport contracts are tested separately with URLProtocol/local D1.
@MainActor final class FixtureDiaryBackend {
    private(set) var workspace: Workspace
    private let stamp = "2026-10-23T12:00:00Z"
    private var scans: [[String: Any]] = []
    private let history = FixtureWatchHistory()
    init(workspace: Workspace, scanner: Bool = false) {
        self.workspace = workspace
        if scanner { scans = [["id": "fixture-unmatched", "version": 1, "deviceId": "fixture-pc", "deviceName": "Reference PC", "volumeId": "fixture-volume", "driveLetter": "R:", "root": "R:\\Reference", "relativePath": "Unmatched Series", "name": "Unmatched Series", "seasonNumber": 1, "fileCount": 16, "sizeBytes": NSNull(), "checkedAt": stamp]] }
    }
    func request<T: Decodable>(_ path: String, method: String, body: [String: Any]?) throws -> T {
        if let update = try history.prepare(workspace, route: URLComponents(string: path)?.path ?? path, method: method, body: body ?? [:]) {
            // Publish only after both the snapshot and caller's receipt decode successfully.
            let result = try JSONDecoder().decode(T.self, from: JSONSerialization.data(withJSONObject: update.response))
            history.commit(update); workspace = update.workspace; return result
        }
        var archive = try object(workspace), titles = try objects(workspace.titles)
        let body = body ?? [:], route = URLComponents(string: path)?.path ?? path
        let parts = route.split(separator: "/").map(String.init)
        var response: [String: Any] = [:]
        var purged = Set<String>()
        var resolvedScan: String?
        if route == "/api/metadata/import", method == "POST" {
            guard let id = body["tmdbId"] as? Int, id > 0, let media = body["mediaType"] as? String, let kind = MediaKind(rawValue: media), let category = body["category"] as? String,
                  (kind == .tv ? ["show", "anime"] : ["movie", "anime-movie"]).contains(category), body["status"] as? String == "planned" else { throw APIError.rejected(400, "The category must match this movie or series.") }
            if let existing = workspace.titles.first(where: { $0.tmdbId == id && $0.isSeries == (kind == .tv) }) {
                guard existing.deletedAt == nil else { throw APIError.rejected(409, "This title is already in Trash. Restore it instead of adding a second copy.") }
                response = ["title": try object(existing), "added": false]
            } else {
                let details = PreviewCatalog.browse(CatalogRoute(kind: kind, id: id)).details
                let seasonObjects: [[String: Any]]
                if kind == .tv { seasonObjects = try objects(details.seasons ?? []) } else { seasonObjects = [] }
                let title: [String: Any] = ["id": "tmdb-\(media)-\(id)", "name": details.name, "category": category, "year": details.year as Any? ?? NSNull(), "overview": details.overview,
                    "poster": CatalogTools.image(details.posterPath) as Any? ?? NSNull(), "backdrop": CatalogTools.image(details.backdropPath, size: "w780") as Any? ?? NSNull(), "communityScore": details.communityScore as Any? ?? NSNull(), "tmdbId": id,
                    "genres": details.genres, "tags": [], "runtimeMinutes": details.runtimeMinutes as Any? ?? NSNull(), "status": "planned", "favorite": false, "queued": false, "score": NSNull(), "notes": "", "deletedAt": NSNull(), "version": 1,
                    "seasons": seasonObjects]
                titles.append(title); response = ["title": title, "added": true]
            }
        } else if route == "/api/scanner/review", method == "GET" {
            response = ["items": scans, "nextCursor": NSNull()]
        } else if parts.count == 5, Array(parts.prefix(3)) == ["api", "scanner", "review"], parts[4] == "resolve", method == "POST" {
            guard let scan = scans.first(where: { $0["id"] as? String == parts[3] }), scan["version"] as? Int == body["expectedVersion"] as? Int,
                  let titleID = body["titleId"] as? String, let title = workspace.activeTitles.first(where: { $0.id == titleID }) else { throw APIError.rejected(409, "This scan was already resolved or the selected title changed. Refresh the queue.") }
            var copies = try objects(workspace.locations)
            let seasonNumber = scan["seasonNumber"] as? Int
            let matchedSeason = seasonNumber.flatMap { number in title.seasons?.contains(where: { $0.number == number }) == true ? number : nil }
            let season: Any = matchedSeason as Any? ?? NSNull()
            let mapping: [String: Any] = ["id": UUID().uuidString, "titleId": titleID, "deviceName": scan["deviceName"]!, "deviceId": scan["deviceId"]!, "volumeId": scan["volumeId"]!, "driveLetter": scan["driveLetter"]!, "root": scan["root"]!, "relativePath": scan["relativePath"]!, "season": season, "fileCount": scan["fileCount"]!, "sizeBytes": scan["sizeBytes"] as Any? ?? NSNull(), "evidence": "present", "checkedAt": scan["checkedAt"]!]
            copies.removeAll { $0["deviceId"] as? String == mapping["deviceId"] as? String && $0["volumeId"] as? String == mapping["volumeId"] as? String && $0["root"] as? String == mapping["root"] as? String && $0["relativePath"] as? String == mapping["relativePath"] as? String }
            copies.append(mapping); archive["locations"] = copies; resolvedScan = parts[3]
            response = ["resolved": true, "titleId": titleID]
        } else if path == "/api/titles/bulk", method == "POST" {
            guard let items = body["items"] as? [[String: Any]], !items.isEmpty, items.count <= CollectionRequest.limit, let action = body["action"] as? String else { throw APIError.rejected(400, "Invalid selection.") }
            let ids = items.compactMap { $0["id"] as? String }
            guard ids.count == items.count, Set(ids).count == ids.count else { throw APIError.rejected(400, "Each selected title must be different.") }
            let archived = action == "restore" || action == "purge"
            // Validate every reviewed version/state before changing anything.
            for item in items {
                guard let id = item["id"] as? String, let title = titles.first(where: { $0["id"] as? String == id }),
                      title["version"] as? Int == item["expectedVersion"] as? Int,
                      (title["deletedAt"] is String) == archived else { throw APIError.rejected(409, "Your selection changed in another session. Refresh it before trying again.") }
            }
            let selected = Set(ids)
            for index in titles.indices where selected.contains(titles[index]["id"] as? String ?? "") {
                switch action {
                case "trash": titles[index]["deletedAt"] = stamp
                case "restore": titles[index]["deletedAt"] = NSNull()
                case "purge": guard body["confirmation"] as? String == "DELETE", let id = titles[index]["id"] as? String else { throw APIError.rejected(400, "Confirm permanent deletion.") }; purged.insert(id)
                case "status": guard let status = body["status"] as? String, ["watching", "dropped"].contains(status) else { throw APIError.rejected(400, "Use the progress transaction for this status.") }; titles[index]["status"] = status
                case "queue": guard let value = body["queued"] as? Bool else { throw APIError.rejected(400, "Invalid Queue setting.") }; titles[index]["queued"] = value
                case "favorite": guard let value = body["favorite"] as? Bool else { throw APIError.rejected(400, "Invalid favorite setting.") }; titles[index]["favorite"] = value
                default: throw APIError.rejected(400, "Unsupported fixture action.")
                }
                titles[index]["version"] = (titles[index]["version"] as? Int ?? 0) + 1
            }
            response = ["ids": ids, "count": ids.count, "action": action]
        } else if path == "/api/trash", method == "DELETE", body["confirmation"] as? String == "EMPTY_TRASH" {
            purged = Set(titles.filter { $0["deletedAt"] is String }.compactMap { $0["id"] as? String }); response = ["deleted": purged.count]
        } else if parts.count >= 3, parts[0] == "api", parts[1] == "titles", let index = titles.firstIndex(where: { $0["id"] as? String == parts[2] }) {
            guard titles[index]["version"] as? Int == body["expectedVersion"] as? Int else { throw APIError.rejected(409, "Your title changed. Refresh before trying again.") }
            if method == "PATCH", parts.count == 3 {
                for key in body.keys where key != "expectedVersion" {
                    guard ["favorite", "queued", "notes", "score", "status"].contains(key) else { throw APIError.rejected(400, "Unsupported fixture field.") }
                    titles[index][key] = body[key]
                }
            } else if method == "DELETE", parts.count == 3 { titles[index]["deletedAt"] = stamp }
            else if method == "POST", parts.count == 4, parts[3] == "restore" { titles[index]["deletedAt"] = NSNull() }
            else { throw APIError.message("This action is not implemented in the isolated write fixture.") }
            titles[index]["version"] = (titles[index]["version"] as? Int ?? 0) + 1
            response = ["title": titles[index]]
        } else { throw APIError.message("This action is not implemented in the isolated write fixture.") }
        archive["titles"] = titles.filter { !purged.contains($0["id"] as? String ?? "") }
        for section in ["episodes", "events", "locations"] {
            if let rows = archive[section] as? [[String: Any]] { archive[section] = rows.filter { !purged.contains($0["titleId"] as? String ?? "") } }
        }
        let updated = try JSONDecoder().decode(Workspace.self, from: JSONSerialization.data(withJSONObject: archive))
        let receipt = try JSONDecoder().decode(T.self, from: JSONSerialization.data(withJSONObject: response))
        workspace = updated; history.retain(Set(updated.titles.map(\.id)))
        if let resolvedScan { scans.removeAll { $0["id"] as? String == resolvedScan } }
        return receipt
    }
    private func object<Value: Encodable>(_ value: Value) throws -> [String: Any] { try JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? [String: Any] ?? [:] }
    private func objects<Value: Encodable>(_ value: Value) throws -> [[String: Any]] { try JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? [[String: Any]] ?? [] }
}
#endif
