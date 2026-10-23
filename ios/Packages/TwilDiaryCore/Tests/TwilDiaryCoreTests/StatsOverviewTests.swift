import Foundation
import Testing
@testable import TwilDiaryCore

private struct WebStatsCase: Decodable {
    let name: String, workspace: Workspace, period: Period, now: String, timeZone: String, year: Int?, expected: StatsOverview
}

@Test func statsAgreeWithUnchangedWebCalculationAcrossEveryPeriodAndEdgeCase() throws {
    let url = try #require(Bundle.module.url(forResource: "stats-golden", withExtension: "json"))
    let cases = try JSONDecoder().decode([WebStatsCase].self, from: Data(contentsOf: url))
    #expect(cases.count == 17)
    for item in cases {
        let value = StatsOverview(workspace: item.workspace, period: item.period, year: item.year, now: try #require(DiaryDate.parse(item.now)), timeZone: try #require(TimeZone(identifier: item.timeZone)))
        #expect(value.coverage == item.expected.coverage, "\(item.name): date/runtime coverage")
        #expect(value.trend == item.expected.trend, "\(item.name): calendar buckets, comparisons, rewatches and busiest day")
        #expect(value.streaks == item.expected.streaks, "\(item.name): local day streaks and future heatmap cells")
        #expect(value.backlog == item.expected.backlog, "\(item.name): aired catalogue, unknown runtimes and stale titles")
        #expect(value.genres == item.expected.genres, "\(item.name): unique watched-title denominator and other-genre union")
        #expect(value.years == item.expected.years && value.selectedYear == item.expected.selectedYear)
    }
}
