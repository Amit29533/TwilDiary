import Foundation
import TwilDiaryCore

/// Disposable UI-test responses only. Release navigation always uses authenticated APIs.
enum PreviewCatalog {
    private static func decode<T: Decodable>(_ name: String) -> T {
        let url = Bundle.main.url(forResource: name, withExtension: "json")!
        return try! JSONDecoder().decode(T.self, from: Data(contentsOf: url))
    }
    static func page(query: String = "", page: Int = 1, type: String = "all") -> CatalogPage {
        let fixture: CatalogPage = decode("catalog-page")
        return CatalogPage(items: fixture.items.filter { (type == "all" || $0.mediaType.rawValue == type) && (query.isEmpty || $0.name.localizedCaseInsensitiveContains(query)) }, page: 1, totalPages: 1)
    }
    static func browse(_ route: CatalogRoute) -> CatalogBrowse {
        let url = Bundle.main.url(forResource: "catalog-browse", withExtension: "json")!
        var value = try! JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
        var details = value["details"] as! [String: Any]
        details["id"] = route.id; details["mediaType"] = route.kind.rawValue
        details["suggestedCategory"] = route.kind == .movie ? "movie" : "anime"
        details["runtimeMinutes"] = route.kind == .movie ? 112 : 24
        value["details"] = details
        return try! JSONDecoder().decode(CatalogBrowse.self, from: JSONSerialization.data(withJSONObject: value))
    }
    static var cast: CastResponse { decode("catalog-cast") }
    static var related: RelatedResponse { decode("catalog-related") }
    static var person: PersonResponse { decode("catalog-person") }
}
