import SwiftUI
import TwilDiaryCore

struct CatalogGrid: View {
    let items: [CatalogItem]
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12, alignment: .top), count: 3), alignment: .leading, spacing: 20) {
            ForEach(items, id: \.displayKey) { item in
                Group {
                    if let saved = item.inLibraryId { NavigationLink(value: saved) { CatalogPoster(item: item) } }
                    else { NavigationLink(value: item.route) { CatalogPoster(item: item) } }
                }.buttonStyle(.plain).accessibilityIdentifier("catalog-" + item.displayKey)
            }
        }
    }
}

struct CatalogPoster: View {
    let item: CatalogItem
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Artwork(path: item.artwork, title: item.name)
                .aspectRatio(2 / 3, contentMode: .fit)
                .overlay(alignment: .bottomLeading) {
                    if let score = item.rating, score > 0 {
                        HStack(spacing: 5) { Image(systemName: "star.fill").font(.system(size: 13)); Text(String(format: "%.1f", score)).frame(height: 18) }
                            .font(.system(size: 12)).foregroundStyle(Color(webHex: "#e7ca90"))
                            .padding(.horizontal, 5).padding(.vertical, 3).background(.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 6)).padding(6)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Text(item.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(.primary).lineLimit(1).frame(minHeight: 20.25).padding(.top, 8)
            Text((item.year.map(String.init) ?? "Year unknown") + (item.inLibraryId == nil ? "" : " · In your library")).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1).frame(height: 18).padding(.top, 4)
        }.accessibilityElement(children: .combine)
    }
}

struct CatalogSearchView: View {
    var onLibraryChoose: ((String) -> Void)? = nil
    var allowsManual = true
    var onClose: (() -> Void)? = nil
    @Environment(DiaryStore.self) private var store
    @Environment(AppRouter.self) private var router
    @State private var query = ""
    @State private var identified: [SearchLibraryTitle] = []
    @State private var results: [CatalogItem] = []
    @State private var loading = false
    @State private var failure: String?
    @State private var showManual = false
    @State private var page = 1
    @State private var totalPages = 0
    @State private var libraryLimit = 20
    @State private var generation = UUID()
    @State private var pageTask: Task<Void, Never>?
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 4) {
                SearchField(placeholder: "Title or IMDb ID…", text: $query, label: "Search library and online", autoFocus: true)
                if let onClose { Button(action: onClose) { DiaryIcon(name: "x", size: 18).frame(width: 44, height: 44) }.buttonStyle(.plain).accessibilityLabel("Close search") }
            }
            if !ready { Text("Find a title, or paste an IMDb ID.").font(.system(size: 14)).foregroundStyle(.secondary) }
            else {
                Text("In Library · \(localMatches.count)").font(.system(size: 15, weight: .semibold))
                ForEach(localMatches.prefix(libraryLimit)) { title in
                    Button { chooseLibrary(title.id) } label: { searchRow(title) }.buttonStyle(.plain)
                        .accessibilityIdentifier((onLibraryChoose == nil ? "search-library-" : "match-title-") + title.id)
                }
                if localMatches.count > libraryLimit { Button("More library matches") { libraryLimit += 20 }.font(.system(size: 13)).frame(minHeight: 44) }
                if localMatches.isEmpty { Text("No library matches").font(.system(size: 13)).foregroundStyle(.secondary) }
                Text("Not In Library · TMDB").font(.system(size: 15, weight: .semibold))
                if loading { ProgressView("Searching…") }
                if let failure { HStack { Text(failure).font(.system(size: 13)).foregroundStyle(.secondary); Spacer(minLength: 0); Button("Retry") { requestPage(page) }.font(.system(size: 13)) } }
                ForEach(results, id: \.key) { item in
                    NavigationLink(value: item.route) {
                        HStack(spacing: 12) {
                            Artwork(path: item.artwork, title: item.name).frame(width: 72, height: 108).clipShape(RoundedRectangle(cornerRadius: 8))
                            VStack(alignment: .leading, spacing: 4) { Text(item.name).font(.system(size: 15, weight: .semibold)); Text([item.year.map(String.init), item.mediaType == .tv ? "Show" : "Movie"].compactMap { $0 }.joined(separator: " · ")).font(.system(size: 13)).foregroundStyle(.secondary) }
                            Spacer(minLength: 0); DiaryIcon(name: "arrow-up-right", size: 18).foregroundStyle(.tint)
                        }.padding(.vertical, 9).foregroundStyle(.primary)
                    }.buttonStyle(.plain).accessibilityIdentifier("search-" + item.key)
                }
                if !loading && results.isEmpty && failure == nil { Text("No online matches").font(.system(size: 13)).foregroundStyle(.secondary) }
                if totalPages > 1 {
                    HStack { Button("Previous") { requestPage(page - 1) }.disabled(page <= 1 || loading); Spacer(); Text("Page \(page) of \(totalPages)").font(.system(size: 13)).foregroundStyle(.secondary); Spacer(); Button("Next") { requestPage(page + 1) }.disabled(page >= min(500, totalPages) || loading) }.font(.system(size: 13))
                }
            }
            if allowsManual { Button("Add manually") { showManual = true }.font(.system(size: 14, weight: .semibold)).frame(minHeight: 44) }
        }.padding(.horizontal, 14).padding(.bottom, 12)
            .task(id: normalized) { await search(number: 1, reset: true) }
            .onDisappear { pageTask?.cancel(); generation = UUID() }
            .sheet(isPresented: $showManual) { ManualTitleView(initialName: normalized) }
    }
    private var normalized: String { DiarySearchTools.normalize(query) }
    private var ready: Bool { DiarySearchTools.ready(normalized) }
    private var localMatches: [SearchLibraryTitle] { DiarySearchTools.merging(DiarySearchTools.matches(store.workspace, query: normalized), identified) }
    private func searchRow(_ title: SearchLibraryTitle) -> some View {
        HStack(spacing: 12) {
            Artwork(path: title.artwork, title: title.name).frame(width: 72, height: 108).clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 4) { Text(title.name).font(.system(size: 15, weight: .semibold)); Text([title.year.map(String.init), title.category == "anime-movie" ? "Anime movie" : title.category.capitalized].compactMap { $0 }.joined(separator: " · ")).font(.system(size: 13)).foregroundStyle(.secondary) }
            Spacer(minLength: 0); DiaryIcon(name: "arrow-up-right", size: 18).foregroundStyle(.tint)
        }.padding(.vertical, 9).foregroundStyle(.primary)
    }
    private func chooseLibrary(_ id: String) {
        Task {
            if store.title(id) == nil { await store.refresh() }
            guard store.title(id) != nil else { failure = "This title is no longer available. Refresh your library and try again."; return }
            if let onLibraryChoose { onLibraryChoose(id) }
            else { onClose?(); router.openTitle(id, tab: router.selectedTab) }
        }
    }
    private func requestPage(_ number: Int) { pageTask?.cancel(); pageTask = Task { await search(number: number) } }
    private func search(number: Int, reset: Bool = false) async {
        let request = UUID(); generation = request
        if reset { results = []; identified = []; page = 1; totalPages = 0; libraryLimit = 20 }
        failure = nil
        guard ready else { loading = false; return }
        let value = normalized; loading = true
        defer { if generation == request { loading = false } }
        do {
            if reset { try await Task.sleep(for: .milliseconds(300)) }
            let response = try await store.searchDiary(value, page: number)
            guard !Task.isCancelled, request == generation, normalized == value else { return }
            guard response.page == number else { throw APIError.message("Search returned an unexpected page. Please retry.") }
            identified = DiarySearchTools.merging(identified, response.library)
            results = response.online; page = response.page; totalPages = response.totalPages
            failure = response.onlineError.isEmpty ? nil : response.onlineError
        } catch is CancellationError { }
        catch { if !Task.isCancelled, request == generation { failure = error.localizedDescription } }
    }
}

struct CatalogDetailView: View {
    let route: CatalogRoute
    var onImported: ((String) -> Void)? = nil
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
                            if let title = store.title(saved.id) { Button("Restore to Library") { Task { if await store.restore(title) { accepted(title.id) } } }.buttonStyle(.borderedProminent).disabled(store.busy) }
                        } else if let onImported { Button("Use this title") { onImported(saved.id) }.buttonStyle(.borderedProminent) }
                        else { NavigationLink(value: saved.id) { Text("Open in Library →").font(.headline) } }
                    }
                    CatalogHero(details: details.details)
                    Text(details.details.overview).font(.subheadline).foregroundStyle(.secondary).lineSpacing(3)
                    if details.libraryTitle == nil {
                        VStack(alignment: .leading, spacing: 16) {
                            Picker("Category", selection: $category) {
                                if details.details.mediaType == .movie { Text("Movie").tag("movie"); Text("Anime movie").tag("anime-movie") }
                                else { Text("Show").tag("show"); Text("Anime").tag("anime") }
                            }.pickerStyle(.menu)
                            Button { Task { if let id = await store.importTitle(details.details, category: category) { accepted(id) } } } label: { Label(store.busy ? "Adding…" : "Add to Planned", systemImage: "plus").font(.subheadline.bold()).frame(maxWidth: .infinity).padding(.vertical, 7) }.buttonStyle(.borderedProminent).disabled(store.busy || store.isPreview)
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
    private func accepted(_ id: String) { if let onImported { onImported(id) } else { importedID = id } }
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
