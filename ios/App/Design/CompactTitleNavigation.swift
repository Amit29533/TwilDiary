import SwiftUI
import TwilDiaryCore

/// Content-sized identity inside the system navigation bar. The system retains
/// Back/interactive transitions and owns safe-area geometry during scrolling.
struct CompactTitleNavigation: View {
    let name: String
    let poster: String?
    var progress: CGFloat = 1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        HStack(spacing: 8) {
            Artwork(path: poster, title: name, initialsOnly: false).frame(width: 28, height: 28).clipShape(RoundedRectangle(cornerRadius: 9))
            Text(name).font(.system(size: 15, weight: .semibold)).lineLimit(1).truncationMode(.tail)
        }.frame(height: 28)
            .opacity(Double(progress))
            .offset(y: reduceMotion ? 0 : (1 - progress) * 6)
            .accessibilityElement(children: .ignore).accessibilityLabel(name).accessibilityIdentifier("compact-title-navigation")
            .accessibilityHidden(progress < 0.5)
    }
}

/// Ignore the crossing band: toolbar layout and a reversing scroll must not
/// repeatedly insert/remove the title at the same single-pixel threshold.
enum CompactHeaderTransition {
    static func progress(nameBottom: CGFloat) -> CGFloat {
        guard nameBottom.isFinite else { return 0 }
        // Fade over 80 points of real scroll. Quantization limits body work;
        // there is no animation repeatedly chasing a reversing finger.
        let value = min(1, max(0, (48 - nameBottom) / 80))
        return (value * 32).rounded() / 32
    }
}

struct CompactHeaderBackdrop: View {
    let progress: CGFloat
    let topInset: CGFloat
    var body: some View {
        Rectangle().fill(.ultraThinMaterial)
            .overlay(.black.opacity(0.22))
            .opacity(Double(progress))
            .frame(height: topInset).offset(y: -topInset)
            .allowsHitTesting(false).accessibilityHidden(true)
    }
}

struct TitleShareAction: View {
    let name: String
    let kind: MediaKind
    let id: Int?
    var body: some View {
        Group {
            if let id, id > 0, let url = URL(string: "https://www.themoviedb.org/\(kind == .tv ? "tv" : "movie")/\(id)") {
                ShareLink(item: url, preview: SharePreview(name)) { Image(systemName: "square.and.arrow.up") }
            } else {
                ShareLink(item: name) { Image(systemName: "square.and.arrow.up") }
            }
        }.accessibilityLabel("Share " + name).accessibilityIdentifier("title-share")
    }
}
