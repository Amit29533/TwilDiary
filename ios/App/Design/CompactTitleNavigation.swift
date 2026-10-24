import SwiftUI
import TwilDiaryCore

/// Content-sized identity inside the system navigation bar. The system retains
/// Back/interactive transitions and owns safe-area geometry during scrolling.
struct CompactTitleNavigation: View {
    let name: String
    let poster: String?
    var body: some View {
        HStack(spacing: 8) {
            Artwork(path: poster, title: name, initialsOnly: false).frame(width: 28, height: 28).clipShape(RoundedRectangle(cornerRadius: 9))
            Text(name).font(.system(size: 15, weight: .semibold)).lineLimit(1).truncationMode(.tail)
        }.frame(maxWidth: .infinity).accessibilityElement(children: .ignore).accessibilityLabel(name).accessibilityIdentifier("compact-title-navigation")
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
