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
                else { shape.fill(.ultraThinMaterial).overlay(shape.fill(Color(webHex: "#28282c").opacity(0.5))) }
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
