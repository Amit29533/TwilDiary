import SwiftUI
import TwilDiaryCore

struct ExploreView: View {
    @Environment(DiaryStore.self) private var store
    @State private var kind = MediaKind.tv
    @State private var sort = "rating"
    @State private var items: [CatalogItem] = []
    @State private var page = 0
    @State private var totalPages = 1
    @State private var loading = false
    @State private var failure: String?
    @State private var showSearch = false
    var body: some View {
        VStack(spacing: 0) {
            PageHeader(name: "Explore", onSearch: { showSearch.toggle() })
            if showSearch { CatalogSearchView() }
            HStack {
                Picker("Media type", selection: $kind) { ForEach(MediaKind.allCases, id: \.self) { Text($0.label).tag($0) } }.pickerStyle(.segmented)
                Picker("Sort", selection: $sort) { Text("Highest rated").tag("rating"); Text("Popular").tag("popular"); Text("Newest").tag("newest") }.pickerStyle(.menu).fixedSize()
            }.padding(.horizontal, 14).padding(.bottom, 12)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let failure { RetryNotice(message: failure) { Task { await load(reset: true) } } }
                    if loading && items.isEmpty { ProgressView("Loading titles…").frame(maxWidth: .infinity).padding(30) }
                    CatalogGrid(items: items)
                    if !loading && items.isEmpty && failure == nil { ContentUnavailableView("No titles found", systemImage: "sparkles", description: Text("Change your filters and try again.")) }
                    if page < totalPages && !items.isEmpty { Button(loading ? "Loading…" : "Load more") { Task { await load(reset: false) } }.buttonStyle(.bordered).disabled(loading).frame(maxWidth: .infinity) }
                }.padding(.horizontal, 14).padding(.bottom, 24)
            }.refreshable { await load(reset: true) }
        }.background(.black).toolbar(.hidden, for: .navigationBar)
            .task(id: kind.rawValue + sort) { await load(reset: true) }
    }
    private func load(reset: Bool) async {
        if reset { items = []; page = 0 }
        loading = true; failure = nil
        defer { loading = false }
        do {
            let result = try await store.discover(kind, sort: sort, page: reset ? 1 : page + 1)
            guard !Task.isCancelled else { return }
            items = reset ? result.items : CatalogTools.merging(items, result.items)
            page = result.page; totalPages = result.totalPages
        } catch { if !Task.isCancelled { failure = error.localizedDescription } }
    }
}

struct CatalogGrid: View {
    let items: [CatalogItem]
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12, alignment: .top), count: 3), alignment: .leading, spacing: 20) {
            ForEach(items, id: \.key) { item in
                Group {
                    if let saved = item.inLibraryId { NavigationLink(value: saved) { CatalogPoster(item: item) } }
                    else { NavigationLink(value: item.route) { CatalogPoster(item: item) } }
                }.buttonStyle(.plain).accessibilityIdentifier("catalog-" + item.key)
            }
        }
    }
}

struct CatalogPoster: View {
    let item: CatalogItem
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Artwork(path: CatalogTools.image(item.posterPath), title: item.name)
                .aspectRatio(2 / 3, contentMode: .fit)
                .overlay(alignment: .topLeading) { if let score = item.rating, score > 0 { RatingBadge(score: score).padding(6) } }
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Text(item.name).font(.system(size: 13, weight: .semibold)).foregroundStyle(.primary).lineLimit(2)
            if let year = item.year { Text(String(year)).font(.caption).foregroundStyle(.secondary) }
        }.accessibilityElement(children: .combine)
    }
}

struct CatalogSearchView: View {
    @Environment(DiaryStore.self) private var store
    @State private var query = ""
    @State private var results: [CatalogItem] = []
    @State private var loading = false
    @State private var failure: String?
    @State private var showManual = false
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SearchField(placeholder: "Title or IMDb ID…", text: $query, label: "Search library and online")
            if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("In Library").font(.subheadline.bold())
                ForEach(localMatches.prefix(8)) { title in NavigationLink(value: title.id) { titleRow(title) }.buttonStyle(.plain) }
                if localMatches.isEmpty { Text("No library matches").font(.caption).foregroundStyle(.secondary) }
                Text("Not In Library · TMDB").font(.subheadline.bold())
                if loading { ProgressView("Searching…") }
                if let failure { Text(failure).font(.caption).foregroundStyle(.secondary) }
                ForEach(results.filter { $0.inLibraryId == nil }, id: \.key) { item in
                    NavigationLink(value: item.route) {
                        HStack(spacing: 10) {
                            Artwork(path: CatalogTools.image(item.posterPath), title: item.name).frame(width: 40, height: 60).clipShape(RoundedRectangle(cornerRadius: 6))
                            VStack(alignment: .leading, spacing: 4) { Text(item.name).font(.subheadline.bold()); Text([item.year.map(String.init), item.mediaType == .tv ? "Show" : "Movie"].compactMap { $0 }.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary) }
                            Spacer(); Image(systemName: "chevron.right").font(.caption)
                        }.foregroundStyle(.primary)
                    }.buttonStyle(.plain).accessibilityIdentifier("search-" + item.key)
                }
                if !loading && results.isEmpty && failure == nil { Text("No online matches").font(.caption).foregroundStyle(.secondary) }
            }
            Button("Add manually") { showManual = true }.font(.subheadline.weight(.semibold))
        }.padding(14).background(Color(white: 0.06), in: RoundedRectangle(cornerRadius: 16)).padding(.horizontal, 14).padding(.bottom, 12)
            .task(id: query) { await search() }
            .sheet(isPresented: $showManual) { ManualTitleView(initialName: query) }
    }
    private var localMatches: [MediaTitle] { store.workspace.activeTitles.filter { $0.name.localizedCaseInsensitiveContains(query.trimmingCharacters(in: .whitespacesAndNewlines)) } }
    private func search() async {
        let value = query.trimmingCharacters(in: .whitespacesAndNewlines)
        results = []; failure = nil
        guard value.count >= 2 else { loading = false; return }
        loading = true
        do {
            try await Task.sleep(for: .milliseconds(250))
            let response = try await store.searchCatalog(value)
            guard !Task.isCancelled else { return }
            results = response.items; loading = false
        } catch { if !Task.isCancelled { failure = error.localizedDescription; loading = false } }
    }
}

struct CatalogDetailView: View {
    let route: CatalogRoute
    @Environment(DiaryStore.self) private var store
    @State private var details: CatalogBrowse?
    @State private var failure: String?
    @State private var loading = false
    @State private var category = "show"
    @State private var importedID: String?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let details {
                    if let saved = details.libraryTitle {
                        if saved.trashed {
                            Text("This title is in Trash").font(.title2.bold())
                            if let title = store.title(saved.id) { Button("Restore to Library") { Task { if await store.restore(title) { importedID = title.id } } }.buttonStyle(.borderedProminent).disabled(store.busy) }
                        } else { NavigationLink(value: saved.id) { Text("Open in Library →").font(.headline) } }
                    }
                    CatalogHero(details: details.details)
                    Text(details.details.overview).font(.subheadline).foregroundStyle(.secondary).lineSpacing(3)
                    if details.libraryTitle == nil {
                        VStack(alignment: .leading, spacing: 16) {
                            Picker("Category", selection: $category) { Text("Movie").tag("movie"); Text("Show").tag("show"); Text("Anime").tag("anime"); Text("Anime movie").tag("anime-movie") }.pickerStyle(.menu)
                            Button { Task { importedID = await store.importTitle(details.details, category: category) } } label: { Label(store.busy ? "Adding…" : "Add to Planned", systemImage: "plus").font(.subheadline.bold()).frame(maxWidth: .infinity).padding(.vertical, 7) }.buttonStyle(.borderedProminent).disabled(store.busy || store.isPreview)
                        }.diaryPanel()
                    }
                    CastAndRelated(route: route)
                } else if loading { ProgressView("Loading title…").frame(maxWidth: .infinity).padding(40) }
                if let failure { RetryNotice(message: failure) { Task { await load() } } }
            }.padding(.horizontal, 14).padding(.bottom, 30)
        }.background(.black).navigationTitle("Title").navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar)
            .task { await load() }
            .navigationDestination(item: $importedID) { TitleDetailView(id: $0) }
    }
    private func load() async {
        loading = true; failure = nil; defer { loading = false }
        do { let response = try await store.browse(route); guard !Task.isCancelled else { return }; details = response; category = response.details.suggestedCategory }
        catch { if !Task.isCancelled { failure = error.localizedDescription } }
    }
}

private struct CatalogHero: View {
    let details: CatalogDetails
    var body: some View {
        HStack(alignment: .bottom, spacing: 14) {
            Artwork(path: CatalogTools.image(details.posterPath), title: details.name).frame(width: 114, height: 171).clipShape(RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 12) {
                Text(details.name).font(.system(size: 23, weight: .bold)).tracking(-0.6)
                Text([details.year.map(String.init), details.suggestedCategory.capitalized, details.runtimeMinutes.map { "\($0) min" }].compactMap { $0 }.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary)
                if let score = details.communityScore { RatingBadge(score: score) }
            }
        }.padding(.top, 35)
    }
}

struct CastAndRelated: View {
    let route: CatalogRoute
    @Environment(DiaryStore.self) private var store
    @State private var cast: [CastPerson] = []
    @State private var related: [CatalogItem] = []
    @State private var failure: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if !cast.isEmpty {
                Text("Cast").font(.system(size: 20, weight: .semibold))
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 18) {
                        ForEach(cast) { person in
                            NavigationLink(value: PersonRoute(id: person.id)) {
                                VStack(spacing: 8) {
                                    Artwork(path: CatalogTools.image(person.profilePath, size: "w185"), title: person.name).frame(width: 82, height: 82).clipShape(Circle())
                                    Text(person.name).font(.system(size: 13, weight: .semibold)).lineLimit(2)
                                    Text(person.character).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                                }.frame(width: 100).multilineTextAlignment(.center).foregroundStyle(.primary)
                            }.buttonStyle(.plain)
                        }
                    }
                }.scrollIndicators(.hidden)
            }
            if !related.isEmpty { Text("You might like").font(.system(size: 20, weight: .semibold)); CatalogGrid(items: Array(related.prefix(6))) }
            if let failure { RetryNotice(message: failure) { Task { await load() } } }
        }.task(id: route) { await load() }
    }
    private func load() async {
        failure = nil
        do { cast = try await store.cast(route).cast } catch { if !Task.isCancelled { failure = error.localizedDescription } }
        do { related = try await store.related(route).items } catch { if !Task.isCancelled { failure = error.localizedDescription } }
    }
}

struct PersonView: View {
    let id: Int
    @Environment(DiaryStore.self) private var store
    @State private var person: PersonDetails?
    @State private var failure: String?
    @State private var kind = MediaKind.tv
    @State private var query = ""
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let person {
                    HStack(alignment: .bottom, spacing: 16) {
                        Artwork(path: CatalogTools.image(person.profilePath), title: person.name).frame(width: 114, height: 171).clipShape(RoundedRectangle(cornerRadius: 12))
                        VStack(alignment: .leading, spacing: 8) { Text(person.name).font(.title2.bold()); Text(person.department).font(.subheadline).foregroundStyle(.secondary); Text(person.birthplace).font(.caption).foregroundStyle(.secondary) }
                    }
                    if !person.biography.isEmpty { DisclosureGroup("Biography") { Text(person.biography).font(.subheadline).foregroundStyle(.secondary).padding(.top, 10) } }
                    Text("Filmography").font(.title3.bold())
                    Picker("Filmography", selection: $kind) { ForEach(MediaKind.allCases, id: \.self) { Text($0.label).tag($0) } }.pickerStyle(.segmented)
                    SearchField(placeholder: "Search filmography…", text: $query, label: "Search filmography")
                    CatalogGrid(items: person.filmography(kind, query: query))
                } else if failure == nil { ProgressView("Loading cast profile…").frame(maxWidth: .infinity).padding(40) }
                if let failure { RetryNotice(message: failure) { Task { await load() } } }
            }.padding(14)
        }.background(.black).navigationTitle(person?.name ?? "Cast").navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar).task { await load() }
    }
    private func load() async { failure = nil; do { person = try await store.person(id).person } catch { failure = error.localizedDescription } }
}

struct ManualTitleView: View {
    var initialName = ""
    @Environment(DiaryStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var category = "movie"
    @State private var year = ""
    @State private var failure: String?
    @State private var identity = UUID().uuidString
    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $name)
                Picker("Category", selection: $category) { Text("Movie").tag("movie"); Text("Show").tag("show"); Text("Anime").tag("anime"); Text("Anime movie").tag("anime-movie") }
                TextField("Year (optional)", text: $year).keyboardType(.numberPad)
                if let failure { Text(failure).font(.caption).foregroundStyle(.red) }
                Button("Add to Planned") { Task { await save() } }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.busy || store.isPreview)
            }.navigationTitle("Add manually").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
                .onAppear { name = initialName }
        }
    }
    private func save() async {
        let number = Int(year)
        guard year.isEmpty || (number.map { (1880...2200).contains($0) } ?? false) else { failure = "Enter a year from 1880 to 2200."; return }
        guard !store.busy else { return }; store.busy = true; defer { store.busy = false }
        do {
            let _: EmptyResponse = try await store.read("/api/titles", method: "POST", body: ["id": identity, "name": name.trimmingCharacters(in: .whitespacesAndNewlines), "category": category, "year": number as Any? ?? NSNull(), "status": "planned"])
            try await store.reload(); dismiss()
        } catch { failure = error.localizedDescription }
    }
}

struct RetryNotice: View {
    let message: String
    let retry: () -> Void
    var body: some View { VStack(alignment: .leading, spacing: 10) { Text(message).font(.subheadline).foregroundStyle(.secondary); Button("Retry", action: retry).buttonStyle(.bordered) }.frame(maxWidth: .infinity, alignment: .leading).diaryPanel() }
}
