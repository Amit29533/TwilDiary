import Foundation
import TwilDiaryCore

extension DiaryStore {
    func searchCatalog(_ query: String, type: String = "all", page: Int = 1) async throws -> CatalogPage {
        if isPreview { return PreviewCatalog.page(query: query, page: page, type: type) }
        return try await read(CatalogTools.apiPath("/api/metadata/search", query: ["q": query, "type": type, "page": String(page)]))
    }
    func discover(_ kind: MediaKind, sort: String = "rating", page: Int = 1) async throws -> CatalogPage {
        if isPreview { return PreviewCatalog.page(page: page, type: kind.rawValue) }
        return try await read(CatalogTools.apiPath("/api/discovery", query: ["type": kind.rawValue, "sort": sort, "page": String(page)]))
    }
    func browse(_ route: CatalogRoute) async throws -> CatalogBrowse {
        if isPreview { return PreviewCatalog.browse(route) }
        return try await read(CatalogTools.apiPath("/api/metadata/browse", query: ["type": route.kind.rawValue, "id": String(route.id)]))
    }
    func cast(_ route: CatalogRoute) async throws -> CastResponse {
        if isPreview { return PreviewCatalog.cast }
        return try await read(CatalogTools.apiPath("/api/metadata/cast", query: ["type": route.kind.rawValue, "id": String(route.id)]))
    }
    func related(_ route: CatalogRoute) async throws -> RelatedResponse {
        if isPreview { return PreviewCatalog.related }
        return try await read(CatalogTools.apiPath("/api/metadata/related", query: ["type": route.kind.rawValue, "id": String(route.id)]))
    }
    func person(_ id: Int) async throws -> PersonResponse {
        if isPreview { return PreviewCatalog.person }
        return try await read(CatalogTools.apiPath("/api/metadata/person", query: ["id": String(id)]))
    }
    func importTitle(_ details: CatalogDetails, category: String) async -> String? {
        guard !busy, !isPreview else { return nil }
        busy = true; defer { busy = false }
        var confirmed = false
        do {
            let result: ImportedTitle = try await read("/api/metadata/import", method: "POST", body: ["mediaType": details.mediaType.rawValue, "tmdbId": details.id, "category": category, "status": "planned"])
            confirmed = true
            try await reload()
            error = nil
            return result.title.id
        } catch {
            if confirmed { self.error = "Added to your library, but the refresh failed. Refresh or try adding again to reopen it; a second copy will not be created." }
            else { self.error = error.localizedDescription }
            return nil
        }
    }
    private struct ImportedTitle: Decodable {
        struct Identity: Decodable { let id: String }
        let title: Identity
    }
}
