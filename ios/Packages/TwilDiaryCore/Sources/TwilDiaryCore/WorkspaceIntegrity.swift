import Foundation

public enum WorkspaceIntegrityError: LocalizedError, Equatable, Sendable {
    case duplicateIdentity(section: String)

    public var errorDescription: String? {
        switch self {
        case .duplicateIdentity(let section):
            "The diary returned duplicate \(section). Your previous diary is unchanged. Please refresh."
        }
    }
}

extension Workspace {
    /// Reject ambiguous snapshots rather than arbitrarily choosing between conflicting records.
    /// Different event IDs remain distinct, including intentional rewatches of the same episode.
    public func validatingIdentities() throws -> Self {
        try requireUnique(titles, section: "titles")
        try requireUnique(episodes, section: "episodes")
        try requireUnique(events, section: "watches")
        try requireUnique(locations, section: "locations")
        return self
    }

    private func requireUnique<Row: Identifiable>(_ rows: [Row], section: String) throws {
        var seen = Set<Row.ID>()
        for row in rows where !seen.insert(row.id).inserted {
            throw WorkspaceIntegrityError.duplicateIdentity(section: section)
        }
    }
}

/// Projection fallback for callers constructing an unvalidated workspace in memory.
/// Production snapshots are validated before publication, so conflicts are never silently accepted.
func distinctRows<Row: Identifiable>(_ rows: [Row]) -> [Row] {
    var seen = Set<Row.ID>()
    return rows.filter { seen.insert($0.id).inserted }
}
