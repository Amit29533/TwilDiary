import Foundation

public enum MediaKind: String, Codable, CaseIterable, Sendable {
    case movie, tv
    public var label: String { self == .movie ? "Movies" : "Shows" }
}

public struct CatalogRoute: Hashable, Sendable {
    public let kind: MediaKind
    public let id: Int
    public init(kind: MediaKind, id: Int) { self.kind = kind; self.id = id }
}

public struct PersonRoute: Hashable, Sendable {
    public let id: Int
    public init(id: Int) { self.id = id }
}

/// Search, discovery, recommendations and filmography share this provider contract.
/// Identity includes the media kind: a movie and series can have the same TMDB ID.
public struct CatalogItem: Decodable, Hashable, Sendable {
    public let id: Int
    public let mediaType: MediaKind
    public let name: String
    public let year: Int?
    public let overview: String
    public let posterPath: String?
    public let backdropPath: String?
    public let rating: Double?
    public let genres: [String]?
    public let inLibraryId: String?
    public let character: String?
    public let job: String?
    public var key: String { "\(mediaType.rawValue):\(id)" }
    public var route: CatalogRoute { CatalogRoute(kind: mediaType, id: id) }
}

public struct CatalogPage: Decodable, Sendable {
    public let items: [CatalogItem]
    public let page: Int
    public let totalPages: Int
    public init(items: [CatalogItem], page: Int, totalPages: Int) { self.items = items; self.page = page; self.totalPages = totalPages }
}

public struct CatalogDetails: Decodable, Sendable {
    public let id: Int
    public let mediaType: MediaKind
    public let name: String
    public let year: Int?
    public let overview: String
    public let posterPath: String?
    public let backdropPath: String?
    public let genres: [String]
    public let runtimeMinutes: Int?
    public let communityScore: Double?
    public let suggestedCategory: String
}

public struct CatalogBrowse: Decodable, Sendable {
    public struct Saved: Decodable, Sendable { public let id: String; public let trashed: Bool }
    public let details: CatalogDetails
    public let libraryTitle: Saved?
}

public struct CastPerson: Decodable, Identifiable, Sendable {
    public let id: Int
    public let name: String
    public let character: String
    public let profilePath: String?
}
public struct CastResponse: Decodable, Sendable { public let cast: [CastPerson]; public let stale: Bool }
public struct RelatedResponse: Decodable, Sendable { public let items: [CatalogItem]; public let stale: Bool }
public struct PersonResponse: Decodable, Sendable { public let person: PersonDetails; public let stale: Bool }
public struct PersonDetails: Decodable, Sendable {
    public let id: Int
    public let name: String
    public let biography: String
    public let birthday: String?
    public let birthplace: String
    public let department: String
    public let profilePath: String?
    public let credits: [CatalogItem]
    public func filmography(_ kind: MediaKind, query: String = "", year: Int? = nil) -> [CatalogItem] {
        credits.filter { $0.mediaType == kind && (query.isEmpty || $0.name.localizedCaseInsensitiveContains(query)) && (year == nil || $0.year == year) }
            .sorted { ($0.year ?? 0) == ($1.year ?? 0) ? $0.name.localizedStandardCompare($1.name) == .orderedAscending : ($0.year ?? 0) > ($1.year ?? 0) }
    }
}

public enum CatalogTools {
    public static func image(_ path: String?, size: String = "w500") -> String? {
        guard let path, ["w185", "w500", "w780"].contains(size),
              path.range(of: #"^/[a-zA-Z0-9_-]+\.(jpg|png|webp)$"#, options: .regularExpression) != nil else { return nil }
        return "https://image.tmdb.org/t/p/" + size + path
    }
    public static func apiPath(_ path: String, query: [String: String] = [:]) -> String {
        var components = URLComponents()
        components.path = path
        if !query.isEmpty { components.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) } }
        return components.string ?? path
    }
    public static func merging(_ existing: [CatalogItem], _ page: [CatalogItem]) -> [CatalogItem] {
        var seen = Set(existing.map(\.key))
        return existing + page.filter { seen.insert($0.key).inserted }
    }
}

public enum PublicRatingSource: String, CaseIterable, Identifiable, Sendable {
    case tmdb, trakt
    public var id: Self { self }
    public var label: String { self == .tmdb ? "TMDB" : "Trakt" }
}
public struct PublicRating: Decodable, Sendable {
    public let score: Double?
    public let state: String
}
public enum CommunityScore {
    public static func value(tmdb: Double?, trakt: PublicRating?, source: PublicRatingSource) -> Double? {
        let score = source == .tmdb ? tmdb : (trakt?.state == "rated" ? trakt?.score : nil)
        return score.flatMap { $0.isFinite && $0 > 0 && $0 <= 10 ? $0 : nil }
    }
}
