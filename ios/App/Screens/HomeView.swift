import SwiftUI
import TwilDiaryCore

struct HomeView: View {
    @Environment(DiaryStore.self) private var store
    @AppStorage("theme") private var theme = DiaryTheme.twilight
    @Environment(AppRouter.self) private var router
    @State private var showSearch = false
    @State private var pick: MediaTitle?
    @State private var upcomingLimit = 3
    var body: some View {
        VStack(spacing: 0) {
            PageHeader(name: "TwilDiary", onSearch: { showSearch.toggle() })
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if showSearch { CatalogSearchView(onClose: { showSearch = false }).padding(.horizontal, -14) }
                    if !watching.isEmpty { VStack(spacing: 10) {
                        SectionHeading(name: "Pick up where you left off") { Button("Glance →") { router.selectedTab = .glance } }
                        Group {
                            ScrollView(.horizontal) {
                                LazyHStack(spacing: 12) { ForEach(watching) { ProgressCard(title: $0, compact: true).containerRelativeFrame(.horizontal, count: 1, spacing: 12) } }.scrollTargetLayout()
                            }.scrollTargetBehavior(.viewAligned).scrollIndicators(.hidden)
                        }
                    } }
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            NavigationLink(value: AppDestination.explore) { shortcut("Explore", "compass") }.accessibilityIdentifier("explore-shortcut")
                            Button { router.library("queue") } label: { shortcut("Queue", "download") }.accessibilityIdentifier("queue-shortcut")
                            Button { router.library("disk") } label: { shortcut("Disk Map", "hard-drive") }
                            Button { router.files() } label: { shortcut("Locations", "folder") }
                            NavigationLink { ScannerReviewView() } label: { shortcut("Fix mismatches", "scan-search") }.accessibilityIdentifier("scanner-shortcut")
                        }.buttonStyle(.plain)
                    }.scrollIndicators(.hidden)
                    VStack(spacing: 10) {
                        SectionHeading(name: "This week") { Button("Stats →") { router.statsToday() }.accessibilityIdentifier("home-stats") }
                        weekPanel
                    }
                    VStack(spacing: 10) {
                        SectionHeading(name: "Up next") { Button("Planned →") { router.library("planned") } }
                        Button { pick = overview.planned.randomElement() } label: {
                            HStack(spacing: 12) {
                                DiaryIcon(name: "shuffle", size: 23)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Pick for me").font(.system(size: 15, weight: .semibold))
                                    Text(overview.planned.isEmpty ? "Add a planned movie or show to get a pick" : "Choose from \(overview.planned.count) unwatched planned titles").font(.system(size: 12)).foregroundStyle(.secondary)
                                }; Spacer(minLength: 0)
                            }.padding(14).background(theme.accent.opacity(0.13), in: RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(theme.accent.opacity(0.28)))
                        }.buttonStyle(.plain).disabled(overview.planned.isEmpty)
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(overview.planned.prefix(3)) { title in
                                VStack(alignment: .leading, spacing: 4) {
                                    NavigationLink(value: title.id) { PosterCard(title: title) }.buttonStyle(.plain)
                                    Text(title.categoryName + (title.runtimeMinutes.map { " · " + DiaryDate.duration($0) + (title.isSeries ? " / ep" : "") } ?? "")).font(.system(size: 11)).foregroundStyle(.secondary)
                                }
                            }
                        }.padding(.top, 8)
                    }
                    VStack(spacing: 10) {
                        SectionHeading(name: "New episodes") { Button("Glance →") { router.selectedTab = .glance } }
                        ForEach(overview.upcoming.prefix(upcomingLimit)) { item in
                            NavigationLink(value: item.title.id) { upcomingRow(item) }.buttonStyle(.plain)
                        }
                        if overview.upcoming.isEmpty { Text("No upcoming air dates in your library for the next 30 days.").font(.system(size: 13)).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).diaryPanel() }
                        if overview.upcoming.count > upcomingLimit { Button("Show more episodes") { upcomingLimit += 5 } }
                        Text("Based on your saved episode dates. Air dates may change.").font(.system(size: 11)).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if !store.workspace.activeEvents.isEmpty { VStack(spacing: 10) {
                        SectionHeading(name: "Recently watched") { NavigationLink("All history →", value: AppDestination.history) }
                        ForEach(sortedHistory(store.workspace.activeEvents).prefix(4)) { event in
                            if let title = store.title(event.titleId) { NavigationLink(value: title.id) { historyRow(event, title: title, workspace: store.workspace) }.buttonStyle(.plain) }
                        }
                    } }
                }.padding(.horizontal, 14).padding(.top, 8).padding(.bottom, 24)
            }.refreshable { await store.refresh() }
        }.sheet(item: $pick) { title in
            NavigationStack {
                VStack(spacing: 20) {
                    Text("Your pick").font(.title2.bold()); PosterCard(title: title).frame(width: 140)
                    Button("Open title") { pick = nil; router.openTitle(title.id, tab: .home) }.buttonStyle(.borderedProminent)
                    Button("Pick again") { pick = overview.planned.randomElement() }.disabled(overview.planned.count < 2)
                }.padding(24).toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { pick = nil } } }
            }.presentationDetents([.medium, .large])
        }
    }
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12, alignment: .top), count: 3)
    private var overview: HomeOverview { HomeOverview(workspace: store.workspace, now: store.now) }
    private var watching: [MediaTitle] { store.workspace.activeTitles.filter { $0.status == "watching" } }
    private func shortcut(_ name: String, _ icon: String) -> some View {
        HStack(spacing: 6) { DiaryIcon(name: icon, size: 17); Text(name).font(.system(size: 12, weight: .semibold)) }.foregroundStyle(Color(webHex: "#c5c0cf")).padding(.horizontal, 14).frame(height: 42).background(Color(webHex: "#111115"), in: RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.white.opacity(0.13)))
    }
    private func upcomingRow(_ item: HomeOverview.Upcoming) -> some View {
        HStack(spacing: 12) {
            Artwork(path: item.title.poster, title: item.title.name).frame(width: 42, height: 62).clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 5) { Text(item.title.name).font(.system(size: 14, weight: .semibold)).lineLimit(2); Text("S\(item.episode.season) E\(item.episode.number)").font(.system(size: 12)).foregroundStyle(.secondary) }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 5) { Text(item.daysAway == 0 ? "Today" : item.daysAway == 1 ? "Tomorrow" : "In \(item.daysAway) days").font(.system(size: 12, weight: .semibold)).foregroundStyle(.tint); Text(item.date, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated)).font(.system(size: 11)).foregroundStyle(.secondary) }
        }.foregroundStyle(.primary).diaryPanel()
    }
    private var weekPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 20) { metric(DiaryDate.duration(overview.minutes), "Watch time", accent: true); metric(String(overview.watches), "Watches"); metric("\(overview.streak) \(overview.streak == 1 ? "day" : "days")", "Current streak") }
            Rectangle().fill(.white.opacity(0.08)).frame(height: 1)
            HStack(alignment: .top, spacing: 0) { ForEach(overview.days) { day in
                NavigationLink { HistoryView(initialDay: day.date) } label: {
                    VStack(spacing: 6) {
                        Text(day.date, format: .dateTime.weekday(.narrow)).font(.system(size: 10)).foregroundStyle(.secondary)
                        Text(day.date, format: .dateTime.day()).font(.system(size: 16, weight: .semibold)).foregroundStyle(DiaryDate.calendar().isDate(day.date, inSameDayAs: store.now) ? theme.accent : .primary)
                        VStack { Spacer(minLength: 0); RoundedRectangle(cornerRadius: 3).fill(day.minutes > 0 ? theme.accent : .white.opacity(0.12)).frame(width: 10, height: day.minutes > 0 ? max(4, 30 * CGFloat(day.minutes) / CGFloat(max(1, overview.days.map(\.minutes).max() ?? 0))) : 2) }.frame(height: 30)
                    }.frame(maxWidth: .infinity).foregroundStyle(.primary).opacity(day.future ? 0.4 : 1)
                }.buttonStyle(.plain).disabled(day.future).accessibilityLabel("\(day.date.formatted(date: .abbreviated, time: .omitted)), \(day.count) watches")
            } }
            if overview.unknownDates > 0 || overview.missingRuntime > 0 { Text("Dated watches only. Missing runtimes are excluded from watch time.").font(.system(size: 11)).foregroundStyle(.secondary).lineSpacing(3) }
        }.diaryPanel()
    }
    private func metric(_ value: String, _ label: String, accent: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 3) { Text(value).font(.system(size: 22, weight: .bold)).tracking(-0.7).foregroundStyle(accent ? theme.accent : .primary).lineLimit(1).minimumScaleFactor(0.7); Text(label).font(.system(size: 11)).foregroundStyle(.secondary) }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct QueueView: View {
    @Environment(DiaryStore.self) private var store
    var planned = false
    var body: some View {
        ScrollView { LazyVStack { ForEach(store.workspace.activeTitles.filter { planned ? $0.status == "planned" : $0.queued == true }) { title in NavigationLink(value: title.id) { titleRow(title) }.buttonStyle(.plain) } }.padding(14) }.navigationTitle(planned ? "Planned" : "Queue").toolbar(.visible, for: .navigationBar)
    }
}

func sortedHistory(_ events: [WatchEvent]) -> [WatchEvent] {
    events.sorted {
        let left = DiaryDate.parse($0.watchedAt), right = DiaryDate.parse($1.watchedAt)
        if let left, let right, left != right { return left > right }
        if (left != nil) != (right != nil) { return left != nil }
        return $0.recordedAt == $1.recordedAt ? $0.id < $1.id : $0.recordedAt > $1.recordedAt
    }
}

@MainActor func historyRow(_ event: WatchEvent, title: MediaTitle, workspace: Workspace) -> some View {
    HStack(alignment: .top, spacing: 12) {
        Artwork(path: title.poster, title: title.name).frame(width: 60, height: 90).clipShape(RoundedRectangle(cornerRadius: 8))
        VStack(alignment: .leading, spacing: 5) {
            Text(title.name).font(.system(size: 15, weight: .semibold)).lineLimit(2)
            Text(workspace.episodes.first(where: { $0.id == event.episodeId }).map { "S\($0.season) E\($0.number)" } ?? title.categoryName).font(.system(size: 13)).foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Text(DiaryDate.parse(event.watchedAt).map { $0.formatted(.dateTime.day().month(.abbreviated).year()) } ?? "Date unknown").font(.system(size: 12)).foregroundStyle(.secondary)
        }.frame(height: 90, alignment: .topLeading)
        Spacer(minLength: 0); DiaryIcon(name: "chevron-right", size: 16).foregroundStyle(.secondary).frame(height: 90)
    }.padding(6).foregroundStyle(.white).frame(maxWidth: .infinity, alignment: .leading).background(Color(webHex: "#111115"), in: RoundedRectangle(cornerRadius: 13)).overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(.white.opacity(0.13)))
}

struct HistoryView: View {
    @Environment(DiaryStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var initialDay: Date? = nil
    var initialUnknown = false
    @State private var showSearch = false
    @State private var query = ""
    @State private var period = "all"
    @State private var showRange = false
    @State private var from = Date.now
    @State private var to = Date.now
    @State private var includeUnknown = false
    var body: some View {
        VStack(spacing: 0) {
            PageHeader(name: "Recently watched", onSearch: { showSearch.toggle() }, onDone: { dismiss() }, doneIdentifier: "history-done")
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if showSearch { CatalogSearchView(onClose: { showSearch = false }).padding(.horizontal, -14) }
                    HStack {
                        Text("Your watch history").font(.system(size: 17, weight: .semibold)); Spacer(minLength: 2)
                        Picker("Date filter", selection: $period) { Text("Any date").tag("all"); Text("Today").tag("today"); Text("Last 7 days").tag("7d"); Text("This month").tag("month"); Text("Date range").tag("range"); Text("Undated").tag("unknown") }.pickerStyle(.menu).fixedSize().font(.system(size: 13))
                    }
                    SearchField(placeholder: "Find a watched title…", text: $query, label: "Find a watched title")
                    DisclosureGroup("Date filters", isExpanded: $showRange) {
                        VStack(spacing: 12) {
                            DatePicker("From", selection: $from, displayedComponents: .date)
                            DatePicker("To", selection: $to, displayedComponents: .date)
                            Toggle("Include undated watches", isOn: $includeUnknown)
                            Button("Apply date range") { if to < from { to = from }; period = "range" }
                        }.font(.subheadline).padding(.top, 12)
                    }.font(.system(size: 13)).foregroundStyle(.secondary)
                    Text("\(events.count) watches").font(.caption).foregroundStyle(.secondary)
                    if period != "all" || !query.isEmpty { Button("Clear filters") { query = ""; period = "all"; includeUnknown = false } }
                    LazyVStack(spacing: 8) { ForEach(events) { event in if let title = store.title(event.titleId) { NavigationLink(value: title.id) { historyRow(event, title: title, workspace: store.workspace) }.buttonStyle(.plain) } } }
                    if events.isEmpty { ContentUnavailableView("No watches found", systemImage: "clock") }
                }.padding(14)
            }
        }.navigationBarBackButtonHidden().toolbar(.hidden, for: .navigationBar)
            .task { if let initialDay { from = initialDay; to = initialDay; period = "range" }; if initialUnknown { period = "unknown" } }

    }
    private var events: [WatchEvent] {
        let calendar = DiaryDate.calendar()
        return sortedHistory(store.workspace.activeEvents.filter { event in
            guard query.isEmpty || (store.title(event.titleId)?.name.localizedCaseInsensitiveContains(query) ?? false) else { return false }
            if period == "all" { return true }
            if period == "unknown" { return DiaryDate.parse(event.watchedAt) == nil }
            guard let date = DiaryDate.parse(event.watchedAt) else { return period == "range" && includeUnknown }
            guard calendar.startOfDay(for: date) <= calendar.startOfDay(for: store.now) else { return false }
            switch period {
            case "today": return calendar.isDate(date, inSameDayAs: store.now)
            case "month": return calendar.isDate(date, equalTo: store.now, toGranularity: .month)
            case "7d": return date >= calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: store.now))!
            default: return date >= calendar.startOfDay(for: from) && date < calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: to))!
            }
        })
    }
}
