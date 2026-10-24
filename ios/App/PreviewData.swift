import Foundation
import TwilDiaryCore

enum PreviewData {
    static var workspace: Workspace {
        let url = Bundle.main.url(forResource: "reference-workspace", withExtension: "json")!
        return try! JSONDecoder().decode(Workspace.self, from: Data(contentsOf: url))
    }
    static func card(_ title: MediaTitle, workspace: Workspace, season: Int? = nil) -> WatchCard {
        let watched = Set(workspace.activeEvents.filter { $0.titleId == title.id }.compactMap(\.episodeId))
        let today = "2026-10-23"
        let selected = season ?? EpisodeSelection.preferredSeason(in: workspace, titleID: title.id, today: today)
        let episodes = workspace.episodes.filter { $0.titleId == title.id && $0.season == selected }.sorted { $0.number < $1.number }
        let next = EpisodeSelection.next(in: workspace, titleID: title.id, today: today, season: selected)
        let prior = workspace.activeEvents.filter { event in event.titleId == title.id && (!title.isSeries || episodes.contains(where: { $0.id == event.episodeId })) }.last
        let previousEpisode = workspace.episodes.first { $0.id == prior?.episodeId }
        let body: [String: Any] = [
            "progress": ["watched": title.isSeries ? episodes.filter { watched.contains($0.id) }.count : (prior == nil ? 0 : 1), "total": title.isSeries ? episodes.count : 1],
            "season": title.isSeries ? ["number": selected, "name": "Season \(selected)", "metadataLoadedAt": "2026-10-23T00:00:00Z"] as [String: Any] : NSNull(),
            "next": next.map { ["id": $0.id, "number": $0.number] as [String: Any] } as Any? ?? NSNull(),
            "previous": prior.map { ["id": $0.id, "version": $0.version ?? 1, "episodeId": $0.episodeId as Any? ?? NSNull(), "number": previousEpisode?.number as Any? ?? NSNull()] as [String: Any] } as Any? ?? NSNull()
        ]
        return try! JSONDecoder().decode(WatchCard.self, from: JSONSerialization.data(withJSONObject: body))
    }
}
