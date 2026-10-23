import SwiftUI

@main
struct TwilDiaryApp: App {
    var body: some Scene {
        WindowGroup {
            FoundationVerificationView()
                .preferredColorScheme(.dark)
        }
    }
}

/// Explicit pipeline proof. Product screens are implemented only after the foundation gate passes.
private struct FoundationVerificationView: View {
    @State private var verified = false
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "sparkle")
                .font(.system(size: 48))
                .foregroundStyle(Color(red: 183 / 255, green: 149 / 255, blue: 246 / 255))
            Text("TwilDiary").font(.largeTitle.bold()).accessibilityIdentifier("foundation-title")
            Text("Native build verification").foregroundStyle(.secondary)
            Button(verified ? "Interaction verified" : "Verify interaction") { verified = true }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("foundation-verify")
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .tint(Color(red: 183 / 255, green: 149 / 255, blue: 246 / 255))
    }
}
