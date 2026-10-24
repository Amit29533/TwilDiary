import SwiftUI
import TwilDiaryCore
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(DiaryStore.self) private var store
    @AppStorage("theme") private var theme = DiaryTheme.twilight
    @AppStorage("publicRatingSource") private var ratingSource = PublicRatingSource.tmdb
    @AppStorage("hideSpoilers") private var hideSpoilers = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showSearch = false
    @State private var confirmSignOut = false
    @State private var summary: TraktController?
    @State private var showExport = false
    @State private var exportDocument = DiaryJSONDocument(data: Data())
    var body: some View {
        VStack(spacing: 0) {
            PageHeader(name: "More", onSearch: { showSearch.toggle() })
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if showSearch { CatalogSearchView(onClose: { showSearch = false }).padding(.horizontal, -14) }
                    traktSummary
                    settingsSection("Library") {
                        HStack(spacing: 8) { settingsIcon("star"); VStack(alignment: .leading, spacing: 3) { Text("Library ratings").font(.subheadline.weight(.semibold)); Text("Community scores, not your rating").font(.caption).foregroundStyle(.secondary) }; Spacer(minLength: 0); Picker("Library ratings", selection: $ratingSource) { ForEach(PublicRatingSource.allCases) { Text($0.label).tag($0) } }.pickerStyle(.menu).font(.caption).fixedSize().accessibilityIdentifier("settings-rating-source") }.padding(14)
                        Divider().padding(.leading, 58)
                        NavigationLink { FilesView() } label: { settingsRow("hard-drive", "Files & drives", subtitle: "Folders, seasons and local copies", disclosure: true) }.accessibilityIdentifier("settings-files")
                        Divider().padding(.leading, 58)
                        NavigationLink { TrashView() } label: { settingsRow("trash-2", "Trash", subtitle: store.workspace.titles.contains(where: { $0.deletedAt != nil }) ? "\(store.workspace.titles.filter { $0.deletedAt != nil }.count) removed titles" : "No removed titles", disclosure: true) }
                    }
                    settingsSection("Tracking") {
                        HStack(spacing: 8) { settingsIcon("eye-off"); Toggle(isOn: $hideSpoilers) { VStack(alignment: .leading, spacing: 3) { Text("Hide episode spoilers").font(.subheadline.weight(.semibold)); Text("Hide unwatched titles, summaries and images").font(.caption).foregroundStyle(.secondary) } }.tint(theme.accent) }.padding(14)
                        Divider().padding(.leading, 58)
                        NavigationLink { HistoryView() } label: { settingsRow("history", "Watch history", subtitle: "Recently watched, dates and filters", disclosure: true) }
                        Divider().padding(.leading, 58)
                        settingsRow("star", "Rating scale", value: "10 · decimals")
                    }
                    settingsSection("Appearance & region") {
                        NavigationLink { AppearanceView() } label: { settingsRow("palette", "Theme", value: theme.name, disclosure: true) }.accessibilityIdentifier("settings-theme")
                        Divider().padding(.leading, 58)
                        settingsRow("activity", "Reduce motion", value: reduceMotion ? "Reduced · device" : "Follow device")
                        Divider().padding(.leading, 58)
                        settingsRow("globe", "Time zone", subtitle: "Uses your device for dates and stats", value: TimeZone.current.identifier.replacingOccurrences(of: "_", with: " "))
                        Divider().padding(.leading, 58)
                        settingsRow("calendar-days", "Week starts on", value: "Monday")
                    }
                    settingsSection("Connections") {
                        NavigationLink { TMDBConnectionView() } label: { settingsRow("database", "TMDB", subtitle: "Posters, details, seasons and episodes", disclosure: true) }
                        Divider().padding(.leading, 58)
                        NavigationLink { TraktView(store: store) } label: { settingsRow("link-2", "Trakt", subtitle: "History, ratings and watchlist", value: summary?.status?.connected == true ? "Connected" : "Set up", disclosure: true) }.accessibilityIdentifier("settings-trakt")
                    }
                    settingsSection("Data & backup") {
                        Button { exportDiary() } label: { settingsRow("download", "Export diary", subtitle: "Titles, progress, notes and file mappings", disclosure: true) }
                        Divider().padding(.leading, 58)
                        settingsRow("shield-check", "Diary storage", subtitle: "Your diary is saved to your workspace", value: store.busy ? "Saving…" : store.showingCachedSnapshot ? "Saved copy" : "Ready")
                    }
                    settingsSection("About") {
                        NavigationLink { AboutView() } label: { settingsRow("info", "About TwilDiary", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "2.0.0", disclosure: true) }
                        Divider().padding(.leading, 58)
                        NavigationLink { AboutView() } label: { settingsRow("shield-check", "Attribution & licenses", disclosure: true) }
                    }
                    Text("This product uses the TMDB API but is not endorsed or certified by TMDB.").font(.caption).foregroundStyle(.secondary).padding(.horizontal, 4)
                    Button("Sign out", role: .destructive) { confirmSignOut = true }.font(.subheadline).frame(maxWidth: .infinity, alignment: .leading).frame(minHeight: 44).disabled(store.busy)
                }.buttonStyle(.plain).padding(.horizontal, 14).padding(.bottom, 24)
            }.refreshable { await summary?.refresh() }
        }.confirmationDialog("Sign out on this device? Your hosted diary stays saved.", isPresented: $confirmSignOut, titleVisibility: .visible) { Button("Sign out", role: .destructive) { store.signOut() } }
            .task { if summary == nil { summary = TraktController(service: makeTraktService(store: store)) }; await summary?.refresh() }
            .fileExporter(isPresented: $showExport, document: exportDocument, contentType: .json, defaultFilename: "TwilDiary-\(DiaryDate.day(store.now))") { result in if case .failure(let error) = result { store.error = error.localizedDescription } }
    }
    private var traktSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Text("Trakt sync").font(.caption.bold()); Spacer(); Text(summary?.error != nil ? "Unavailable" : (summary?.sync?.pendingChanges ?? 0) > 0 ? "Needs review" : summary?.status?.connected == true ? "Connected" : "Not connected").font(.caption2.bold()).foregroundStyle((summary?.sync?.pendingChanges ?? 0) > 0 ? Color.yellow : Color.secondary) }
            Text((summary?.sync?.pendingChanges ?? 0) > 0 ? "\(summary?.sync?.pendingChanges ?? 0) changes to review" : summary?.status?.connected == true ? "Keep your watches in sync" : "Bring your watch history together").font(.system(size: 20, weight: .semibold))
            Text("Scan Trakt to review incoming and outgoing changes before applying them.").font(.system(size: 13)).foregroundStyle(.secondary).lineSpacing(3)
            NavigationLink { TraktView(store: store) } label: { Text((summary?.sync?.pendingChanges ?? 0) > 0 ? "Review changes" : "Open Trakt sync").font(.system(size: 13, weight: .semibold)).padding(.horizontal, 16).frame(height: 42).foregroundStyle(Color(webHex: "#21182e")).background(theme.accent, in: RoundedRectangle(cornerRadius: 12)) }.accessibilityIdentifier("settings-trakt-summary")
        }.diaryPanel()
    }
    private func settingsSection<Content: View>(_ name: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 9) { Text(name).font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary).padding(.horizontal, 4); VStack(spacing: 0, content: content).background(Color(webHex: "#111115"), in: RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.08))) }
    }
    private func settingsIcon(_ icon: String) -> some View { DiaryIcon(name: icon, size: 18).foregroundStyle(theme.accent).frame(width: 34, height: 34).background(theme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 10)) }
    private func settingsRow(_ icon: String, _ title: String, subtitle: String? = nil, value: String? = nil, disclosure: Bool = false) -> some View {
        HStack(spacing: 10) { settingsIcon(icon); VStack(alignment: .leading, spacing: 3) { Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white); if let subtitle { Text(subtitle).font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) } }; Spacer(minLength: 4); if let value { Text(value).font(.system(size: 12)).foregroundStyle(.secondary).multilineTextAlignment(.trailing) }; if disclosure { DiaryIcon(name: "chevron-right", size: 14).foregroundStyle(.secondary) } }.padding(14).frame(minHeight: 58).contentShape(Rectangle())
    }
    private func exportDiary() { do { exportDocument = DiaryJSONDocument(data: try DiaryExport(workspace: store.workspace).encoded()); showExport = true } catch { store.error = error.localizedDescription } }
}

struct DiaryJSONDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

struct AppearanceView: View {
    @AppStorage("theme") private var theme = DiaryTheme.twilight
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ScrollView { VStack(spacing: 14) { ForEach(DiaryTheme.allCases) { item in
            Button { theme = item } label: {
                HStack(spacing: 16) { RoundedRectangle(cornerRadius: 16).fill(LinearGradient(colors: [item.accent.opacity(0.6), item.accent.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 70, height: 76).overlay { BrandMark().fill(item.accent).frame(width: 28, height: 28) }; VStack(alignment: .leading, spacing: 5) { Text(item.name).font(.headline); Text(item == .glass ? "Liquid accents on AMOLED black" : "AMOLED dark · \(item.name) accent").font(.caption).foregroundStyle(.secondary) }; Spacer(); if theme == item { Image(systemName: "checkmark.circle.fill").foregroundStyle(item.accent) } }.foregroundStyle(.white).diaryPanel()
            }.buttonStyle(.plain).accessibilityIdentifier("theme-" + item.rawValue).accessibilityAddTraits(theme == item ? .isSelected : [])
        } }.padding(16) }.background(.black).navigationTitle("Appearance").navigationBarBackButtonHidden().toolbar(.visible, for: .navigationBar).toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
    }
}

struct TMDBConnectionView: View {
    @Environment(DiaryStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var checking = false
    @State private var verified = false
    @State private var error: String?
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 18) {
            HStack { DiaryIcon(name: "key-round", size: 22).foregroundStyle(.tint); Text("TMDB").font(.title2.bold()); Spacer(); Text(verified ? "Connected" : checking ? "Checking…" : "Not connected").font(.caption).foregroundStyle(verified ? Color.green : Color.secondary) }
            Text("Posters, title details, seasons and episodes.").font(.subheadline).foregroundStyle(.secondary)
            Button(checking ? "Checking…" : "Check connection") { Task { await check() } }.buttonStyle(.bordered).disabled(checking)
            if let error { Text(error).font(.subheadline).foregroundStyle(.secondary) }
            Text("API credentials stay on your server. Use the PC app to configure or replace them.").font(.caption).foregroundStyle(.secondary)
        }.diaryPanel().padding(16) }.background(.black).navigationTitle("TMDB").navigationBarBackButtonHidden().toolbar(.visible, for: .navigationBar).toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }.task { await check() }
    }
    private func check() async { checking = true; error = nil; defer { checking = false }; do { if !store.isPreview { let _: EmptyResponse = try await store.read("/api/metadata/status") }; verified = true } catch { verified = false; self.error = error.localizedDescription } }
}

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 24) {
            VStack(spacing: 12) { BrandMark().fill(.tint).frame(width: 54, height: 54); Text("TwilDiary").font(.title.bold()); Text("Your stories, at your pace.").foregroundStyle(.secondary); Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "2.0.0") · Build \(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "")").font(.caption) }.frame(maxWidth: .infinity).diaryPanel()
            VStack(alignment: .leading, spacing: 16) { Text("Attribution & licenses").font(.title2.bold()); Text("Movie & television data").font(.headline); Text("This product uses the TMDB API but is not endorsed or certified by TMDB.").font(.subheadline).foregroundStyle(.secondary); Link("The Movie Database ↗", destination: URL(string: "https://www.themoviedb.org")!); Text("Trakt").font(.headline); Text("Trakt connects your watch history, ratings and watchlist when you authorize it. Scanning prepares a review before changes are applied.").font(.subheadline).foregroundStyle(.secondary); Link("Trakt ↗", destination: URL(string: "https://trakt.tv")!); Text("Icons").font(.headline); Text("Lucide icons are provided under the ISC license.").font(.subheadline).foregroundStyle(.secondary) }.diaryPanel()
            if let url = Bundle.main.url(forResource: "Lucide-LICENSE", withExtension: "txt"), let license = try? String(contentsOf: url, encoding: .utf8) { DisclosureGroup("Lucide ISC license") { Text(license).font(.caption).textSelection(.enabled).padding(.top, 12) }.diaryPanel() }
        }.padding(16) }.background(.black).navigationTitle("About").navigationBarBackButtonHidden().toolbar(.visible, for: .navigationBar).toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
    }
}
