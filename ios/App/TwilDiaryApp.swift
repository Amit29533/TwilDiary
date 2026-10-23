import SwiftUI
import UIKit
import TwilDiaryCore

@main struct TwilDiaryApp: App {
    @State private var store = DiaryStore()
    @State private var router = AppRouter()
    @AppStorage("theme") private var theme = DiaryTheme.twilight
    var body: some Scene {
        WindowGroup { RootView().environment(store).environment(router).preferredColorScheme(.dark).tint(theme.accent) }
    }
}

enum AppTab: String, CaseIterable, Hashable {
    case home, library, glance, stats, more
    var label: String { rawValue.capitalized }
    var icon: String {
        switch self { case .home: "house"; case .library: "library-big"; case .glance: "eye"; case .stats: "chart-no-axes-column-increasing"; case .more: "ellipsis" }
    }
}
enum AppDestination: Hashable { case explore, history, files, trash }

@MainActor @Observable final class AppRouter {
    var selectedTab = AppTab.glance
    var paths: [AppTab: NavigationPath] = [:]
    var libraryShortcut: String?
    var libraryRevision = 0
    var statsRevision = 0
    var detailTabs = Set<AppTab>()
    func library(_ shortcut: String) { libraryShortcut = shortcut; libraryRevision += 1; paths[.library] = NavigationPath(); selectedTab = .library }
    func statsToday() { statsRevision += 1; paths[.stats] = NavigationPath(); selectedTab = .stats }
    func files() { selectedTab = .more; paths[.more] = NavigationPath(); paths[.more, default: NavigationPath()].append(AppDestination.files) }
    func openTitle(_ id: String, tab: AppTab) { selectedTab = tab; paths[tab, default: NavigationPath()].append(id) }
}

struct RootView: View {
    @Environment(DiaryStore.self) private var store
    @Environment(AppRouter.self) private var router
    @State private var showSignIn = false
    @AppStorage("theme") private var theme = DiaryTheme.twilight
    var body: some View {
        Group {
            if store.needsSignIn {
                VStack(spacing: 22) {
                    BrandMark().fill(.tint).frame(width: 56, height: 56)
                    Text("TwilDiary").font(.largeTitle.bold())
                    Text("Your diary, now on iOS.").foregroundStyle(.secondary)
                    Button("Sign in to your diary") { showSignIn = true }.buttonStyle(.borderedProminent).controlSize(.large)
                    if let error = store.error { Text(error).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center) }
                }.padding(28).frame(maxWidth: .infinity, maxHeight: .infinity).background(.black)
                    .sheet(isPresented: $showSignIn) {
                        NavigationStack {
                            AccessSignIn { credential in showSignIn = false; Task { await store.connect(credential) } }
                                .navigationTitle("Private sign-in").navigationBarTitleDisplayMode(.inline)
                                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showSignIn = false } } }
                        }
                    }
            } else if !store.hasLoadedWorkspace {
                VStack(spacing: 22) {
                    BrandMark().fill(.tint).frame(width: 48, height: 48)
                    Text(store.loading ? "Opening your diary" : "Your diary is temporarily unavailable").font(.title2.bold())
                    if store.loading { ProgressView() }
                    else {
                        Text(store.error ?? "You’re signed in. Retry to load your diary.").foregroundStyle(.secondary).multilineTextAlignment(.center)
                        Button("Retry") { Task { await store.refresh() } }.buttonStyle(.borderedProminent).controlSize(.large)
                        Button("Sign out") { store.signOut() }.foregroundStyle(.secondary)
                    }
                }.padding(28).frame(maxWidth: .infinity, maxHeight: .infinity).background(.black)
            } else {
                ZStack {
                    ForEach(AppTab.allCases, id: \.self) { tab in
                        PersistentTab(selected: router.selectedTab == tab) { diaryStack(tab) { screen(tab) } }
                    }
                }
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        VStack(spacing: 8) {
                            if let label = store.undoLabel {
                                HStack { DiaryIcon(name: "check", size: 18).foregroundStyle(.mint); Text(label); Spacer(); Button("Undo") { Task { await store.undo() } }.disabled(store.busy) }
                                    .font(.system(size: 13, weight: .semibold)).padding(14).glassEffect(in: RoundedRectangle(cornerRadius: 18)).padding(.horizontal, 14)
                            }
                            if showNavigation { navigation.padding(.horizontal, 12).padding(.bottom, 10) }
                        }
                    }.overlay(alignment: .top) {
                        if let error = store.error {
                            HStack { Text(error).font(.caption); Button("Dismiss", systemImage: "xmark") { store.error = nil }.labelStyle(.iconOnly) }
                                .padding(12).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14)).padding()
                        }
                    }
            }
        }.task { await store.refresh() }
    }
    private var showNavigation: Bool { !router.detailTabs.contains(router.selectedTab) }
    private var navigation: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil); router.selectedTab = tab } label: {
                    VStack(spacing: 2) { DiaryIcon(name: tab.icon, size: 23); Text(tab.label).font(.system(size: 11)) }
                        .frame(maxWidth: .infinity).frame(height: 57)
                        .foregroundStyle(router.selectedTab == tab ? theme.accent : Color(webHex: "#a09aa9"))
                        .background(router.selectedTab == tab ? theme.accent.opacity(0.13) : .clear, in: Capsule())
                        .overlay(Capsule().strokeBorder(router.selectedTab == tab ? theme.accent.opacity(0.28) : .clear))
                }.buttonStyle(.plain).accessibilityLabel(tab.label).accessibilityIdentifier("tab-" + tab.rawValue).accessibilityAddTraits(router.selectedTab == tab ? .isSelected : [])
            }
        }.padding(4).background(.ultraThinMaterial, in: Capsule()).overlay(Capsule().strokeBorder(.white.opacity(0.16)))
    }
    @ViewBuilder private func screen(_ tab: AppTab) -> some View {
        switch tab { case .home: HomeView(); case .library: LibraryView(); case .glance: GlanceView(); case .stats: StatsView(); case .more: SettingsView() }
    }
    private func diaryStack<Content: View>(_ tab: AppTab, @ViewBuilder content: () -> Content) -> some View {
        NavigationStack(path: Binding(get: { router.paths[tab] ?? NavigationPath() }, set: { router.paths[tab] = $0 })) {
            content().background(tab == .library ? Color(webHex: "#0e0d13") : .black).toolbar(.hidden, for: .navigationBar).accessibilityHidden(router.selectedTab != tab).onAppear { router.detailTabs.remove(tab) }
                .navigationDestination(for: String.self) { TitleDetailView(id: $0).accessibilityHidden(router.selectedTab != tab).onAppear { router.detailTabs.insert(tab) } }
                .navigationDestination(for: CatalogRoute.self) { CatalogDetailView(route: $0).accessibilityHidden(router.selectedTab != tab).onAppear { router.detailTabs.insert(tab) } }
                .navigationDestination(for: PersonRoute.self) { PersonView(id: $0.id).accessibilityHidden(router.selectedTab != tab).onAppear { router.detailTabs.insert(tab) } }
                .navigationDestination(for: AppDestination.self) { destination in
                    Group { switch destination { case .explore: ExploreView(); case .history: HistoryView(); case .files: FilesView(); case .trash: TrashView() } }.accessibilityHidden(router.selectedTab != tab).onAppear { router.detailTabs.remove(tab) }
                }
        }
    }
}

/// Mount each stack on its first visit and retain it thereafter, without a second system tab bar.
private struct PersistentTab<Content: View>: View {
    let selected: Bool
    @ViewBuilder var content: Content
    @State private var mounted = false
    init(selected: Bool, @ViewBuilder content: () -> Content) { self.selected = selected; self.content = content() }
    var body: some View {
        Group { if mounted || selected { content } }
            .opacity(selected ? 1 : 0).allowsHitTesting(selected).accessibilityHidden(!selected)
            .onChange(of: selected, initial: true) { _, value in if value { mounted = true } }
    }
}
