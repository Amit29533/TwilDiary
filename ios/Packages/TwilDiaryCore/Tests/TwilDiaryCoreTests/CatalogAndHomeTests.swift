import Foundation
import Testing
@testable import TwilDiaryCore

@Test func publicRatingsNeverSubstituteAnotherSource() throws {
    let unavailable = try JSONDecoder().decode(PublicRating.self, from: Data(#"{"score":null,"state":"unavailable"}"#.utf8))
    let rated = try JSONDecoder().decode(PublicRating.self, from: Data(#"{"score":7.3,"state":"rated"}"#.utf8))
    #expect(CommunityScore.value(tmdb: 8.5, trakt: unavailable, source: .trakt) == nil)
    #expect(CommunityScore.value(tmdb: 8.5, trakt: rated, source: .trakt) == 7.3)
    #expect(CommunityScore.value(tmdb: 8.5, trakt: rated, source: .tmdb) == 8.5)
    #expect(CommunityScore.value(tmdb: .infinity, trakt: nil, source: .tmdb) == nil)
}
@Test func catalogIdentityIncludesKindAndPagingDeduplicates() throws {
    func item(_ kind: String) throws -> CatalogItem {
        try JSONDecoder().decode(CatalogItem.self, from: Data("{\"id\":42,\"mediaType\":\"\(kind)\",\"name\":\"Sample\",\"overview\":\"\"}".utf8))
    }
    let movie = try item("movie"), series = try item("tv")
    #expect(movie.route != series.route)
    #expect(CatalogTools.merging([movie], [movie, series]).count == 2)
    #expect(CatalogTools.image("/image_12.jpg") == "https://image.tmdb.org/t/p/w500/image_12.jpg")
    #expect(CatalogTools.image("//evil.test/a.jpg") == nil)
    #expect(CatalogTools.image("/../private.jpg") == nil)
    #expect(CatalogTools.image("/a.jpg", size: "original") == nil)
}
@Test func weeklySummaryCountsRewatchesButNotFutureOrRevokedEvents() throws {
    var workspace = SampleWorkspace.make()
    let event = try #require(workspace.events.first)
    let now = try #require(DiaryDate.parse("2026-10-23T12:00:00Z"))
    var calendar = DiaryDate.calendar(timeZone: TimeZone(secondsFromGMT: 0)!)
    calendar.firstWeekday = 2
    let initial = HomeOverview(workspace: workspace, now: now, calendar: calendar)
    workspace.events.append(event)
    let repeated = HomeOverview(workspace: workspace, now: now, calendar: calendar)
    #expect(repeated.watches == initial.watches + 1)
    #expect(repeated.minutes == initial.minutes + (workspace.titles.first { $0.id == event.titleId }?.runtimeMinutes ?? 0))
    #expect(repeated.days.count == 7)
    #expect(calendar.component(.weekday, from: repeated.days[0].date) == 2)
    #expect(repeated.days.filter(\.future).allSatisfy { $0.count == 0 })
    #expect(!repeated.planned.contains { $0.id == event.titleId })
}
