import SwiftUI
import TwilDiaryCore

struct LibraryView: View {
    @Environment(DiaryStore.self) private var store
    @AppStorage("theme") private var theme = DiaryTheme.twilight
    @Environment(AppRouter.self) private var router
    @AppStorage("publicRatingSource") private var ratingSource = PublicRatingSource.tmdb
    @State private var category = LibraryCategory.all
    @State private var status = "all"
    @State private var genre = ""
    @State private var drive = ""
    @State private var search = ""
    @State private var showSearch = false
    @State private var list = false
    @State private var genreRows = false
    @State private var sort = "library"
    @State private var appliedShortcutRevision = 0
    var body: some View {
        VStack(spacing: 0) {
            PageHeader(name: "Library", count: String(store.workspace.activeTitles.count), onSearch: { showSearch.toggle() })
            if showSearch { SearchField(placeholder: "Search your library…", text: $search, label: "library-search").padding(.horizontal, 14).padding(.bottom, 10) }
            CategoryPicker(selection: $category)
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    Menu {
                        Picker("Status", selection: $status) {
                            Text("All statuses").tag("all")
                            ForEach(["planned", "watching", "completed", "dropped", "queue"], id: \.self) { Text($0.capitalized).tag($0) }
                        }
                    } label: { filterChip(status == "all" ? "Status" : status.capitalized, selected: status != "all") }
                    Menu {
                        Picker("Genre", selection: $genre) { Text("All genres").tag(""); ForEach(genres, id: \.self) { value in Text("\(value) (\(store.workspace.activeTitles.filter { $0.genres.contains(value) }.count))").tag(value) } }
                    } label: { filterChip(genre.isEmpty ? "Genre" : genre, selected: !genre.isEmpty) }
                    Menu {
                        Picker("Disk", selection: $drive) { Text("All disks").tag(""); Text("On any disk").tag("mapped"); Text("Not on a disk").tag("unmapped"); ForEach(drives, id: \.self) { Text("Drive " + $0).tag($0) } }
                    } label: { filterChip(drive.isEmpty ? "Disk" : drive == "mapped" ? "On disk" : drive == "unmapped" ? "No disk" : "Drive " + drive, selected: !drive.isEmpty) }
                    NavigationLink(value: AppDestination.trash) { HStack(spacing: 6) { DiaryIcon(name: "trash-2", size: 16); Text("Trash") }.font(.system(size: 13, weight: .semibold)).padding(.horizontal, 15).frame(height: 38).background(Color(webHex: "#111115"), in: Capsule()).overlay(Capsule().strokeBorder(.white.opacity(0.14))) }
                }.buttonStyle(.plain).foregroundStyle(Color(webHex: "#c5c0cf")).padding(.horizontal, 14).padding(.vertical, 10)
            }.scrollIndicators(.hidden)
            HStack(spacing: 6) {
                Text(filtered.count == store.workspace.activeTitles.count ? "All titles" : "\(filtered.count) titles").font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1)
                Spacer(minLength: 0)
                Menu {
                    Picker("Order", selection: $sort) { Text("Library order").tag("library"); Text("Title A–Z").tag("name"); Text("Rating").tag("rating"); Text("Year").tag("year") }
                } label: { HStack(spacing: 5) { DiaryIcon(name: "arrow-down-up", size: 15); Text(sort == "library" ? "Library order" : sort == "name" ? "Title A–Z" : sort == "year" ? "Year" : "Rating"); DiaryIcon(name: "chevron-down", size: 12) }.font(.system(size: 12, weight: .semibold)).fixedSize().padding(.horizontal, 5).frame(height: 38) }.buttonStyle(.plain)
                Button { list = false; genreRows = false } label: { layoutIcon("layout-grid", selected: !list && !genreRows) }.accessibilityLabel("Grid layout")
                Button { list = true; genreRows = false } label: { layoutIcon("rows-3", selected: list && !genreRows) }.accessibilityLabel("List layout")
                Button { genreRows.toggle(); list = false } label: { layoutIcon("list-video", selected: genreRows) }.accessibilityLabel("Genre sections")
            }.foregroundStyle(Color(webHex: "#c5c0cf")).buttonStyle(.plain).padding(.horizontal, 14).padding(.bottom, 10)
            if status != "all" || !genre.isEmpty || !drive.isEmpty { Button("Clear filters") { status = "all"; genre = ""; drive = "" }.font(.caption).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 14).padding(.bottom, 8) }
            ScrollView {
                if genreRows {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        ForEach(genres, id: \.self) { value in
                            let titles = filtered.filter { $0.genres.contains(value) }
                            if !titles.isEmpty {
                                Text(value).font(.headline)
                                ScrollView(.horizontal) { LazyHStack(alignment: .top, spacing: 12) { ForEach(titles) { title in poster(title).frame(width: 112) } } }.scrollIndicators(.hidden)
                            }
                        }
                    }.padding(.horizontal, 14)
                } else if list {
                    LazyVStack(spacing: 8) { ForEach(filtered) { title in NavigationLink(value: title.id) { titleRow(title) }.buttonStyle(.plain) } }.padding(.horizontal, 14)
                } else {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12, alignment: .top), count: 3), alignment: .leading, spacing: 20) { ForEach(filtered) { poster($0) } }.padding(.horizontal, 14)
                }
                if filtered.isEmpty { ContentUnavailableView("No matching titles", systemImage: "books.vertical", description: Text("Change your filters or search.")) }
            }.refreshable { await store.refresh() }
        }.task(id: filtered.map(\.id).joined(separator: ",") + ratingSource.rawValue) { await store.loadPublicRatings(filtered, source: ratingSource) }
            .onChange(of: router.libraryRevision) { _, _ in applyShortcut() }
            .onAppear { applyShortcut() }
    }
    private func applyShortcut() {
        guard router.libraryRevision > appliedShortcutRevision else { return }
        appliedShortcutRevision = router.libraryRevision
        category = .all; search = ""; genre = ""; drive = ""; status = "all"
        switch router.libraryShortcut { case "queue": status = "queue"; case "planned": status = "planned"; case "disk": drive = "mapped"; default: break }
    }
    private func poster(_ title: MediaTitle) -> some View {
        NavigationLink(value: title.id) { PosterCard(title: title) }.buttonStyle(.plain).accessibilityIdentifier("title-" + title.id)
            .contextMenu {
                Button(title.favorite ? "Remove favorite" : "Favorite") { Task { await store.patch(title, values: ["favorite": !title.favorite]) } }
                Button(title.queued == true ? "Remove from Queue" : "Add to Queue") { Task { await store.patch(title, values: ["queued": title.queued != true]) } }
                Button("Move to Trash", role: .destructive) { Task { await store.trash(title) } }
            }
    }
    private func filterChip(_ label: String, selected: Bool) -> some View {
        HStack(spacing: 7) { Text(label).lineLimit(1); DiaryIcon(name: "chevron-down", size: 13) }.font(.system(size: 13, weight: .semibold)).padding(.horizontal, 15).frame(height: 38).background(selected ? theme.accent.opacity(0.16) : Color(webHex: "#111115"), in: Capsule()).overlay(Capsule().strokeBorder(selected ? theme.accent.opacity(0.7) : .white.opacity(0.14)))
    }
    private func layoutIcon(_ name: String, selected: Bool) -> some View { DiaryIcon(name: name, size: 18).frame(width: 32, height: 38).background(selected ? Color(webHex: "#211c30") : .clear, in: RoundedRectangle(cornerRadius: 11)) }
    private var genres: [String] { Set(store.workspace.activeTitles.flatMap(\.genres)).sorted() }
    private var drives: [String] { Set(store.workspace.locations.map(\.driveLetter)).sorted() }
    private var filtered: [MediaTitle] {
        let selected = store.workspace.activeTitles.filter { title in
            let locations = store.workspace.locations.filter { $0.titleId == title.id }
            let diskMatches = drive.isEmpty || (drive == "mapped" ? !locations.isEmpty : drive == "unmapped" ? locations.isEmpty : locations.contains { $0.driveLetter == drive })
            return category.includes(title) && (status == "all" || (status == "queue" ? title.queued == true : title.status == status)) && (genre.isEmpty || title.genres.contains(genre)) && (search.isEmpty || title.name.localizedCaseInsensitiveContains(search)) && diskMatches
        }
        if sort == "name" { return selected.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending } }
        if sort == "year" { return selected.sorted { ($0.year ?? 0) == ($1.year ?? 0) ? $0.name < $1.name : ($0.year ?? 0) > ($1.year ?? 0) } }
        if sort == "rating" { return selected.sorted { let left = store.publicScore($0, source: ratingSource) ?? 0, right = store.publicScore($1, source: ratingSource) ?? 0; return left == right ? $0.name < $1.name : left > right } }
        return selected
    }
}

@MainActor func titleRow(_ title: MediaTitle) -> some View {
    HStack(spacing: 12) {
        Artwork(path: title.poster, title: title.name).frame(width: 48, height: 72).clipShape(RoundedRectangle(cornerRadius: 8))
        VStack(alignment: .leading, spacing: 5) { Text(title.name).font(.subheadline.bold()); Text(title.categoryName).font(.caption).foregroundStyle(.secondary) }
        Spacer(); DiaryIcon(name: "chevron-right", size: 15).foregroundStyle(.secondary)
    }.foregroundStyle(.white).diaryPanel()
}

struct GlanceView: View {
    @Environment(DiaryStore.self) private var store
    @State private var category = LibraryCategory.all
    @State private var search = ""
    @State private var showSearch = false
    var body: some View {
        VStack(spacing: 0) {
            PageHeader(name: "Glance", count: "\(titles.count) watching", onSearch: { showSearch.toggle() })
            if showSearch { SearchField(placeholder: "Find a current watch…", text: $search, label: "Find a current watch").padding(.horizontal, 14).padding(.bottom, 10) }
            CategoryPicker(selection: $category)
            ScrollView {
                LazyVStack(spacing: 8) { ForEach(titles) { ProgressCard(title: $0) } }.padding(.horizontal, 8).padding(.top, 12).padding(.bottom, 16)
                if titles.isEmpty { ContentUnavailableView("Nothing in progress", systemImage: "eye", description: Text("Set a title to Watching to see it here.")) }
            }.refreshable { await store.refresh() }
        }
    }
    private var titles: [MediaTitle] { store.workspace.activeTitles.filter { $0.status == "watching" && category.includes($0) && (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search)) } }
}

struct TrashView: View {
    @Environment(DiaryStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        List(store.workspace.titles.filter { $0.deletedAt != nil }) { title in
            HStack { Text(title.name); Spacer(); Button("Restore") { Task { await store.restore(title) } }.disabled(store.busy) }
        }.overlay { if !store.workspace.titles.contains(where: { $0.deletedAt != nil }) { ContentUnavailableView("Trash is empty", systemImage: "trash") } }
            .navigationTitle("Trash").navigationBarBackButtonHidden().toolbar(.visible, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
    }
}
