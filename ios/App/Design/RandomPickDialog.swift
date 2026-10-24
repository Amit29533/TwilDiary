import SwiftUI
import TwilDiaryCore

struct RandomPickScope: Identifiable {
    let id = UUID()
    /// nil is the whole collection; an empty list is deliberately empty.
    let titleIDs: [String]?
    func candidates(in workspace: Workspace) -> [MediaTitle] {
        guard let titleIDs else { return workspace.titles }
        let ids = Set(titleIDs)
        return workspace.titles.filter { ids.contains($0.id) }
    }
}

struct RandomPickDialog: View {
    let titles: [MediaTitle]
    let onClose: () -> Void
    let onOpen: (String) -> Void
    let onAdd: () -> Void
    @AppStorage("theme") private var theme = DiaryTheme.twilight
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedID: String?
    @State private var sequence = 0
    @State private var rolling = false
    private var active: [MediaTitle] { titles.filter { $0.deletedAt == nil } }
    private var picked: MediaTitle? { active.first { $0.id == selectedID } }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color(webHex: "#020106bf").background(.ultraThinMaterial).ignoresSafeArea().onTapGesture { onClose() }.accessibilityHidden(true)
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 8) {
                            DiaryIcon(name: "sparkles", size: 17)
                            Text("A little surprise").font(.system(size: 14))
                            Spacer(minLength: 0)
                            Button(action: onClose) { DiaryIcon(name: "x", size: 21).frame(width: 44, height: 44) }
                                .buttonStyle(.plain).accessibilityLabel("Close random pick")
                        }.foregroundStyle(theme.accent).padding(.bottom, 7)
                        if let picked {
                            pickCard(picked, compact: proxy.size.width < 359).id(sequence)
                                .transition(reduceMotion ? .identity : .opacity.combined(with: .offset(y: 14)))
                            HStack(spacing: 10) {
                                Button { choose() } label: { HStack(spacing: 7) { DiaryIcon(name: "shuffle", size: 18); Text("Pick again") }.frame(maxWidth: .infinity).frame(minHeight: 44) }
                                    .buttonStyle(.plain).background(Color(webHex: "#131219"), in: RoundedRectangle(cornerRadius: 12))
                                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color(webHex: "#34313f")))
                                    .disabled(active.count < 2 || rolling).accessibilityIdentifier("random-pick-again")
                                Button { onOpen(picked.id) } label: { HStack(spacing: 7) { Text("Open title"); DiaryIcon(name: "arrow-up-right", size: 18) }.frame(maxWidth: .infinity).frame(minHeight: 44) }
                                    .buttonStyle(.plain).foregroundStyle(theme.ink).background(theme.accent, in: RoundedRectangle(cornerRadius: 12)).accessibilityIdentifier("random-pick-open")
                            }.font(.system(size: 14, weight: .semibold)).padding(.top, 16)
                        } else {
                            VStack(spacing: 14) {
                                DiaryIcon(name: "sparkles", size: 32).foregroundStyle(theme.accent)
                                Text("Your next story starts here").font(.system(size: 20, weight: .bold)).foregroundStyle(.primary)
                                Text("Add some titles to your collection for a surprise pick.").font(.system(size: 14)).foregroundStyle(.secondary)
                                Button("Add a title", action: onAdd).buttonStyle(.borderedProminent).controlSize(.large)
                            }.multilineTextAlignment(.center).frame(maxWidth: .infinity).padding(.horizontal, 12).padding(.vertical, 28)
                        }
                    }.padding(16)
                }.fixedSize(horizontal: false, vertical: true).frame(maxHeight: max(0, proxy.size.height - 32))
                    .frame(width: min(480, max(0, proxy.size.width - 38)))
                    .background(Color(webHex: "#0d0d12"), in: RoundedRectangle(cornerRadius: 26))
                    .overlay(RoundedRectangle(cornerRadius: 26).strokeBorder(theme.accent.opacity(0.3137)))
                    .shadow(color: theme.accent.opacity(0.11), radius: 45)
                    .shadow(color: .black.opacity(0.8), radius: 50, y: 30)
                    .accessibilityElement(children: .contain).accessibilityAddTraits(.isModal).accessibilityIdentifier("random-pick-dialog")
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }.onAppear { choose() }
            .onChange(of: active.map(\.id)) { _, _ in if picked == nil { rolling = false; choose() } }
            .task(id: sequence) {
                guard rolling else { return }
                do { try await Task.sleep(for: .milliseconds(650)) } catch { return }
                rolling = false
            }.accessibilityAction(.escape) { onClose() }
    }

    private func pickCard(_ title: MediaTitle, compact: Bool) -> some View {
        HStack(spacing: compact ? 12 : 18) {
            Artwork(path: title.poster, title: title.name, initialsOnly: false).frame(width: compact ? 85 : 115, height: compact ? 128 : 173)
                .clipShape(RoundedRectangle(cornerRadius: 11)).shadow(color: .black.opacity(0.53), radius: 13, y: 10).rotationEffect(.degrees(-3))
            VStack(alignment: .leading, spacing: 10) {
                Text("FROM YOUR COLLECTION").font(.system(size: 11)).tracking(0.77).foregroundStyle(theme.accent)
                Text(title.name).font(.system(size: 19.2, weight: .bold)).tracking(-0.5).fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("random-picked-name")
                Text([title.year.map(String.init), title.categoryName].compactMap { $0 }.joined(separator: " · ")).font(.system(size: 13)).foregroundStyle(Color(webHex: "#c5c0cf"))
                Text(title.status.capitalized).font(.system(size: 12)).foregroundStyle(theme.accent)
                    .padding(.horizontal, 9).padding(.vertical, 4).background(theme.accent.opacity(0.0784), in: Capsule()).overlay(Capsule().strokeBorder(theme.accent.opacity(0.2667)))
            }.frame(maxWidth: .infinity, alignment: .leading)
        }.padding(.horizontal, compact ? 12 : 18).padding(.vertical, compact ? 20 : 26).frame(minHeight: 240)
            .background {
                ZStack {
                    Color(webHex: "#17121f")
                    if let backdrop = title.backdrop { Artwork(path: backdrop).opacity(0.6) }
                    LinearGradient(colors: [Color(webHex: "#15101966"), Color(webHex: "#0a090df2")], startPoint: .leading, endPoint: .trailing)
                    LinearGradient(colors: [Color(webHex: "#08080d"), .clear], startPoint: .bottom, endPoint: .top)
                }.allowsHitTesting(false)
            }.clipShape(RoundedRectangle(cornerRadius: 17)).overlay(RoundedRectangle(cornerRadius: 17).strokeBorder(.white.opacity(0.125)))
    }
    private func choose() {
        guard !rolling else { return }
        #if DEBUG
        let sample = ProcessInfo.processInfo.arguments.contains("--ui-testing") ? 0.45 : Double.random(in: 0..<1)
        #else
        let sample = Double.random(in: 0..<1)
        #endif
        let next = RandomPick.choose(titles, previousID: selectedID, sample: sample)
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.5)) { selectedID = next?.id; sequence += 1; rolling = next != nil }
    }
}
