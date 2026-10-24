import SwiftUI
import UIKit
import TwilDiaryCore

/// A single interaction surface: touch/hold to preview, slide the lens, release to select.
/// Native Button actions remain available to VoiceOver and keyboard activation.
struct DiaryNavigationBar: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("theme") private var theme = DiaryTheme.twilight
    private struct Scrub {
        let location: CGPoint
        let translation: CGSize
    }
    @GestureState private var scrub: Scrub?
    @State private var lastHovered: Int?
    private let inset: CGFloat = 4
    private let rowHeight: CGFloat = 57
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let cell = max(1, (width - inset * 2) / CGFloat(AppTab.allCases.count))
            let selected = AppTab.allCases.firstIndex(of: router.selectedTab) ?? 0
            let preview = scrub.flatMap { NavigationScrub.index(x: Double($0.location.x), width: Double(width), count: AppTab.allCases.count) } ?? selected
            let center = scrub.map { min(width - inset - cell / 2, max(inset + cell / 2, $0.location.x)) } ?? (inset + cell * (CGFloat(selected) + 0.5))
            let tilt = reduceMotion ? 0 : min(2, max(-2, Double(scrub?.translation.width ?? 0) * 0.015))
            ZStack(alignment: .topLeading) {
                DiaryNavigationSurface()
                DiaryNavigationSelection(selected: true)
                    .frame(width: cell, height: rowHeight)
                    .scaleEffect(x: reduceMotion || scrub == nil ? 1 : 1.045, y: reduceMotion || scrub == nil ? 1 : 0.965)
                    .rotationEffect(.degrees(tilt))
                    .offset(x: center - cell / 2, y: inset)
                    .animation(reduceMotion ? nil : .interactiveSpring(response: 0.26, dampingFraction: 0.76), value: center)
                    .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.65), value: scrub != nil)
                    .allowsHitTesting(false).accessibilityHidden(true)
                HStack(spacing: 0) {
                    ForEach(Array(AppTab.allCases.enumerated()), id: \.element) { index, tab in
                        Button { activate(tab) } label: {
                            VStack(spacing: 0) {
                                DiaryIcon(name: tab.icon, size: 23).frame(width: 40, height: 33)
                                Text(tab.label).font(.system(size: 11)).frame(height: 16.5)
                            }.frame(maxWidth: .infinity).frame(height: rowHeight).contentShape(Rectangle())
                                .foregroundStyle(theme == .glass ? Color(webHex: preview == index ? "#f5f5f7" : "#e0e0e6") : preview == index ? theme.accent : theme.muted)
                        }.buttonStyle(.plain).accessibilityLabel(tab.label).accessibilityIdentifier("tab-" + tab.rawValue)
                            .accessibilityAddTraits(router.selectedTab == tab ? .isSelected : [])
                    }
                }.padding(inset)
            }.contentShape(Capsule()).coordinateSpace(name: "diary-navigation")
                .highPriorityGesture(DragGesture(minimumDistance: 0, coordinateSpace: .named("diary-navigation"))
                    .updating($scrub) { value, state, _ in state = Scrub(location: value.location, translation: value.translation) }
                    .onChanged { value in
                        if let next = NavigationScrub.index(x: Double(value.location.x), width: Double(width), count: AppTab.allCases.count), next != lastHovered {
                            if lastHovered != nil || next != selected { UISelectionFeedbackGenerator().selectionChanged() }
                            lastHovered = next
                        }
                    }
                    .onEnded { value in
                        defer { lastHovered = nil }
                        guard NavigationScrub.acceptsRelease(x: Double(value.location.x), y: Double(value.location.y), width: Double(width), height: Double(rowHeight + inset * 2)),
                              let index = NavigationScrub.index(x: Double(value.location.x), width: Double(width), count: AppTab.allCases.count) else { return }
                        let tab = AppTab.allCases[index]
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        if value.translation.width * value.translation.width + value.translation.height * value.translation.height < 64 { router.select(tab) }
                        else if router.selectedTab != tab { router.selectedTab = tab }
                    })
                .onChange(of: scrub != nil) { _, active in if !active { lastHovered = nil } }
        }.frame(height: rowHeight + inset * 2)
    }
    private func activate(_ tab: AppTab) {
        if router.selectedTab != tab { UISelectionFeedbackGenerator().selectionChanged() }
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        router.select(tab)
    }
}
