import Foundation
import TwilDiaryCore

extension DiaryStore {
    func searchDiary(_ query: String, page: Int = 1) async throws -> DiarySearchPage {
        guard DiarySearchTools.ready(query), (1...500).contains(page) else { throw APIError.message("Enter a title or IMDb ID (2–200 characters)") }
        if isPreview {
            let result = PreviewCatalog.page(query: query, page: page)
            return DiarySearchPage(library: [], online: result.items, page: result.page, totalPages: result.totalPages)
        }
        return try await read(CatalogTools.apiPath("/api/search", query: ["q": query, "scope": "online", "page": String(page)]))
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
