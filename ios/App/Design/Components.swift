import SwiftUI
import UIKit
import TwilDiaryCore

enum DiaryTheme: String, CaseIterable, Identifiable {
    case twilight, ocean, jade, rose, amber, glass
    var id: Self { self }
    var name: String { self == .glass ? "Liquid Glass" : rawValue.capitalized }
    var accent: Color {
        switch self {
        case .twilight: Color(webHex: "#b795f6")
        case .ocean: Color(webHex: "#82b8ff")
        case .jade: Color(webHex: "#79d8bc")
        case .rose: Color(webHex: "#f4a2c6")
        case .amber: Color(webHex: "#edbe73")
        case .glass: Color(webHex: "#c4e5ff")
        }
    }
}

extension Color {
    init(webHex: String) {
        let raw = webHex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let value = UInt64(raw, radix: 16) ?? 0
        let rgb = raw.count == 8 ? value >> 8 : value
        self.init(.sRGB, red: Double((rgb >> 16) & 255) / 255, green: Double((rgb >> 8) & 255) / 255, blue: Double(rgb & 255) / 255, opacity: raw.count == 8 ? Double(value & 255) / 255 : 1)
    }
}

extension View {
    func diaryPanel() -> some View {
        padding(16).background(Color(webHex: "#111115"), in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(.white.opacity(0.13)))
    }
}

struct DiaryIcon: View {
    let name: String
    var size: CGFloat = 20
    var body: some View {
        Image(name).renderingMode(.template).resizable().scaledToFit().frame(width: size, height: size).accessibilityHidden(true)
    }
}

struct BrandMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let sx = rect.width / 24, sy = rect.height / 24
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * sx, y: rect.minY + y * sy) }
        path.move(to: point(12, 1))
        path.addCurve(to: point(23, 12), control1: point(13.5, 8.5), control2: point(15.5, 10.5))
        path.addCurve(to: point(12, 23), control1: point(15.5, 13.5), control2: point(13.5, 15.5))
        path.addCurve(to: point(1, 12), control1: point(10.5, 15.5), control2: point(8.5, 13.5))
        path.addCurve(to: point(12, 1), control1: point(8.5, 10.5), control2: point(10.5, 8.5))
        path.closeSubpath(); return path
    }
}

struct PageHeader: View {
    let name: String
    var count: String? = nil
    var onSearch: (() -> Void)? = nil
    var onDone: (() -> Void)? = nil
    var doneIdentifier = "page-done"
    @AppStorage("theme") private var theme = DiaryTheme.twilight
    var body: some View {
        HStack(spacing: 9) {
            BrandMark().fill(theme.accent).frame(width: 24, height: 24)
                .frame(width: 44, height: 44).background(theme.accent.opacity(0.07), in: Circle())
                .overlay(Circle().strokeBorder(theme.accent.opacity(0.3)))
            if name == "TwilDiary" {
                HStack(spacing: 0) {
                    Text("Twil").foregroundStyle(Color(webHex: "#f3f0f7"))
                    Text("Diary").foregroundStyle(LinearGradient(colors: [.white, theme.accent], startPoint: .leading, endPoint: .trailing))
                }.font(.system(size: 26, weight: .bold)).tracking(-1.25)
            } else { Text(name).font(.system(size: 26, weight: .bold)).tracking(-1.2).foregroundStyle(Color(webHex: "#f3f0f7")).lineLimit(1).minimumScaleFactor(0.7) }
            if let count { Text(count).font(.system(size: 13)).foregroundStyle(Color(webHex: "#a09aa9")).lineLimit(1) }
            Spacer(minLength: 0)
            if let onSearch { Button(action: onSearch) { DiaryIcon(name: "search", size: 22).frame(width: 44, height: 44) }.buttonStyle(.plain).foregroundStyle(Color(webHex: "#c5c0cf")).accessibilityLabel(name == "Library" ? "Search library" : "Search").accessibilityIdentifier("search-" + name.lowercased()) }
            if let onDone { Button("Done", action: onDone).font(.system(size: 14, weight: .semibold)).frame(minWidth: 44, minHeight: 44).accessibilityIdentifier(doneIdentifier) }
        }.frame(height: 56).padding(.horizontal, 14).background(Color(webHex: "#050507"))
    }
}

struct SearchField: View {
    let placeholder: String
    @Binding var text: String
    let label: String
    var autoFocus = false
    @State private var didAutoFocus = false
    @FocusState private var focused: Bool
    @AppStorage("theme") private var theme = DiaryTheme.twilight
    var body: some View {
        HStack(spacing: 10) {
            DiaryIcon(name: "search", size: 19).foregroundStyle(Color(webHex: "#a09aa9"))
            TextField(placeholder, text: $text).font(.system(size: 16)).textInputAutocapitalization(.never).autocorrectionDisabled().submitLabel(.search).focused($focused).onSubmit { focused = false }.accessibilityLabel(label)
            if !text.isEmpty { Button { text = "" } label: { DiaryIcon(name: "x", size: 16).frame(width: 26, height: 32) }.buttonStyle(.plain).accessibilityLabel("Clear search") }
        }.padding(.horizontal, 14).frame(minHeight: 48).background(Color(webHex: "#111115"), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(focused ? theme.accent.opacity(0.65) : .white.opacity(0.13)))
            .task { if autoFocus && !didAutoFocus { didAutoFocus = true; focused = true } }
    }
}

@MainActor private enum DemoArtwork {
    static let cache = NSCache<NSString, UIImage>()
    static func image(_ path: String) -> UIImage? {
        if let saved = cache.object(forKey: path as NSString) { return saved }
        if path.hasPrefix("scene:") {
            let scenes: [String: CGRect] = ["frieren": CGRect(x: 506, y: 446, width: 287, height: 120), "night": CGRect(x: 510, y: 795, width: 285, height: 145), "severance": CGRect(x: 496, y: 1150, width: 299, height: 135), "again": CGRect(x: 510, y: 1480, width: 285, height: 110)]
            guard let crop = scenes[String(path.dropFirst(6))], let file = Bundle.main.path(forResource: "glance-reference-atlas", ofType: "jpg"), let source = UIImage(contentsOfFile: file)?.cgImage?.cropping(to: crop) else { return nil }
            let image = UIImage(cgImage: source); cache.setObject(image, forKey: path as NSString); return image
        }
        let name = path.hasPrefix("asset:") ? String(path.dropFirst(6)) : URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
        let windows: [String: CGRect] = ["frieren": CGRect(x: 60, y: 335, width: 193, height: 240), "night": CGRect(x: 60, y: 711, width: 193, height: 242), "severance": CGRect(x: 60, y: 1084, width: 193, height: 212), "again": CGRect(x: 60, y: 1426, width: 193, height: 177)]
        let image: UIImage?
        if path.hasPrefix("/demo/"), let crop = windows[name], let file = Bundle.main.path(forResource: "glance-reference-atlas", ofType: "jpg"), let source = UIImage(contentsOfFile: file)?.cgImage?.cropping(to: crop) { image = UIImage(cgImage: source) }
        else if let file = Bundle.main.path(forResource: name, ofType: "jpg") { image = UIImage(contentsOfFile: file) }
        else { image = nil }
        if let image { cache.setObject(image, forKey: path as NSString) }; return image
    }
}

struct Artwork: View {
    let path: String?
    var title: String = ""
    var body: some View {
        GeometryReader { proxy in
          ZStack {
            LinearGradient(colors: [tint, Color(webHex: "#1c1728")], startPoint: .topLeading, endPoint: .bottomTrailing)
            if let path, path.hasPrefix("asset:") || path.hasPrefix("/demo/") || path.hasPrefix("scene:"), let image = DemoArtwork.image(path) { Image(uiImage: image).resizable().scaledToFill().frame(width: proxy.size.width, height: proxy.size.height).clipped() }
            else if let image = fixtureImage(path) { Image(uiImage: image).resizable().scaledToFill().frame(width: proxy.size.width, height: proxy.size.height).clipped() }
            else if let path, let url = URL(string: path), url.scheme == "https" {
                AsyncImage(url: url) { phase in if let image = phase.image { image.resizable().scaledToFill().frame(width: proxy.size.width, height: proxy.size.height).clipped() } else { initials } }
            } else { initials }
          }.frame(width: proxy.size.width, height: proxy.size.height).clipped()
        }.contentShape(Rectangle()).accessibilityHidden(true)
    }
    private var tint: Color {
        let values = ["#543173", "#514779", "#294959", "#345682", "#477062", "#73435f"]
        return Color(webHex: values[title.unicodeScalars.reduce(0) { $0 + Int($1.value) } % values.count])
    }
    private func fixtureImage(_ path: String?) -> UIImage? {
        #if DEBUG
        guard ProcessInfo.processInfo.arguments.contains("--ui-testing"), let path, path.contains("image.tmdb.org/t/p/") else { return nil }
        return DemoArtwork.image(path.contains("backdrop") ? "/demo/frieren-hero-v2.jpg" : "asset:frieren")
        #else
        return nil
        #endif
    }
    private var initials: some View { Text(title.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined().uppercased()).font(.system(size: 24, weight: .bold)).foregroundStyle(Color(webHex: "#eee6fb99")) }
}

struct RatingBadge: View {
    let score: Double
    var body: some View {
        HStack(spacing: 3) { Image(systemName: "star.fill").foregroundStyle(Color(webHex: "#ffe341")); Text(score, format: .number.precision(.fractionLength(1))) }
            .font(.system(size: 11, weight: .semibold)).foregroundStyle(.white).shadow(color: .black.opacity(0.9), radius: 3, y: 1)
            .padding(.horizontal, 6).padding(.vertical, 4).background(.black.opacity(0.65), in: Capsule())
    }
}

struct PosterCard: View {
    let title: MediaTitle
    @Environment(DiaryStore.self) private var store
    @AppStorage("publicRatingSource") private var ratingSource = PublicRatingSource.tmdb
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Artwork(path: title.poster, title: title.name).aspectRatio(2 / 3, contentMode: .fit)
                .overlay(alignment: .topLeading) { if let score = store.publicScore(title, source: ratingSource) { RatingBadge(score: score).padding(6) } }
                .overlay(alignment: .bottom) { if title.status == "watching" { GeometryReader { proxy in Rectangle().fill(.white.opacity(0.2)).overlay(alignment: .leading) { Rectangle().fill(.tint).frame(width: proxy.size.width * progress) } }.frame(height: 4) } }
                .overlay(alignment: .bottomTrailing) { if title.status == "completed" { Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundStyle(.black).frame(width: 25, height: 25).background(Color(webHex: "#6ce3a5"), in: Circle()).padding(7) } }
                .overlay(alignment: .bottomLeading) { if present || title.queued == true { DiaryIcon(name: present ? "monitor" : "download", size: 13).foregroundStyle(Color(webHex: present ? "#9edbc4" : "#b795f6")).padding(6).background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 6)).padding(7) } }
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Text(title.name).font(.system(size: 14, weight: .semibold)).foregroundStyle(Color(webHex: "#f3f0f7")).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
        }.contentShape(Rectangle()).accessibilityElement(children: .ignore).accessibilityLabel(title.name).accessibilityValue(accessibleDetails)
    }
    private var present: Bool { store.workspace.locations.contains { $0.titleId == title.id && $0.evidence == "present" } }
    private var accessibleDetails: String {
        [title.categoryName, title.status.capitalized, store.publicScore(title, source: ratingSource).map { "Rating " + $0.formatted(.number.precision(.fractionLength(1))) }, title.status == "watching" ? "\(Int((progress * 100).rounded())) percent watched" : nil].compactMap { $0 }.joined(separator: ", ")
    }
    private var progress: Double {
        LibraryProgress.fraction(title: title, workspace: store.workspace)
    }
}

struct CategoryPicker: View {
    @Binding var selection: LibraryCategory
    var body: some View {
        HStack(spacing: 0) {
            ForEach(LibraryCategory.allCases) { category in
                Button { selection = category } label: {
                    Text(category.rawValue).font(.system(size: 15, weight: .semibold)).foregroundStyle(selection == category ? Color(webHex: "#f3f0f7") : Color(webHex: "#a09aa9"))
                        .padding(.horizontal, 14).frame(height: 40)
                        .overlay(alignment: .bottom) { if category == selection { Rectangle().fill(.tint).frame(height: 3) } }
                }.buttonStyle(.plain).accessibilityAddTraits(selection == category ? .isSelected : [])
            }
            Spacer(minLength: 0)
        }
    }
}

struct SectionHeading<Trailing: View>: View {
    let name: String
    @ViewBuilder var trailing: Trailing
    var body: some View { HStack(spacing: 8) { Text(name).font(.system(size: 19, weight: .semibold)).tracking(-0.5); Spacer(minLength: 4); trailing.font(.system(size: 12, weight: .semibold)) }.frame(minHeight: 32) }
}

struct ProgressCard: View {
    let title: MediaTitle
    var compact = false
    @Environment(DiaryStore.self) private var store
    @State private var card: WatchCard?
    @State private var drag: CGFloat = 0
    var body: some View {
        ZStack(alignment: .leading) {
            if !compact { Label("Mark one watched", systemImage: "checkmark").font(.subheadline.bold()).foregroundStyle(.mint).padding(20) }
            Group { if compact { compactContent } else { glanceContent } }
                .background { GeometryReader { proxy in Artwork(path: cardBackdrop, title: title.name).frame(width: proxy.size.width, height: proxy.size.height).overlay(LinearGradient(colors: [.black.opacity(compact ? 0.05 : 0.35), .black.opacity(0.88)], startPoint: .top, endPoint: .bottom)) } }
                .clipShape(RoundedRectangle(cornerRadius: compact ? 12 : 14))
                .overlay(RoundedRectangle(cornerRadius: compact ? 12 : 14).strokeBorder(.white.opacity(0.17)))
                .offset(x: drag)
        }.background(.green.opacity(0.15), in: RoundedRectangle(cornerRadius: 14)).clipShape(RoundedRectangle(cornerRadius: 14))
            .simultaneousGesture(DragGesture(minimumDistance: 22).onChanged { value in
                guard !compact, value.startLocation.x > 24, !store.busy, card?.next != nil || !title.isSeries else { return }
                if value.translation.width > abs(value.translation.height) * 1.3 { drag = min(120, max(0, value.translation.width)) }
            }.onEnded { _ in
                let mark = drag > 80; withAnimation(.easeOut(duration: 0.18)) { drag = 0 }
                if mark { Task { await markWatch() } }
            })
            .task(id: store.workspace.events) { await loadCard() }
    }
    private var compactContent: some View {
        VStack {
            Spacer(minLength: 0)
            HStack(alignment: .bottom, spacing: 10) {
                NavigationLink(value: title.id) { Artwork(path: title.poster, title: title.name).frame(width: 42, height: 62).clipShape(RoundedRectangle(cornerRadius: 6)) }.buttonStyle(.plain)
                VStack(alignment: .leading, spacing: 7) {
                    NavigationLink(value: title.id) { Text(title.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white).lineLimit(1) }.buttonStyle(.plain)
                    timeLine.font(.system(size: 12, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.8)
                    GeometryReader { proxy in Capsule().fill(.white.opacity(0.15)).overlay(alignment: .leading) { Capsule().fill(.tint).frame(width: proxy.size.width * fraction) } }.frame(height: 4)
                }.padding(.bottom, 4)
                Button { Task { await markWatch() } } label: { Image(systemName: "plus").font(.system(size: 24, weight: .regular)).frame(width: 36, height: 36) }
                    .buttonStyle(.plain).foregroundStyle(Color(webHex: "#21182e")).background(.tint, in: RoundedRectangle(cornerRadius: 10)).disabled(store.busy || (title.isSeries && card?.next == nil)).accessibilityLabel("Mark next watch for \(title.name)")
            }
        }.padding(12).frame(height: 142)
    }
    private var glanceContent: some View {
        VStack(spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                NavigationLink(value: title.id) { Artwork(path: title.poster, title: title.name).frame(width: 94, height: 118).clipShape(RoundedRectangle(cornerRadius: 8)) }.buttonStyle(.plain)
                VStack(alignment: .leading, spacing: 7) {
                    HStack(alignment: .top) {
                        NavigationLink(value: title.id) { Text(title.name).font(.system(size: 18, weight: .semibold)).foregroundStyle(.white).lineLimit(2).multilineTextAlignment(.leading) }.buttonStyle(.plain).accessibilityIdentifier("progress-title-" + title.id)
                        Spacer(minLength: 0)
                        Menu { Button(title.queued == true ? "Remove from Queue" : "Queue") { Task { await store.patch(title, values: ["queued": title.queued != true]) } } } label: { DiaryIcon(name: "ellipsis", size: 19).frame(width: 26, height: 30) }.foregroundStyle(Color(webHex: "#c5c0cf"))
                    }
                    timeLine.font(.system(size: 13, weight: .semibold)).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
            }
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    GeometryReader { proxy in Capsule().fill(.white.opacity(0.16)).overlay(alignment: .leading) { Capsule().fill(.tint).frame(width: proxy.size.width * fraction) } }.frame(height: 6)
                    Text("\(Int((fraction * 100).rounded()))% complete").font(.system(size: 13)).foregroundStyle(Color(webHex: "#c5c0cf"))
                }
                Button { let reviewed = card?.previous; Task { await store.removeLatest(title, expected: reviewed); await loadCard() } } label: { Image(systemName: "minus").font(.system(size: 18)).frame(width: 32, height: 32).background(.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.white.opacity(0.3))) }.buttonStyle(.plain).disabled(store.busy || card?.previous == nil).accessibilityLabel("Remove latest watch for \(title.name)")
                Text("\(card?.progress.watched ?? 0)").font(.system(size: 17, weight: .semibold)).monospacedDigit().accessibilityIdentifier("watch-count-" + title.id)
                Button { Task { await markWatch() } } label: { Image(systemName: "plus").font(.system(size: 20)).foregroundStyle(Color(webHex: "#21182e")).frame(width: 34, height: 34).background(.tint, in: RoundedRectangle(cornerRadius: 10)) }.buttonStyle(.plain).disabled(store.busy || (title.isSeries && card?.next == nil)).accessibilityLabel("Mark next watch for \(title.name)")
            }
        }.padding(10)
    }
    private var timeLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(card?.season.map { "S\($0.number) · E\(card?.progress.watched ?? 0) of \(card?.progress.total ?? 0)" } ?? title.categoryName).foregroundStyle(Color(webHex: "#c5c0cf"))
            Text(remaining.map { "· \(DiaryDate.duration($0)) left" } ?? "· Time unknown").foregroundStyle(Color(white: 0.75)).shadow(color: .black.opacity(0.8), radius: 2, y: 1)
        }
    }
    private var fraction: Double { guard let card, card.progress.total > 0 else { return 0 }; return min(1, Double(card.progress.watched) / Double(card.progress.total)) }
    private var cardBackdrop: String? { ["again", "night", "severance"].contains(title.id) ? "scene:" + title.id : title.backdrop ?? title.poster }
    private var remaining: Int? {
        guard let card else { return nil }
        if !title.isSeries { return title.runtimeMinutes.map { card.progress.watched == 0 ? $0 : 0 } }
        return SeasonProgress.calculate(title: title, workspace: store.workspace, season: card.season?.number ?? 1).remainingMinutes
    }
    private func loadCard() async {
        do { let result = try await store.card(title); guard !Task.isCancelled else { return }; card = result }
        catch is CancellationError { }
        catch { if !Task.isCancelled { store.error = error.localizedDescription } }
    }
    private func markWatch() async { await store.markNext(title, expectedEpisode: card?.next?.id); await loadCard() }
}
