import SwiftUI
import TwilDiaryCore

@MainActor struct TraktView: View {
    let store: DiaryStore
    @State private var controller: TraktController
    @State private var showSignIn = false
    @State private var clock = Date.now
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage("theme") private var theme = DiaryTheme.twilight
    init(store: DiaryStore) { self.store = store; _controller = State(initialValue: TraktController(service: makeTraktService(store: store))) }
    var body: some View {
        @Bindable var controller = controller
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                connection
                if controller.status?.connected == true {
                    preferences
                    if controller.busy || controller.sync?.run?.state == "building" { scanProgress }
                    if let sync = controller.sync, sync.run != nil { review(sync) }
                }
                if let error = controller.error { VStack(alignment: .leading, spacing: 8) { Text(error).font(.subheadline).foregroundStyle(.secondary); Button("Retry") { Task { await controller.refresh() } }.disabled(controller.busy) }.diaryPanel().accessibilityIdentifier("trakt-error") }
            }.padding(16).padding(.bottom, 100)
        }.background(.black).navigationTitle("Trakt").navigationBarTitleDisplayMode(.inline).navigationBarBackButtonHidden().toolbar(.visible, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .task(id: controller.kind.rawValue + "\n" + controller.query) {
                do { try await Task.sleep(for: .milliseconds(250)); try Task.checkCancellation(); await controller.refreshReview() } catch { }
            }
            .refreshable { await controller.refresh() }
            .task(id: controller.cooldownUntil) {
                clock = .now
                while controller.cooldownUntil > clock && !Task.isCancelled {
                    do { try await Task.sleep(for: .seconds(1)) } catch { return }
                    clock = .now
                }
            }
            .onDisappear { controller.paused = true }
            .onChange(of: scenePhase) { _, phase in if phase == .active && !controller.busy { Task { await controller.refresh() } } }
            .sheet(isPresented: $showSignIn) {
                if let credential = store.browserCredential() {
                    NavigationStack {
                        TraktSignIn(credential: credential) { result in
                            showSignIn = false
                            switch result { case .success: Task { await controller.refresh() }; case .failure(let error): controller.error = error.localizedDescription }
                        }.navigationTitle("Connect Trakt").navigationBarTitleDisplayMode(.inline)
                            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showSignIn = false } } }
                    }
                }
            }
    }
    private var connection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                DiaryIcon(name: "link-2", size: 22).foregroundStyle(theme.accent).padding(12).background(theme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 4) { Text(controller.status?.needsReconnect == true ? "Reconnect Trakt" : controller.status?.connected == true ? "Connected" : controller.loading ? "Checking connection…" : "Connect to Trakt").font(.title3.bold()); Text(controller.status?.username.map { "@" + $0 } ?? "Your watches, together").font(.caption).foregroundStyle(.secondary) }
                Spacer(minLength: 0)
                if controller.status?.needsReconnect == true { Text("Reconnect").font(.caption.bold()).foregroundStyle(.yellow) }
                else if (controller.sync?.pendingChanges ?? 0) > 0 { Text("Review").font(.caption.bold()).foregroundStyle(.yellow) }
            }
            if let date = DiaryDate.parse(controller.status?.lastSyncAt) { Text("Last synced \(date.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(.secondary) }
            if controller.status?.connected == true {
                HStack { Button("Scan Trakt", systemImage: "arrow.trianglehead.2.clockwise.rotate.90") { Task { await controller.scan(start: true) } }.buttonStyle(.borderedProminent).disabled(coolingDown); Button("Disconnect", role: .destructive) { Task { await controller.disconnect() } }.buttonStyle(.bordered) }.disabled(controller.busy)
            } else if controller.status?.configured == true {
                Button("Connect Trakt") { showSignIn = true }.buttonStyle(.borderedProminent).disabled(controller.busy)
                Link("Connect in browser", destination: AppConfiguration.backend.appendingPathComponent("preview/more/trakt")).font(.caption)
            } else if controller.status != nil { Text("Configure the Trakt Client ID on your server using the PC app. Sign-in uses PKCE; no client secret is needed.").font(.subheadline).foregroundStyle(.secondary) }
            if coolingDown { Text("Trakt asked us to wait \(Int(ceil(controller.cooldownUntil.timeIntervalSince(clock))))s before continuing.").font(.caption).foregroundStyle(.secondary) }
        }.diaryPanel()
    }
    private var preferences: some View {
        @Bindable var controller = controller
        return VStack(alignment: .leading, spacing: 12) {
            Text("Sync preferences").font(.subheadline.bold()).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 12) {
                Picker("Decimal ratings", selection: $controller.mode) { ForEach(TraktRatingMode.allCases) { Text($0.label).tag($0) } }.pickerStyle(.menu).disabled(controller.busy)
                Text("For the next scan; decimals stay in TwilDiary").font(.caption).foregroundStyle(.secondary)
                Divider(); Text("Included in each scan").font(.caption).foregroundStyle(.secondary)
                Text("Watch history · Ratings · Watchlist").font(.subheadline)
            }.diaryPanel()
        }
    }
    private var scanProgress: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(controller.sync?.run.map { "\($0.stage.replacingOccurrences(of: "-", with: " ")) · page \($0.page)" } ?? "Sync in progress…").font(.subheadline)
            if controller.busy { Button(controller.paused ? "Pausing…" : "Pause after this step") { controller.paused = true }.disabled(controller.paused) }
            else { Button("Continue scan") { Task { await controller.scan(start: false) } }.disabled(coolingDown) }
        }.diaryPanel()
    }
    private func review(_ sync: TraktSync) -> some View {
        @Bindable var controller = controller
        return VStack(alignment: .leading, spacing: 14) {
            HStack { Text("Review changes").font(.title2.bold()); Spacer(); Text("\(sync.pendingChanges) remaining").font(.caption).foregroundStyle(.secondary) }
            Text("\(sync.run?.progress ?? 0) Trakt items scanned. Nothing is saved until you apply it.").font(.subheadline).foregroundStyle(.secondary)
            if let error = sync.run?.error { Text(error).font(.caption).foregroundStyle(.secondary) }
            if sync.run?.state == "complete" { Label((sync.counts["skipped"] ?? 0) > 0 ? "Finished with skipped items" : "You’re up to date", systemImage: "checkmark.circle").diaryPanel() }
            else if sync.run?.state == "cancelled" { Text("Scan stopped. Scan again when you’re ready to continue.").font(.subheadline).diaryPanel() }
            else {
                SearchField(placeholder: "Find a title in this review…", text: $controller.query, label: "Search Trakt changes")
                Picker("Filter Trakt changes", selection: $controller.kind) { ForEach(TraktKind.allCases) { Text($0.label).tag($0) } }.pickerStyle(.segmented).accessibilityIdentifier("trakt-kind")
                LazyVStack(spacing: 10) { ForEach(Array(controller.visibleItems.prefix(controller.limit))) { change in reviewItem(change, sync: sync) } }
                if controller.visibleItems.isEmpty { Text("No matching changes in this review.").font(.subheadline).foregroundStyle(.secondary) }
                HStack { Text("Showing \(min(controller.limit, controller.visibleItems.count)) of \(controller.visibleItems.count) loaded changes").font(.caption).foregroundStyle(.secondary); Spacer(); if controller.limit < controller.visibleItems.count || sync.next != nil { Button("Load more") { Task { await controller.loadMore() } }.font(.subheadline).disabled(controller.busy) } }
                if sync.reviewing && (sync.counts["safe"] ?? 0) > 0 { applyPanel(sync).padding(.top, 10) }
                if sync.reviewing || sync.run?.state == "building" { Button("Stop this scan") { Task { await controller.cancel() } }.font(.subheadline).disabled(controller.busy) }
            }
        }
    }
    private func applyPanel(_ sync: TraktSync) -> some View {
        VStack(spacing: 9) {
            Button { Task { await controller.apply(); await store.refresh() } } label: {
                Text(sync.readyChanges > 0 ? "Apply all ready changes (\(sync.readyChanges))" : "Link existing items (\(sync.counts["links"] ?? 0))")
                    .font(.system(size: 15, weight: .semibold)).frame(maxWidth: .infinity).frame(minHeight: 50)
                    .foregroundStyle(Color(webHex: "#21182e")).background(theme.accent, in: RoundedRectangle(cornerRadius: 12))
            }.buttonStyle(.plain).disabled(controller.busy || coolingDown).accessibilityIdentifier("trakt-apply-ready")
            Text("Conflicts need your choice above. Filters only change what’s shown.").font(.system(size: 12)).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
    }
    private func reviewItem(_ change: TraktChange, sync: TraktSync) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) { Text(change.name).font(.subheadline.bold()); Spacer(); Text(change.kindLabel).font(.caption.bold()).foregroundStyle(theme.accent).padding(6).background(theme.accent.opacity(0.1), in: Capsule()) }
            Text(change.error ?? change.detail).font(.caption).foregroundStyle(.secondary)
            if let context = change.context {
                if let season = context.season, let episode = context.episode, change.kind == "history" { Text("S\(season) · E\(episode)").font(.caption).foregroundStyle(.secondary) }
                if change.review { Text("TwilDiary: \(reviewValue(change.kind, context.local)) · Trakt: \(reviewValue(change.kind, context.remote))").font(.caption).foregroundStyle(.secondary) }
                else if change.kind == "history" { Text(reviewValue(change.kind, change.direction == "push" ? context.local : context.remote)).font(.caption).foregroundStyle(.secondary) }
            }
            if ["applied", "skipped"].contains(change.state) { Text(change.state.capitalized).font(.caption).foregroundStyle(.secondary) }
            else {
                // A single subtree keeps each review action unique in accessibility.
                // ViewThatFits retained two sets of buttons, including hidden candidates.
                let layout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                    : AnyLayout(HStackLayout(spacing: 8))
                layout { changeActions(change) }.disabled(controller.busy || !sync.reviewing)
            }
        }.diaryPanel().accessibilityElement(children: .contain).accessibilityIdentifier("trakt-change-" + change.id)
    }
    @ViewBuilder private func changeActions(_ change: TraktChange) -> some View {
        if change.state == "uncertain" { action("Check Trakt", change: change, choice: .local) }
        else if change.review && !change.blocked { action("Keep TwilDiary", change: change, choice: .local); action("Use Trakt", change: change, choice: .trakt) }
        else if !change.blocked { action("Apply", change: change, choice: .apply) }
        Button("Skip") { Task { await controller.apply(change: change, choice: .skip); await store.refresh() } }.font(.caption).accessibilityIdentifier("trakt-skip-" + change.id)
    }
    private func action(_ label: String, change: TraktChange, choice: TraktChoice) -> some View {
        Button(label) { Task { await controller.apply(change: change, choice: choice); await store.refresh() } }.buttonStyle(.bordered).font(.caption).disabled(coolingDown).accessibilityIdentifier("trakt-" + choice.rawValue + "-" + change.id)
    }
    private func reviewValue(_ kind: String, _ value: String?) -> String {
        if kind == "rating" { return value ?? "No rating" }
        if kind == "watchlist" { return value == "true" ? "Planned" : "Not planned" }
        return DiaryDate.parse(value).map { $0.formatted(date: .abbreviated, time: .shortened) } ?? "Unknown date"
    }
    private var coolingDown: Bool { controller.cooldownUntil > clock }
}
