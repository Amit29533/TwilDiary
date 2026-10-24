import SwiftUI

/// Shared title header for saved titles and unimported catalog previews.
struct TitleHero<PersonalRating: View>: View {
    let name: String
    let poster: String?
    let year: Int?
    let category: String
    let runtime: Int?
    let series: Bool
    let score: Double?
    let summary: String
    @Binding var expanded: Bool
    let personalRating: PersonalRating
    init(name: String, poster: String?, year: Int?, category: String, runtime: Int?, series: Bool, score: Double?, summary: String, expanded: Binding<Bool>, @ViewBuilder personalRating: () -> PersonalRating) {
        self.name = name; self.poster = poster; self.year = year; self.category = category; self.runtime = runtime; self.series = series; self.score = score; self.summary = summary; self._expanded = expanded; self.personalRating = personalRating()
    }
    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            Artwork(path: poster, title: name).frame(width: 114, height: 171).clipShape(RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 0) {
                Text(name).font(.system(size: 24, weight: .bold)).tracking(-1.08).fixedSize(horizontal: false, vertical: true)
                Text([year.map(String.init) ?? "—", category, runtime.map { series ? "\($0) min per episode" : "\($0) min" }].compactMap { $0 }.joined(separator: " · ")).font(.system(size: 14.4)).lineSpacing(4.3).foregroundStyle(.secondary).frame(minHeight: 21.6, alignment: .top).padding(.top, 14)
                InlineFlowLayout {
                    HStack(spacing: 5) { Image(systemName: "star.fill").font(.system(size: 20)).foregroundStyle(.yellow); Text(score.map { $0.formatted(.number.precision(.fractionLength(1))) } ?? "—").foregroundStyle(.yellow); Text("TMDb").font(.system(size: 14.4)).foregroundStyle(.secondary) }.frame(minHeight: 44)
                    personalRating
                }.font(.system(size: 15.2)).padding(.top, 14)
                synopsis.padding(.top, 16)
            }.padding(.top, 14)
        }.padding(.top, 82)
    }
    private var synopsis: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(summary.isEmpty ? "Add your own thoughts in Notes." : summary).font(.system(size: 15.04)).lineSpacing(6).foregroundStyle(Color(webHex: "#c5c0cf")).lineLimit(expanded ? nil : 2)
                .padding(.trailing, !expanded && summary.count > 100 ? 36 : 0)
                .overlay(alignment: .bottomTrailing) { if !expanded && summary.count > 100 { Button("More") { expanded = true }.font(.system(size: 14, weight: .semibold)).frame(width: 44, height: 44).offset(y: 8) } }
            if expanded { Button("Less") { expanded = false }.font(.system(size: 14, weight: .semibold)).frame(minHeight: 36) }
        }
    }
}
struct TitleArtworkBackdrop: View {
    let path: String?
    let name: String
    var body: some View {
        Artwork(path: path, title: name).frame(height: 380)
            .overlay(LinearGradient(stops: [.init(color: .clear, location: 0.2), .init(color: .black.opacity(1.0 / 15), location: 0.45), .init(color: .black.opacity(13.0 / 15), location: 0.75), .init(color: .black, location: 1)], startPoint: .top, endPoint: .bottom)).ignoresSafeArea(edges: .top)
    }
}
