import SwiftUI
import TwilDiaryCore

struct TitleDetailView: View {
    let id: String
    @Environment(DiaryStore.self) private var store
    @AppStorage("theme") private var theme = DiaryTheme.twilight
    @AppStorage("hideSpoilers") private var hideSpoilers = true
    @State private var chosenSeason: Int?
    @State private var initializedEditor = false
    @State private var configuredSeason: Int?
    @FocusState private var notesFocused: Bool
    @State private var showOverview = false
    @State private var showNotes = false
    @State private var showLocation = false
    @State private var notes = ""
    @State private var notesVersion: Int?
    @State private var ratingVersion: Int?
    @State private var rating = 7.0
    @State private var showRating = false
    @State private var resetConfirmation = false
    @State private var card: WatchCard?
    @State private var cardRequest = UUID()
    @State private var showAllEpisodes = false
    @State private var watchDate = Date.now
    @State private var showDate = false
    @State private var sliderDraft: Double?
    @State private var expandedEpisodes = Set<String>()
    @State private var revealedEpisodes: [String: RevealedEpisode] = [:]
    @State private var revealing = false
    @State private var episodeError: String?
    var body: some View {
        Group {
            if let title = store.title(id) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header(title)
                        progressPanel(title)
                        if title.isSeries { episodeSection(title) }
                        else { movieHistory(title) }
                        if let tmdbId = title.tmdbId { CastAndRelated(route: CatalogRoute(kind: title.isSeries ? .tv : .movie, id: tmdbId)) }
                        VStack(spacing: 20) {
                            DisclosureGroup("Notes", isExpanded: $showNotes) {
                                VStack(alignment: .leading, spacing: 12) {
                                    TextEditor(text: $notes).frame(minHeight: 110).scrollContentBackground(.hidden).focused($notesFocused).accessibilityIdentifier("title-notes").accessibilityLabel("Title notes")
                                    if notes.utf16.count > 20_000 { Text("Keep notes within 20,000 characters.").font(.caption).foregroundStyle(.orange) }
                                    Button("Save notes") { Task { if await store.patch(title, values: ["notes": notes], expectedVersion: notesVersion) { notesVersion = store.title(id)?.version } } }.disabled(store.busy || notes == title.notes || notes.utf16.count > 20_000)
                                }.padding(.top, 12)
                            }
                            Divider()
                            DisclosureGroup(isExpanded: $showLocation) { ForEach(locations) { location in
                                VStack(alignment: .leading, spacing: 7) { Text(location.evidence == "present" ? "Available · \(location.deviceName)" : location.evidence.capitalized).font(.subheadline.bold()); Text(location.path).font(.caption.monospaced()).textSelection(.enabled); Text("\(location.fileCount) files").font(.caption).foregroundStyle(.secondary) }.frame(maxWidth: .infinity, alignment: .leading).padding(.top, 12)
                            } } label: { Text(serverLabel).font(.subheadline.weight(.semibold)) }
                        }.diaryPanel()
                    }.padding(.horizontal, 16).padding(.bottom, 32)
                }.scrollDismissesKeyboard(.interactively).background(alignment: .top) {
                    Artwork(path: ["again", "night", "severance"].contains(title.id) ? "scene:" + title.id : title.backdrop ?? title.poster, title: title.name).frame(height: 310).overlay(LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)).ignoresSafeArea(edges: .top)
                }.background(.black)
                    .toolbar(.visible, for: .navigationBar).navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItemGroup(placement: .topBarTrailing) {
                            Button { Task { await store.patch(title, values: ["favorite": !title.favorite]) } } label: { Image(systemName: title.favorite ? "heart.fill" : "heart") }.accessibilityLabel("Favorite").disabled(store.busy)
                            Menu {
                                Button(title.queued == true ? "Remove from Queue" : "Add to Queue") { Task { await store.patch(title, values: ["queued": title.queued != true]) } }
                                Button("Notes") { showNotes = true }
                                Button("File locations") { showLocation = true }
                            } label: { Image(systemName: "ellipsis") }
                        }
                    }
                    .toolbar { ToolbarItemGroup(placement: .keyboard) { if notesFocused { Spacer(); Button("Done") { notesFocused = false }.accessibilityIdentifier("notes-keyboard-done") } } }
                    .task { if !initializedEditor { initializedEditor = true; watchDate = store.now; notes = title.notes; notesVersion = title.version; rating = title.score ?? 7 } }
                    .task(id: season) {
                        if configuredSeason != season { configuredSeason = season; sliderDraft = nil; showAllEpisodes = false }
                        if !hideSpoilers { await revealSeason(title) }
                    }
                    .task(id: cardRevision(title)) { await loadCard(title) }
                    .onChange(of: hideSpoilers) { _, hidden in if !hidden { Task { await revealSeason(title) } } }
                    .sheet(isPresented: $showRating) { ratingSheet(title) }
                    .confirmationDialog("Reset progress to 0? Logged watches will be removed, with Undo available.", isPresented: $resetConfirmation, titleVisibility: .visible) {
                        Button("Reset to Planned", role: .destructive) { Task { await store.setStatus(title, status: "planned"); await loadCard(title) } }
                    }
            } else { ContentUnavailableView("Title unavailable", systemImage: "film") }
        }
    }
    private func header(_ title: MediaTitle) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Artwork(path: title.poster, title: title.name).frame(width: 114, height: 171).clipShape(RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 12) {
                Text(title.name).font(.system(size: 24, weight: .bold)).tracking(-0.7).fixedSize(horizontal: false, vertical: true)
                Text([title.year.map(String.init), title.categoryName, title.runtimeMinutes.map { title.isSeries ? "\($0) min per episode" : "\($0) min" }].compactMap { $0 }.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) { communityRating(title); personalRating(title) }
                    VStack(alignment: .leading, spacing: 6) { communityRating(title); personalRating(title) }
                }.font(.system(size: 13))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title.overview.isEmpty ? "Add your own thoughts in Notes." : title.overview).font(.system(size: 14)).lineSpacing(4).foregroundStyle(Color(webHex: "#c5c0cf")).lineLimit(showOverview ? nil : 2)
                    if title.overview.count > 100 { Button(showOverview ? "Less" : "More") { showOverview.toggle() }.font(.system(size: 13, weight: .semibold)) }
                }
            }.padding(.top, 14)
        }.padding(.top, 82)
    }
    private func communityRating(_ title: MediaTitle) -> some View { HStack(spacing: 4) { Image(systemName: "star.fill").foregroundStyle(.yellow); Text(title.communityScore.map { $0.formatted(.number.precision(.fractionLength(1))) } ?? "—").foregroundStyle(.yellow); Text("TMDb").foregroundStyle(.secondary) } }
    private func personalRating(_ title: MediaTitle) -> some View { Button { openRating(title) } label: { HStack(spacing: 4) { Image(systemName: "star"); Text("Your rating").foregroundStyle(.secondary); Text(title.score.map { $0.formatted(.number.precision(.fractionLength(1))) } ?? "—") } }.buttonStyle(.plain) }
    private func progressPanel(_ title: MediaTitle) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Menu { ForEach(["planned", "watching", "completed", "dropped"], id: \.self) { status in
                    Button(status.capitalized) {
                        if status == "planned" && title.status != "planned" { resetConfirmation = true }
                        else { Task { await store.setStatus(title, status: status, watchedAt: watchInstant); await loadCard(title) } }
                    }
                } } label: { Label(title.status.capitalized, systemImage: "play.fill").font(.subheadline.bold()) }.buttonStyle(.bordered)
                Spacer(minLength: 0)
                if let minutes = remaining(title) { Text("\(DiaryDate.duration(minutes)) left").font(.caption).foregroundStyle(Color(white: 0.75)).shadow(color: .black, radius: 3) }
            }
            if let card {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(title.isSeries ? "Episode \(displayedWatched)" : "\(movieViewings.count)").font(.system(size: 20, weight: .bold))
                    Text(title.isSeries ? "of \(card.progress.total)" : movieViewings.count == 1 ? "view logged" : "views logged").font(.system(size: 15)).foregroundStyle(.secondary)
                    Spacer(minLength: 0); Text("\(displayedPercent)%").foregroundStyle(.tint).font(.system(size: 20, weight: .bold))
                }
                if title.isSeries {
                    episodeSlider(title, card: card)
                } else {
                    ProgressView(value: Double(percent), total: 100)
                        .accessibilityIdentifier("movie-progress")
                        .frame(height: 44)
                        .overlay {
                            Slider(value: Binding(get: { Double(percent) }, set: { value in
                                Task {
                                    if value < 50, let previous = card.previous { await store.removeLatest(title, expected: previous) }
                                    else if value >= 50, card.progress.watched == 0 { await store.recordViewing(title, watchedAt: watchInstant) }
                                    await loadCard(title)
                                }
                            }), in: 0...100, step: 100).opacity(0.02).disabled(store.busy || !store.canMutate).accessibilityLabel("Movie watched")
                        }
                }
                if let next = card.next, let episode = episodes.first(where: { $0.id == next.id }) { nextPreview(title, episode: episode) }
                else if title.isSeries { Text(seasonCanEdit(title) ? "You’re caught up with available episodes." : "Load the season to see what’s next.").font(.subheadline).foregroundStyle(.secondary) }
                Button { Task {
                    if title.isSeries, let next = card.next, let episode = episodes.first(where: { $0.id == next.id }) { await store.recordViewing(title, episode: episode, watchedAt: watchInstant) }
                    else if !title.isSeries { await store.recordViewing(title, rewatch: !movieViewings.isEmpty, watchedAt: watchInstant) }
                    await loadCard(title)
                } } label: {
                    Label(title.isSeries ? card.next.map { "Mark E\($0.number) watched" } ?? "Season caught up" : movieViewings.isEmpty ? "Log a watch" : "Log a rewatch", systemImage: !title.isSeries && !movieViewings.isEmpty ? "arrow.counterclockwise" : "checkmark")
                        .font(.system(size: 16, weight: .semibold)).frame(maxWidth: .infinity).frame(minHeight: 50)
                        .foregroundStyle(Color(webHex: "#21182e")).background(theme.accent, in: RoundedRectangle(cornerRadius: 14))
                }.buttonStyle(.plain).disabled(store.busy || (title.isSeries && card.next == nil)).accessibilityIdentifier("mark-title-watch")
                HStack {
                    Button { showDate.toggle() } label: { Label(DiaryDate.day(watchDate) == DiaryDate.day(store.now) ? "Watched today" : DiaryDate.day(watchDate), systemImage: "calendar") }.font(.caption).foregroundStyle(.secondary).accessibilityIdentifier("watch-date")
                    Spacer(minLength: 6); Button(title.isSeries ? "Rate show" : "Rate movie") { openRating(title) }.font(.caption.bold())
                }.frame(minHeight: 32)
                if showDate { DatePicker("Watch date", selection: $watchDate, in: ...store.now, displayedComponents: .date).datePickerStyle(.compact).font(.subheadline).frame(maxWidth: .infinity).clipped().disabled(store.busy); Text("Used for your next watch or progress update.").font(.caption).foregroundStyle(.secondary) }
                if let reviewed = card.previous { Button("Remove latest watch") { Task { await store.removeLatest(title, season: title.isSeries ? season : nil, expected: reviewed); await loadCard(title) } }.font(.caption).disabled(store.busy) }
            } else { ProgressView("Loading progress…") }
        }.diaryPanel()
    }
    private func episodeSlider(_ title: MediaTitle, card: WatchCard) -> some View {
        let states = sliderDraft.map { draft in (0..<max(0, card.progress.total)).map { $0 < Int(draft) ? EpisodeSegment.watched : .unwatched } }
            ?? EpisodeSegment.make(episodes: episodes, total: card.progress.total, watched: watched, nextID: card.next?.id)
        return ZStack {
            EpisodeProgressTrack(segments: states, season: season).accessibilityHidden(true)
            if !episodes.isEmpty {
                Slider(value: Binding(get: { sliderDraft ?? Double(card.progress.watched) }, set: { sliderDraft = $0 }), in: 0...Double(max(1, episodes.count)), step: 1) { editing in
                    if !editing, let count = sliderDraft {
                        Task { await store.setSeasonProgress(title, season: season, count: Int(count), watchedAt: watchInstant); sliderDraft = nil; await loadCard(title) }
                    }
                }.opacity(0.02).disabled(store.busy || !store.canMutate || !seasonCanEdit(title))
                    .accessibilityLabel("Season \(season) episodes watched").accessibilityValue("\(displayedWatched) of \(card.progress.total) episodes watched").accessibilityIdentifier("episode-progress")
            }
        }.frame(height: 44)
    }
    private func nextPreview(_ title: MediaTitle, episode: Episode) -> some View {
        Button { toggleEpisode(title, episode: episode) } label: {
            HStack(spacing: 12) {
                episodeArtwork(episode).frame(width: 104, height: 58).clipShape(RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 4) { Text("UP NEXT").font(.system(size: 10, weight: .bold)).foregroundStyle(theme.accent); Text("\(episode.number) · \(episodeName(episode))").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white).multilineTextAlignment(.leading) }
                Spacer(minLength: 0); if let runtime = title.runtimeMinutes { Text("\(runtime) min").font(.caption).foregroundStyle(.secondary) }
            }.padding(12).background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 16))
        }.buttonStyle(.plain).accessibilityLabel("Episode \(episode.number) details")
    }
    private func episodeSection(_ title: MediaTitle) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Text("Episodes").font(.title2.bold()); Spacer(); Picker("Season", selection: Binding(get: { season }, set: { chosenSeason = $0 })) { ForEach(title.seasons ?? [], id: \.number) { Text($0.name).tag($0.number) } }.pickerStyle(.menu) }
            Text("Season \(season) · \(card?.progress.watched ?? 0) / \(card?.progress.total ?? episodes.count) watched").font(.caption).foregroundStyle(.secondary)
            if !seasonCanEdit(title) { Button("Load season episodes") { Task { await store.loadSeason(title, number: season); await loadCard(title) } }.buttonStyle(.bordered).disabled(store.busy) }
            if revealing { ProgressView("Loading episode details…").font(.caption) }
            if let episodeError { Text(episodeError).font(.caption).foregroundStyle(.secondary); Button("Retry episode details") { Task { await revealSeason(title) } } }
            LazyVStack(spacing: 10) { ForEach(visibleEpisodes) { episode in episodeRow(title, episode: episode) } }
            if episodes.isEmpty { Text("No episode metadata yet").font(.subheadline).foregroundStyle(.secondary) }
            if episodes.count > 4 { Button(showAllEpisodes ? "Back to next episode" : "Show all \(episodes.count) episodes") { showAllEpisodes.toggle() }.frame(maxWidth: .infinity).frame(minHeight: 44) }
            if let pending = store.pendingSeasonAdjustments[title.id + ":" + String(season)] { Button("Retry progress to episode \(pending.count)") { Task { await store.setSeasonProgress(title, season: season, count: pending.count, watchedAt: watchInstant); await loadCard(title) } }.disabled(store.busy) }
        }
    }
    private func episodeRow(_ title: MediaTitle, episode: Episode) -> some View {
        let isWatched = watched.contains(episode.id), next = card?.next?.id == episode.id
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Button { toggleEpisode(title, episode: episode) } label: {
                    HStack(spacing: 12) {
                        episodeArtwork(episode).frame(width: 88, height: 53).clipShape(RoundedRectangle(cornerRadius: 10))
                        VStack(alignment: .leading, spacing: 4) { Text("\(episode.number) · \(episodeName(episode))").font(.subheadline).foregroundStyle(.white).multilineTextAlignment(.leading); Text(isWatched ? "Watched" : next ? "Up next" : hasAired(episode) ? "Not watched" : "Not aired yet").font(.caption).foregroundStyle(next ? theme.accent : Color.secondary) }
                        Spacer(minLength: 0)
                    }
                }.buttonStyle(.plain).accessibilityLabel("Episode \(episode.number) details")
                Button { Task { if isWatched { await store.unwatchEpisode(episode) } else { await store.recordViewing(title, episode: episode, watchedAt: watchInstant) }; await loadCard(title) } } label: { Image(systemName: isWatched ? "checkmark.circle.fill" : "circle").font(.system(size: 24)).foregroundStyle(isWatched ? theme.accent : Color.secondary).frame(width: 44, height: 44) }
                    .buttonStyle(.plain).disabled(store.busy || (!isWatched && !hasAired(episode))).accessibilityLabel("Mark episode \(episode.number) \(isWatched ? "unwatched" : "watched")")
            }
            if expandedEpisodes.contains(episode.id) { Text(episodeSummary(episode)).font(.subheadline).foregroundStyle(.secondary).padding(.horizontal, 4) }
        }.padding(8).background(next ? theme.accent.opacity(0.09) : .clear, in: RoundedRectangle(cornerRadius: 15))
    }
    @ViewBuilder private func episodeArtwork(_ episode: Episode) -> some View {
        if isHidden(episode) { Color(webHex: "#211d2d").overlay { DiaryIcon(name: "eye-off", size: 23).foregroundStyle(.secondary) } }
        else { Artwork(path: revealedEpisodes[episode.id]?.artwork ?? episode.still ?? store.title(id)?.backdrop, title: String(episode.number)) }
    }
    private func isHidden(_ episode: Episode) -> Bool { hideSpoilers && !watched.contains(episode.id) && !expandedEpisodes.contains(episode.id) }
    private func episodeName(_ episode: Episode) -> String {
        if isHidden(episode) { return "A story for later" }
        let name = revealedEpisodes[episode.id]?.name ?? episode.name
        return name.isEmpty ? "Episode \(episode.number)" : name
    }
    private func episodeSummary(_ episode: Episode) -> String { let text = revealedEpisodes[episode.id]?.overview ?? episode.overview; return text.isEmpty ? "No episode summary available." : text }
    private func hasAired(_ episode: Episode) -> Bool { episode.airedOn.map { SeasonAdjustment.validDay($0) && $0 <= DiaryDate.day(store.now) } ?? false }
    private func seasonCanEdit(_ title: MediaTitle) -> Bool {
        guard !episodes.isEmpty else { return false }
        guard let manifest = title.seasons?.first(where: { $0.number == season }) else { return title.tmdbId == nil }
        return manifest.expectedEpisodes.map { $0 == episodes.count } ?? (manifest.metadataLoadedAt != nil)
    }
    private func toggleEpisode(_ title: MediaTitle, episode: Episode) {
        if expandedEpisodes.contains(episode.id) { expandedEpisodes.remove(episode.id) }
        else { expandedEpisodes.insert(episode.id); if revealedEpisodes[episode.id] == nil { Task { await revealSeason(title) } } }
    }
    private func revealSeason(_ title: MediaTitle) async {
        guard !revealing else { return }
        let selected = season; revealing = true; episodeError = nil
        defer { revealing = false }
        do {
            let details = try await store.revealedSeason(title, number: selected)
            guard selected == season, !Task.isCancelled else { return }
            for episode in details { revealedEpisodes[episode.id] = episode }
        } catch is CancellationError { }
        catch { if selected == season { episodeError = error.localizedDescription } }
    }
    private var movieViewings: [WatchEvent] { store.workspace.activeEvents.filter { $0.titleId == id && $0.episodeId == nil }.sorted { ($0.recordedAt, $0.id) > ($1.recordedAt, $1.id) } }
    private func movieHistory(_ title: MediaTitle) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if !movieViewings.isEmpty { Text("Viewing history").font(.title2.bold()) }
            ForEach(movieViewings) { event in
                HStack { Image(systemName: "checkmark.circle.fill").foregroundStyle(theme.accent); Text(DiaryDate.parse(event.watchedAt).map { $0.formatted(date: .abbreviated, time: .omitted) } ?? "Unknown date").font(.subheadline); Spacer(); if event.id == card?.previous?.id { Text("Latest").font(.caption).foregroundStyle(.secondary) } }.padding(.vertical, 8)
            }
        }
    }
    private var displayedWatched: Int { sliderDraft.map(Int.init) ?? card?.progress.watched ?? 0 }
    private var watchInstant: Date { let calendar = DiaryDate.calendar(); return calendar.isDate(watchDate, inSameDayAs: store.now) ? store.now : calendar.date(bySettingHour: 12, minute: 0, second: 0, of: watchDate) ?? watchDate }
    private var displayedPercent: Int { guard let total = card?.progress.total, total > 0 else { return 0 }; return Int((Double(displayedWatched) / Double(total) * 100).rounded()) }
    private func ratingSheet(_ title: MediaTitle) -> some View {
        NavigationStack {
            Form {
                Section("Your rating") {
                    Stepper(value: $rating, in: 1...10, step: 0.5) {
                        Text(rating, format: .number.precision(.fractionLength(1)))
                    }
                    Button("Save rating") {
                        Task { if await store.patch(title, values: ["score": rating], expectedVersion: ratingVersion) { showRating = false } }
                    }
                    Button("Clear rating") {
                        Task { if await store.patch(title, values: ["score": NSNull()], expectedVersion: ratingVersion) { showRating = false } }
                    }
                }
            }
                .navigationTitle(title.isSeries ? "Rate show" : "Rate movie").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showRating = false } } }
        }.presentationDetents([.medium])
    }
    private func openRating(_ title: MediaTitle) { rating = title.score ?? 7; ratingVersion = title.version; showRating = true }
    private struct CardRevision: Hashable {
        let season: Int
        let events: [WatchEvent]
        let episodes: [Episode]
        let seasons: [Season]
    }
    private var season: Int { chosenSeason ?? EpisodeSelection.preferredSeason(in: store.workspace, titleID: id, today: DiaryDate.day(store.now)) }
    private func cardRevision(_ title: MediaTitle) -> CardRevision {
        CardRevision(season: season, events: store.workspace.events.filter { $0.titleId == id }, episodes: episodes, seasons: title.seasons ?? [])
    }
    private var episodes: [Episode] { store.workspace.episodes.filter { $0.titleId == id && $0.season == season }.sorted { $0.number < $1.number } }
    private var visibleEpisodes: [Episode] {
        EpisodeSelection.window(episodes, season: season, all: showAllEpisodes, nextID: card?.next?.id)
    }
    private var watched: Set<String> { Set(store.workspace.activeEvents.filter { $0.titleId == id }.compactMap(\.episodeId)) }
    private var locations: [FileLocation] { store.workspace.locations.filter { $0.titleId == id } }
    private var serverLabel: String { ServerAvailability.label(locations) }
    private var percent: Int { guard let card, card.progress.total > 0 else { return 0 }; return Int((Double(card.progress.watched) / Double(card.progress.total) * 100).rounded()) }
    private func remaining(_ title: MediaTitle) -> Int? { title.isSeries ? SeasonProgress.calculate(title: title, workspace: store.workspace, season: season).remainingMinutes : title.runtimeMinutes.map { card?.progress.watched == 1 ? 0 : $0 } }
    private func loadCard(_ title: MediaTitle) async {
        let request = UUID(), requestedSeason = season
        cardRequest = request
        do {
            let loaded = try await store.card(title, season: title.isSeries ? requestedSeason : nil)
            guard cardRequest == request, requestedSeason == season, !Task.isCancelled else { return }
            card = loaded
        } catch is CancellationError { }
        catch { if cardRequest == request, !Task.isCancelled { store.error = error.localizedDescription } }
    }
}
