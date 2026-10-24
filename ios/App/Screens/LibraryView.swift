import SwiftUI
import TwilDiaryCore

struct LibraryView: View {
    var archived = false
    @Environment(DiaryStore.self) private var store
    @Environment(\.dismiss) private var dismiss
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
    @State private var selecting = false
    @State private var selected = Set<String>()
    @State private var review: CollectionReview?
    @State private var confirmEmptyTrash = false
    var body: some View {
        VStack(spacing: 0) {
            PageHeader(name: "Library", count: String(collection.count), onSearch: { showSearch.toggle(); if !showSearch { search = "" } })
            if showSearch { SearchField(placeholder: "Search your library…", text: $search, label: "library-search", autoFocus: true).padding(.horizontal, 14).padding(.bottom, 10) }
            CategoryPicker(selection: $category)
            filterBar
            orderingBar
            if category != .all || status != "all" || !genre.isEmpty || !drive.isEmpty || !search.isEmpty { Button("Clear filters") { category = .all; status = "all"; genre = ""; drive = ""; search = "" }.font(.caption).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 14).padding(.bottom, 8) }
            if ratingSource == .trakt {
                if store.communityRatings.loading { ratingStatus("Loading Trakt community ratings…") }
                else if store.communityRatings.unavailable { ratingStatus("Some Trakt ratings are unavailable. Try again later or select TMDB in Settings.") }
            }
            collectionContent
        }.task(id: collection.map(\.id).sorted().joined(separator: ",") + ratingSource.rawValue) { await store.loadPublicRatings(collection, source: ratingSource) }
            .onChange(of: router.libraryRevision) { _, _ in applyShortcut() }
            .onAppear { applyShortcut() }
            .onChange(of: filterScope) { _, _ in selecting = false; selected = [] }
            .onChange(of: filtered.map(\.id)) { _, ids in selected.formIntersection(ids) }
            .sheet(item: $review) { value in CollectionReviewView(review: value) { selecting = false; selected = [] } }
            .confirmationDialog("Empty Trash?", isPresented: $confirmEmptyTrash, titleVisibility: .visible) { Button("Empty Trash", role: .destructive) { Task { await store.emptyTrash() } } } message: { Text("This permanently removes every title in Trash and its diary history. Files on your disks stay untouched.") }
    }
    private func ratingStatus(_ message: String) -> some View {
        Text(message).font(.system(size: 12)).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 14).padding(.bottom, 10)
    }
    private var filterBar: some View {
        ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    Menu {
                        Picker("Status", selection: $status) {
                            Text("All statuses").tag("all")
                            ForEach(["planned", "watching", "completed", "dropped", "queue"], id: \.self) { Text($0.capitalized).tag($0) }
                        }
                    } label: { filterChip(status == "all" ? "Status" : status.capitalized, selected: status != "all") }
                    Menu {
                        Picker("Genre", selection: $genre) { Text("All genres").tag(""); ForEach(genres, id: \.self) { value in Text("\(value) (\(collection.filter { $0.genres.contains(value) }.count))").tag(value) } }
                    } label: { filterChip(genre.isEmpty ? "Genre" : genre, selected: !genre.isEmpty) }
                    Menu {
                        Picker("Disk", selection: $drive) { Text("All disks").tag(""); Text("On any disk").tag("mapped"); Text("Not on a disk").tag("unmapped"); ForEach(disks) { Text($0.letters.joined(separator: " / ") + " · " + $0.deviceName).tag($0.key) } }
                    } label: { filterChip(driveLabel, selected: !drive.isEmpty) }
                    if archived { Button { dismiss() } label: { trashChip }.accessibilityLabel("Return to Library") }
                    else { NavigationLink(value: AppDestination.trash) { trashChip }.accessibilityLabel("Open Trash") }
                }.buttonStyle(.plain).foregroundStyle(Color(webHex: "#c5c0cf")).padding(.horizontal, 14).padding(.vertical, 10)
            }.scrollIndicators(.hidden)
    }
    private var orderingBar: some View {
        HStack(spacing: 6) {
                Text(archived ? "In Trash" : filtered.count == collection.count ? "All titles" : "\(filtered.count) titles").font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1)
                Spacer(minLength: 0)
                Menu {
                    Picker("Order", selection: $sort) { Text("Library order").tag("library"); Text("Title A–Z").tag("name"); Text("Rating").tag("rating"); Text("Year").tag("year") }
                } label: { HStack(spacing: 5) { DiaryIcon(name: "arrow-down-up", size: 15); Text(sort == "library" ? "Library order" : sort == "name" ? "Title A–Z" : sort == "year" ? "Year" : "Rating"); DiaryIcon(name: "chevron-down", size: 12) }.font(.system(size: 12, weight: .semibold)).fixedSize().padding(.horizontal, 5).frame(height: 38) }.buttonStyle(.plain)
                if selecting { Button("Done selecting", systemImage: "xmark") { selecting = false; selected = [] }.labelStyle(.iconOnly) }
                else {
                    Button { list = false; genreRows = false } label: { layoutIcon("layout-grid", selected: !list && !genreRows) }.accessibilityLabel("Grid layout")
                    Button { list = true; genreRows = false } label: { layoutIcon("rows-3", selected: list && !genreRows) }.accessibilityLabel("List layout")
                    if !archived { Button { genreRows.toggle(); list = false } label: { layoutIcon("list-video", selected: genreRows) }.accessibilityLabel("Genre sections") }
                }
            }.foregroundStyle(Color(webHex: "#c5c0cf")).buttonStyle(.plain).padding(.horizontal, 14).padding(.bottom, 10)
    }
    private var collectionContent: some View {
        ScrollView {
                if archived {
                    VStack(alignment: .leading, spacing: 10) {
                        Button("Empty Trash", systemImage: "trash", role: .destructive) { confirmEmptyTrash = true }.buttonStyle(.bordered).disabled(store.busy || collection.isEmpty).accessibilityIdentifier("empty-trash")
                        Text("Removed titles stay here with their history. Deleting permanently only removes diary records; your disk files stay untouched.").font(.caption).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 14).padding(.bottom, 14)
                }
                if selecting { CollectionSelectionPanel(titles: filtered, selected: $selected, archived: archived, onReview: prepareReview).padding(.horizontal, 14).padding(.bottom, 12) }
                if genreRows && !selecting {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        ForEach(LibraryShelf.make(filtered)) { shelf in
                            HStack { Text(shelf.genre).font(.headline); Text("\(shelf.titles.count)").font(.caption).foregroundStyle(.secondary); Spacer(); if shelf.genre != "Without a genre" { Button("See all") { genre = shelf.genre; genreRows = false }.font(.caption.bold()).accessibilityLabel("See all \(shelf.genre) titles") } }
                            ScrollView(.horizontal) { LazyHStack(alignment: .top, spacing: 12) { ForEach(shelf.titles) { title in poster(title).frame(width: 112) } } }.scrollIndicators(.hidden)
                        }
                    }.padding(.horizontal, 14)
                } else if list {
                    LazyVStack(spacing: 8) { ForEach(filtered) { title in poster(title, row: true) } }.padding(.horizontal, 14)
                } else {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12, alignment: .top), count: 3), alignment: .leading, spacing: 20) { ForEach(filtered) { poster($0) } }.padding(.horizontal, 14)
                }
                if filtered.isEmpty { ContentUnavailableView(archived ? "Trash is clear" : "No matching titles", systemImage: archived ? "trash" : "books.vertical", description: Text(archived ? "Removed titles will appear here. Try clearing filters if a title is missing." : "Change your filters or search.")) }
            }.refreshable { await store.refresh() }
    }
    private func applyShortcut() {
        guard !archived, router.libraryRevision > appliedShortcutRevision else { return }
        appliedShortcutRevision = router.libraryRevision
        category = .all; search = ""; genre = router.libraryGenreShortcut; drive = router.libraryDiskShortcut; status = "all"
        switch router.libraryShortcut { case "queue": status = "queue"; case "planned", "watching", "completed", "dropped": status = router.libraryShortcut ?? "all"; case "disk": drive = "mapped"; default: break }
    }
    @ViewBuilder private func poster(_ title: MediaTitle, row: Bool = false) -> some View {
        if selecting {
            Button { if selected.contains(title.id) { selected.remove(title.id) } else if selected.count < CollectionRequest.limit { selected.insert(title.id) } } label: {
                cardContent(title, row: row).overlay(alignment: .topTrailing) { Image(systemName: selected.contains(title.id) ? "checkmark.circle.fill" : "circle").font(.system(size: 22)).foregroundStyle(selected.contains(title.id) ? theme.accent : .white).padding(7).shadow(color: .black, radius: 3) }
            }.buttonStyle(.plain).disabled(store.busy || (!selected.contains(title.id) && selected.count >= CollectionRequest.limit)).accessibilityIdentifier("select-title-" + title.id).accessibilityAddTraits(selected.contains(title.id) ? .isSelected : [])
        } else if archived {
            VStack(spacing: 8) {
                cardContent(title, row: row)
                HStack { Button("Restore") { review = CollectionReview(titles: [title], change: .restore) }.font(.caption.bold()); Spacer(); Button("Delete permanently", systemImage: "trash", role: .destructive) { review = CollectionReview(titles: [title], change: .purge) }.labelStyle(.iconOnly) }.buttonStyle(.bordered).disabled(store.busy)
            }.contextMenu { Button("Select") { selecting = true; selected = [title.id] } }.accessibilityIdentifier("archived-title-" + title.id)
        } else {
            NavigationLink(value: title.id) { cardContent(title, row: row) }.buttonStyle(.plain).contentShape(Rectangle()).accessibilityIdentifier("title-" + title.id)
                .contextMenu {
                    Button("Select") { selecting = true; selected = [title.id] }
                    Button(title.favorite ? "Remove favorite" : "Favorite") { review = CollectionReview(titles: [title], change: .favorite(!title.favorite)) }
                    Button(title.queued == true ? "Remove from Queue" : "Add to Queue") { review = CollectionReview(titles: [title], change: .queue(title.queued != true)) }
                    Button("Move to Trash", role: .destructive) { review = CollectionReview(titles: [title], change: .trash) }
                }
        }
    }
    @ViewBuilder private func cardContent(_ title: MediaTitle, row: Bool) -> some View { if row { titleRow(title) } else { PosterCard(title: title).contentShape(Rectangle()) } }
    private func prepareReview(_ change: CollectionChange) { let titles = filtered.filter { selected.contains($0.id) }; if !titles.isEmpty { review = CollectionReview(titles: titles, change: change) } }
    private var filterScope: String { [category.rawValue, status, genre, drive, search, sort].joined(separator: "\n") }
    private var collection: [MediaTitle] { store.workspace.titles.filter { ($0.deletedAt != nil) == archived } }
    private var trashChip: some View { HStack(spacing: 6) { DiaryIcon(name: "trash-2", size: 16); Text("Trash") }.font(.system(size: 13, weight: .semibold)).padding(.horizontal, 15).frame(height: 38).background(archived ? theme.accent.opacity(0.16) : Color(webHex: "#111115"), in: Capsule()).overlay(Capsule().strokeBorder(archived ? theme.accent.opacity(0.7) : .white.opacity(0.14))) }
    private func filterChip(_ label: String, selected: Bool) -> some View {
        HStack(spacing: 7) { Text(label).lineLimit(1); DiaryIcon(name: "chevron-down", size: 13) }.font(.system(size: 13, weight: .semibold)).padding(.horizontal, 15).frame(height: 38).background(selected ? theme.accent.opacity(0.16) : Color(webHex: "#111115"), in: Capsule()).overlay(Capsule().strokeBorder(selected ? theme.accent.opacity(0.7) : .white.opacity(0.14)))
    }
    private func layoutIcon(_ name: String, selected: Bool) -> some View { DiaryIcon(name: name, size: 18).frame(width: 32, height: 38).background(selected ? Color(webHex: "#211c30") : .clear, in: RoundedRectangle(cornerRadius: 11)) }
    private var genres: [String] { LibraryShelf.make(collection).map(\.genre).filter { $0 != "Without a genre" } }
    private var disks: [DiskSummary] { DiskSummary.make(store.workspace.locations) }
    private var driveLabel: String { if drive.isEmpty { return "Disk" }; if drive == "mapped" { return "On disk" }; if drive == "unmapped" { return "No disk" }; return disks.first { $0.key == drive }?.letters.joined(separator: " / ") ?? "Selected disk" }
    private var filtered: [MediaTitle] {
        var query = LibraryQuery()
        query.archived = archived
        query.query = search; query.category = category == .movies ? "movie" : category == .shows ? "show" : category == .anime ? "anime" : "all"
        query.status = status == "queue" ? "all" : status; query.queued = status == "queue"; query.genre = genre
        query.disk = drive.isEmpty ? "all" : ["mapped", "unmapped"].contains(drive) || drive.hasPrefix("[") || drive.hasPrefix("drive:") ? drive : "drive:" + drive.uppercased()
        query.sort = sort == "name" ? .title : sort == "rating" ? .score : sort == "year" ? .year : .library
        return query.titles(in: store.workspace) { store.publicScore($0, source: ratingSource) }
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
            PageHeader(name: "Glance", count: "\(store.workspace.activeTitles.filter { $0.status == "watching" }.count) watching", onSearch: { showSearch.toggle(); if !showSearch { search = "" } })
            if showSearch { SearchField(placeholder: "Find a current watch…", text: $search, label: "Find a current watch", autoFocus: true).padding(.horizontal, 14).padding(.bottom, 10) }
            CategoryPicker(selection: $category)
            ScrollView {
                LazyVStack(spacing: 8) { ForEach(titles) { ProgressCard(title: $0) } }.padding(.horizontal, 8).padding(.top, 12).padding(.bottom, 16)
                if titles.isEmpty { ContentUnavailableView("A clear little corner", systemImage: "eye", description: Text("No current watches match these filters. Try another category or clear your search.")) }
            }.refreshable { await store.refresh() }
        }
    }
    private var titles: [MediaTitle] { store.workspace.activeTitles.filter { $0.status == "watching" && category.includes($0) && (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search)) } }
}

struct TrashView: View {
    var body: some View {
        LibraryView(archived: true).navigationBarBackButtonHidden().toolbar(.hidden, for: .navigationBar)
    }
}
