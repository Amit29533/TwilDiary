import SwiftUI
import UIKit

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
    @State private var synopsisWidth: CGFloat = 0
    @State private var synopsisParts = SynopsisTextLayout.Parts(leading: "", continuation: "")
    private var synopsisText: String { summary.isEmpty ? "Add your own thoughts in Notes." : summary }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 15) {
                Artwork(path: poster, title: name, initialsOnly: false).frame(width: 114, height: 171).clipShape(RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 0) {
                    Text(name).font(.system(size: 24, weight: .bold)).tracking(-1.08).fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("title-hero-name")
                    Text([year.map(String.init) ?? "—", category, runtime.map { series ? "\($0) min per episode" : "\($0) min" }].compactMap { $0 }.joined(separator: " · ")).font(.system(size: 14.4)).lineSpacing(4.3).foregroundStyle(.secondary).frame(minHeight: 21.6, alignment: .top).padding(.top, 14)
                    InlineFlowLayout {
                        HStack(spacing: 5) { Image(systemName: "star.fill").font(.system(size: 20)).foregroundStyle(.yellow); Text(score.map { $0.formatted(.number.precision(.fractionLength(1))) } ?? "—").foregroundStyle(.yellow); Text("TMDb").font(.system(size: 14.4)).foregroundStyle(.secondary) }.frame(minHeight: 44)
                        personalRating
                    }.font(.system(size: 15.2)).padding(.top, 14)
                    synopsisLead.padding(.top, 16)
                        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width in
                            synopsisWidth = width; measureSynopsis()
                        }
                }.padding(.top, 14)
            }
            if expanded && !synopsisParts.continuation.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(synopsisParts.continuation.trimmingCharacters(in: .whitespacesAndNewlines))
                        .font(.system(size: 15.04)).lineSpacing(6).foregroundStyle(Color(webHex: "#c5c0cf"))
                        .frame(maxWidth: .infinity, alignment: .leading).fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("title-synopsis-continuation")
                    Button("Less") { setExpanded(false) }.font(.system(size: 14, weight: .semibold)).frame(minHeight: 44)
                }.frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .contain).accessibilityIdentifier("title-synopsis-expanded")
                    .transition(reduceMotion ? .identity : .opacity.combined(with: .offset(y: 6)))
            }
        }.padding(.top, 82).onChange(of: synopsisText) { _, _ in measureSynopsis() }
    }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var synopsisLead: some View {
        let hasOverflow = !synopsisParts.continuation.isEmpty
        return Text(synopsisParts.leading.isEmpty ? synopsisText : synopsisParts.leading.trimmingCharacters(in: .whitespacesAndNewlines) + (expanded || !hasOverflow ? "" : "…"))
            .font(.system(size: 15.04)).lineSpacing(6).foregroundStyle(Color(webHex: "#c5c0cf"))
            .lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, 36)
            .accessibilityIdentifier("title-synopsis-text")
            .overlay(alignment: .bottomTrailing) {
                if !expanded && hasOverflow {
                    Button("More") { setExpanded(true) }.font(.system(size: 14, weight: .semibold))
                        .frame(width: 44, height: 44).offset(y: 8)
                }
            }
    }
    private func setExpanded(_ value: Bool) {
        withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.88)) { expanded = value }
    }
    private func measureSynopsis() {
        guard synopsisWidth > 36 else { return }
        synopsisParts = SynopsisTextLayout.split(synopsisText, width: synopsisWidth - 36)
    }

}
struct TitleArtworkBackdrop: View {
    let path: String?
    let name: String
    var topExtension: CGFloat = 0
    var body: some View {
        ZStack {
            LinearGradient(stops: [.init(color: Color(webHex: "#3c2c48"), location: 0), .init(color: Color(webHex: "#473c37"), location: 0.45), .init(color: Color(webHex: "#253b3b"), location: 1)], startPoint: .topLeading, endPoint: .bottomTrailing)
            if let path { Artwork(path: path, title: name) }
        }.frame(height: 380 + topExtension)
            .overlay(LinearGradient(stops: [.init(color: .clear, location: 0.2), .init(color: .black.opacity(1.0 / 15), location: 0.45), .init(color: .black.opacity(13.0 / 15), location: 0.75), .init(color: .black, location: 1)], startPoint: .top, endPoint: .bottom)).offset(y: -topExtension).allowsHitTesting(false).accessibilityHidden(true)
    }
}
