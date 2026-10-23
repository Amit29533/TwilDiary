import SwiftUI
import Charts
import TwilDiaryCore

struct StatsView: View {
    @Environment(DiaryStore.self) private var store
    @AppStorage("theme") private var theme = DiaryTheme.twilight
    @Environment(AppRouter.self) private var router
    @State private var period = Period.month
    @State private var appliedShortcutRevision = 0
    @State private var year = DiaryDate.calendar().component(.year, from: Date.now)
    @State private var selectedDay: Date?
    @State private var showGenres = false
    var body: some View {
        VStack(spacing: 0) {
            PageHeader(name: "Stats")
            ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack { Text("\(datedCount) of \(store.workspace.activeEvents.count) watches have dates").font(.subheadline.bold()); Spacer() }
                    ProgressView(value: Double(datedCount), total: Double(max(1, store.workspace.activeEvents.count)))
                    Text("\(store.workspace.activeEvents.count - datedCount) undated watches are left out of periods and trends. Unknown runtimes are left out of watch time.").font(.caption).foregroundStyle(.secondary)
                }.diaryPanel()
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 6) {
                        Text("Watch time").font(.title3.bold()).lineLimit(1).minimumScaleFactor(0.8)
                        Spacer(minLength: 0)
                        Picker("Watch time period", selection: $period) { ForEach(Period.allCases) { Text($0.label).tag($0) } }.pickerStyle(.menu).fixedSize()
                        if period == .year { Picker("Year", selection: $year) { ForEach(years, id: \.self) { Text(String($0)).tag($0) } }.pickerStyle(.menu).fixedSize() }
                    }
                    StatsRangeSelector(selection: $period)
                    Text(DiaryDate.duration(minutes)).font(.system(size: 38, weight: .bold)).foregroundStyle(.tint).tracking(-1)
                    Text("\(events.count) watches · \(Set(events.map(\.titleId)).count) movies & shows").font(.caption).foregroundStyle(.secondary)
                    Chart(daily) { day in BarMark(x: .value("Day", day.date, unit: .day), y: .value("Minutes", day.minutes)).foregroundStyle(.tint).cornerRadius(3) }
                        .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) }.chartYAxis(.hidden)
                        .chartXSelection(value: $selectedDay).frame(height: 120)
                    if let selectedDay {
                        let selected = events.filter { DiaryDate.parse($0.watchedAt).map { DiaryDate.calendar().isDate($0, inSameDayAs: selectedDay) } ?? false }
                        Text(selectedDay, format: .dateTime.day().month(.wide).year()).font(.subheadline.bold())
                        ForEach(selected) { event in if let title = store.title(event.titleId) { NavigationLink(value: title.id) { titleRow(title) }.buttonStyle(.plain) } }
                    }
                    Text("Dated watches only. Estimated from title runtimes. Includes rewatches.").font(.caption).foregroundStyle(.secondary)
                }.diaryPanel()
                VStack(alignment: .leading, spacing: 14) {
                    Text("Streaks").font(.title3.bold())
                    HStack { Text("\(homeSummary.streak) \(homeSummary.streak == 1 ? "day" : "days")").font(.title2.bold()); Spacer(); Text("Current streak").font(.caption).foregroundStyle(.secondary) }
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 12), spacing: 3) {
                        ForEach(heatmap, id: \.date) { day in
                            RoundedRectangle(cornerRadius: 3).fill(day.count == 0 ? Color.white.opacity(0.06) : theme.accent.opacity(min(1, 0.3 + Double(day.count) * 0.15))).frame(height: 14).accessibilityLabel("\(day.date.formatted(date: .abbreviated, time: .omitted)): \(day.count) watches")
                        }
                    }
                    Text("Last 12 weeks").font(.caption2).foregroundStyle(.secondary)
                }.diaryPanel()
                VStack(alignment: .leading, spacing: 16) {
                    Text("Backlog").font(.title3.bold())
                    ForEach(["planned", "watching", "completed", "dropped"], id: \.self) { status in HStack { Text(status.capitalized); Spacer(); Text("\(store.workspace.activeTitles.filter { $0.status == status }.count)").bold() }.font(.subheadline) }
                    NavigationLink { QueueView(planned: true) } label: { Text("Open planned →").font(.subheadline.bold()) }
                }.diaryPanel()
                VStack(alignment: .leading, spacing: 14) {
                    Text("Genre mix").font(.title3.bold())
                    Text("Share of your \(watchedTitles.count) watched titles with each genre").font(.caption).foregroundStyle(.secondary)
                    ForEach(Array(genres.prefix(showGenres ? genres.count : 5)), id: \.name) { genre in
                        VStack(spacing: 5) { HStack { Text(genre.name).bold(); Spacer(); Text("\(genre.percent)% · \(genre.count) titles").foregroundStyle(.secondary) }.font(.caption); ProgressView(value: Double(genre.percent), total: 100) }
                    }
                    if genres.count > 5 { Button(showGenres ? "Show top 5" : "All other genres") { showGenres.toggle() }.font(.subheadline.bold()) }
                    Text("Titles can have several genres, so these shares add up to more than 100%.").font(.caption).foregroundStyle(.secondary)
                }.diaryPanel()
            }.padding(.horizontal, 16).padding(.bottom, 24)
            }.refreshable { await store.refresh() }
        }.onChange(of: router.statsRevision) { _, _ in applyShortcut() }.onAppear { applyShortcut() }.onChange(of: period) { _, _ in selectedDay = nil }
    }
    private func applyShortcut() { if router.statsRevision > appliedShortcutRevision { appliedShortcutRevision = router.statsRevision; period = .today; selectedDay = nil } }
    private var homeSummary: HomeOverview { HomeOverview(workspace: store.workspace, now: store.now) }
    private var heatmap: [(date: Date, count: Int)] {
        let calendar = DiaryDate.calendar(), today = DiaryDate.calendar().startOfDay(for: store.now)
        var counts: [Date: Int] = [:]
        for event in store.workspace.activeEvents { if let date = DiaryDate.parse(event.watchedAt), date <= store.now { counts[calendar.startOfDay(for: date), default: 0] += 1 } }
        // Column-major order: twelve weeks across, Monday to Sunday down.
        let monday = calendar.dateInterval(of: .weekOfYear, for: store.now)!.start
        return (0..<84).map { index in
            let date = calendar.date(byAdding: .day, value: (index % 12 - 11) * 7 + index / 12, to: monday)!
            return (date, date > today ? 0 : counts[date] ?? 0)
        }
    }
    private var events: [WatchEvent] { store.workspace.activeEvents.filter { event in DiaryDate.parse(event.watchedAt).map { period.contains($0, now: store.now, calendar: DiaryDate.calendar(), year: year) } ?? false } }
    private var minutes: Int { events.reduce(0) { $0 + max(0, store.title($1.titleId)?.runtimeMinutes ?? 0) } }
    private var datedCount: Int { store.workspace.activeEvents.filter { DiaryDate.parse($0.watchedAt) != nil }.count }
    private var years: [Int] { Set(store.workspace.activeEvents.compactMap { DiaryDate.parse($0.watchedAt).map { DiaryDate.calendar().component(.year, from: $0) } } + [DiaryDate.calendar().component(.year, from: Date.now)]).sorted(by: >) }
    private struct Day: Identifiable { var id: Date { date }; let date: Date; let minutes: Int }
    private var daily: [Day] {
        var values: [Date: Int] = [:]
        for event in events { if let date = DiaryDate.parse(event.watchedAt) { values[DiaryDate.calendar().startOfDay(for: date), default: 0] += max(0, store.title(event.titleId)?.runtimeMinutes ?? 0) } }
        return values.map { Day(date: $0.key, minutes: $0.value) }.sorted { $0.date < $1.date }
    }
    private struct Genre { let name: String; let count: Int; let percent: Int }
    private var watchedTitles: [MediaTitle] { let watched = Set(store.workspace.activeEvents.map(\.titleId)); return store.workspace.activeTitles.filter { watched.contains($0.id) } }
    private var genres: [Genre] {
        var counts: [String: Int] = [:]
        let titles = watchedTitles
        for title in titles {
            let names = Set(title.genres.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
            for genre in names.isEmpty ? ["Uncategorized"] : Array(names) { counts[genre, default: 0] += 1 }
        }
        return counts.map { Genre(name: $0.key, count: $0.value, percent: Int((Double($0.value) / Double(max(1, titles.count)) * 100).rounded())) }.sorted { $0.count == $1.count ? $0.name < $1.name : $0.count > $1.count }
    }
}

private struct StatsRangeSelector: View {
    @Binding var selection: Period
    @AppStorage("theme") private var theme = DiaryTheme.twilight
    private let ranges: [Period] = [.week, .month, .ninetyDays, .year, .all]
    var body: some View {
        HStack(spacing: 0) {
            ForEach(ranges) { range in
                Button { selection = range } label: {
                    Text(label(range)).font(.system(size: 12, weight: .semibold))
                        .frame(maxWidth: .infinity).frame(height: 34)
                }.buttonStyle(.plain).foregroundStyle(selection == range ? Color(webHex: "#21182e") : Color(webHex: "#c5c0cf")).accessibilityAddTraits(selection == range ? .isSelected : [])
            }
        }.frame(height: 34).background(alignment: .leading) {
            GeometryReader { proxy in
                if let index = ranges.firstIndex(of: selection) {
                    Rectangle().fill(theme.accent).frame(width: proxy.size.width / CGFloat(ranges.count), height: 34).offset(x: proxy.size.width * CGFloat(index) / CGFloat(ranges.count))
                }
            }
        }.clipShape(RoundedRectangle(cornerRadius: 11)).overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(.white.opacity(0.13))).id(selection)
    }
    private func label(_ value: Period) -> String {
        switch value { case .week: "7D"; case .month: "30D"; case .ninetyDays: "90D"; case .year: "1Y"; case .all: "All"; case .today: "Today" }
    }
}
