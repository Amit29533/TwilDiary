import SwiftUI
import UIKit

/// A short, readable Undo window. Repeated actions and active recovery restart its lifetime.
struct UndoToast: View {
    let label: String
    @Environment(DiaryStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("theme") private var theme = DiaryTheme.twilight
    private struct Lifetime: Equatable {
        let notice: UUID
        let busy: Bool
        let recovering: Bool
    }
    var body: some View {
        HStack(spacing: 8) {
            DiaryIcon(name: "check", size: 17).foregroundStyle(Color(webHex: "#79d8bc"))
            Text(label).font(.system(size: 13, weight: .semibold)).foregroundStyle(Color(webHex: "#f5f5f7"))
                .lineLimit(2).fixedSize(horizontal: false, vertical: true).layoutPriority(1)
            Button("Undo") { Task { await store.undo() } }
                .font(.system(size: 13, weight: .semibold)).foregroundStyle(theme.accent)
                .frame(minWidth: 44, minHeight: 44).disabled(store.writesBlocked)
            Button { store.dismissUndo() } label: { DiaryIcon(name: "x", size: 14).frame(width: 32, height: 44) }
                .foregroundStyle(Color(webHex: "#c5c0cf")).accessibilityLabel("Dismiss undo")
        }.buttonStyle(.plain).padding(.horizontal, 12).padding(.vertical, 2)
            .background(.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 22))
            .glassEffect(in: RoundedRectangle(cornerRadius: 22))
            .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
            .accessibilityIdentifier("undo-toast")
            .task(id: Lifetime(notice: store.undoNoticeID, busy: store.busy, recovering: store.needsMutationRefresh)) {
                guard !store.busy, !store.needsMutationRefresh else { return }
                let notice = store.undoNoticeID
                do { try await Task.sleep(for: .seconds(UIAccessibility.isVoiceOverRunning ? 8 : 4.5)) } catch { return }
                guard !Task.isCancelled, notice == store.undoNoticeID else { return }
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) { store.dismissUndo() }
            }
    }
}
