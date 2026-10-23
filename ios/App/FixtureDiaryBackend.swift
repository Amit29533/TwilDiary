#if DEBUG
import Foundation
import TwilDiaryCore

/// Opt-in simulator write fixture. It cannot construct or send a network request.
/// Real transport contracts are tested separately with URLProtocol/local D1.
@MainActor final class FixtureDiaryBackend {
    private(set) var workspace: Workspace
    private let stamp = "2026-10-23T12:00:00Z"
    init(workspace: Workspace) { self.workspace = workspace }
    func request<T: Decodable>(_ path: String, method: String, body: [String: Any]?) throws -> T {
        var archive = try object(workspace), titles = try objects(workspace.titles)
        let body = body ?? [:], parts = path.split(separator: "/").map(String.init)
        var response: [String: Any] = [:]
        var purged = Set<String>()
        if path == "/api/titles/bulk", method == "POST" {
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
        workspace = updated
        return receipt
    }
    private func object<Value: Encodable>(_ value: Value) throws -> [String: Any] { try JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? [String: Any] ?? [:] }
    private func objects<Value: Encodable>(_ value: Value) throws -> [[String: Any]] { try JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? [[String: Any]] ?? [] }
}
#endif
