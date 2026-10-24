import SwiftUI

/// Source theme surfaces; artwork is never blurred or recolored by these controls.
struct DiaryPanelModifier: ViewModifier {
    var padding: CGFloat = 16
    var radius: CGFloat = 22
    var accentBorder = false
    @AppStorage("theme") private var theme = DiaryTheme.twilight
    func body(content: Content) -> some View {
        content.padding(padding)
            .background {
                RoundedRectangle(cornerRadius: theme == .glass ? 24 : radius).fill(Color(webHex: theme == .glass ? "#101013eb" : "#111115"))
                    .overlay {
                        if theme == .glass { RoundedRectangle(cornerRadius: 24).fill(LinearGradient(colors: [.white.opacity(5.0 / 255), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)) }
                    }
            }
            .overlay(RoundedRectangle(cornerRadius: theme == .glass ? 24 : radius).strokeBorder(theme == .glass ? .white.opacity(28.0 / 255) : accentBorder ? theme.accent.opacity(0.2) : .white.opacity(0.13)))
            .shadow(color: .black.opacity(theme == .glass ? 0.3 : 0), radius: theme == .glass ? 16 : 0, y: theme == .glass ? 12 : 0)
    }
}
struct DiaryControlSurface<SurfaceShape: Shape>: View {
    let shape: SurfaceShape
    var selected = false
    var field = false
    @AppStorage("theme") private var theme = DiaryTheme.twilight
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var body: some View {
        ZStack {
            if theme == .glass {
                if reduceTransparency { shape.fill(Color(webHex: "#222226")) }
                else { shape.fill(.clear).glassEffect(in: shape).overlay(shape.fill(Color(webHex: "#19191d").opacity(0.16))) }
                shape.fill(LinearGradient(stops: [.init(color: .white.opacity(0.065), location: 0), .init(color: .white.opacity(0.012), location: 0.5), .init(color: .white.opacity(0.047), location: 1)], startPoint: .topLeading, endPoint: .bottomTrailing))
                shape.fill(RadialGradient(colors: [.white.opacity(0.12), .clear], center: .topLeading, startRadius: 0, endRadius: 180))
                shape.stroke(.white.opacity(selected ? 0.32 : 0.18), lineWidth: 1)
            } else {
                shape.fill(selected ? theme.accent.opacity(0.09) : Color(webHex: field ? "#111115" : "#131219"))
                shape.stroke(selected ? theme.accent.opacity(0.45) : Color(webHex: field ? "#ffffff21" : "#34313f"), lineWidth: 1)
            }
        }.allowsHitTesting(false)
    }
}

/// Phone navigation tokens from tokens.css and the Liquid Glass overrides in themes.css.
struct DiaryNavigationSurface: View {
    @AppStorage("theme") private var theme = DiaryTheme.twilight
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var body: some View {
        ZStack {
            if reduceTransparency {
                Capsule().fill(Color(webHex: theme == .glass ? "#19191d" : "#111115"))
            } else {
                Capsule().fill(.ultraThinMaterial)
                if theme == .glass {
                    Capsule().fill(Color(webHex: "#242428a8"))
                    Capsule().fill(LinearGradient(stops: [
                        .init(color: Color(webHex: "#ffffff14"), location: 0),
                        .init(color: Color(webHex: "#ffffff03"), location: 0.48),
                        .init(color: Color(webHex: "#ffffff09"), location: 1)
                    ], startPoint: .topLeading, endPoint: .bottomTrailing))
                } else {
                    Capsule().fill(LinearGradient(colors: [Color(webHex: "#111518cf"), Color(webHex: "#080b0ee8")], startPoint: .top, endPoint: .bottom))
                }
            }
            if theme == .glass {
                Capsule().fill(RadialGradient(colors: [Color(webHex: "#ffffff1c"), .clear], center: UnitPoint(x: 0.1, y: 0), startRadius: 0, endRadius: 245))
                Capsule().fill(RadialGradient(colors: [Color(webHex: "#b4d4ff0c"), .clear], center: .bottomTrailing, startRadius: 0, endRadius: 160))
            }
            Capsule().strokeBorder(Color(webHex: theme == .glass ? "#ffffff30" : "#ffffff26"))
            Capsule().strokeBorder(LinearGradient(colors: [Color(webHex: theme == .glass ? "#ffffff3b" : "#ffffff20"), .clear, Color(webHex: theme == .glass ? "#ffffff0c" : "#ffffff08")], startPoint: .top, endPoint: .bottom))
        }.clipShape(Capsule()).shadow(color: .black.opacity(theme == .glass ? 0.6 : 0.53), radius: 16, y: 8).allowsHitTesting(false)
    }
}

struct DiaryNavigationSelection: View {
    let selected: Bool
    @AppStorage("theme") private var theme = DiaryTheme.twilight
    var body: some View {
        if selected {
            ZStack {
                if theme == .glass {
                    Capsule().fill(LinearGradient(colors: [Color(webHex: "#ffffff14"), Color(webHex: "#ffffff09")], startPoint: .topLeading, endPoint: .bottomTrailing))
                    Capsule().fill(RadialGradient(colors: [Color(webHex: "#ffffff2b"), .clear], center: UnitPoint(x: 0.2, y: 0), startRadius: 0, endRadius: 72))
                } else {
                    Capsule().fill(LinearGradient(colors: [theme.accent.opacity(0.19), theme.accent.opacity(0.09)], startPoint: .topLeading, endPoint: .bottomTrailing))
                }
                Capsule().strokeBorder(theme == .glass ? Color(webHex: "#ffffff12") : theme.accent.opacity(0.15))
                Capsule().strokeBorder(LinearGradient(colors: [theme == .glass ? Color(webHex: "#ffffff38") : theme.accent.opacity(0.3), .clear], startPoint: .top, endPoint: .center))
            }.allowsHitTesting(false)
        }
    }
}
