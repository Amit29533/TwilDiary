import SwiftUI
import UIKit

/// A real native adjustable control with a 44pt touch area and transparent artwork.
/// Explicit track tracking avoids relying on a nearly invisible SwiftUI slider thumb.
@MainActor struct EpisodeRangeInput: UIViewRepresentable {
    let value: Double
    let maximum: Int
    let enabled: Bool
    let label: String
    let valueText: String
    let identifier: String
    let onChange: @MainActor (Double) -> Void
    let onCommit: @MainActor (Double) -> Void
    let onCancel: @MainActor () -> Void
    func makeUIView(context: Context) -> TrackSlider {
        let control = TrackSlider()
        let clear = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1)).image { _ in }
        let states: [UIControl.State] = [.normal, .highlighted, .disabled]
        for state in states {
            control.setThumbImage(clear, for: state)
            control.setMinimumTrackImage(clear, for: state)
            control.setMaximumTrackImage(clear, for: state)
        }
        control.backgroundColor = .clear; control.minimumValue = 0
        control.isAccessibilityElement = true; control.accessibilityTraits = .adjustable
        updateUIView(control, context: context)
        return control
    }
    func updateUIView(_ control: TrackSlider, context: Context) {
        control.maximumValue = Float(max(1, maximum)); control.isEnabled = enabled
        control.setValue(Float(value), animated: false)
        control.accessibilityLabel = label; control.accessibilityValue = valueText; control.accessibilityIdentifier = identifier
        control.changed = onChange; control.committed = onCommit; control.cancelled = onCancel
    }
    final class TrackSlider: UISlider {
        var changed: (@MainActor (Double) -> Void)?
        var committed: (@MainActor (Double) -> Void)?
        var cancelled: (@MainActor () -> Void)?
        override var intrinsicContentSize: CGSize { CGSize(width: UIView.noIntrinsicMetric, height: 44) }
        override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
            guard isEnabled else { return false }; updateCount(at: touch.location(in: self)); return true
        }
        override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
            updateCount(at: touch.location(in: self)); return true
        }
        override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
            if let touch { updateCount(at: touch.location(in: self)) }
            committed?(Double(value))
        }
        override func cancelTracking(with event: UIEvent?) { cancelled?() }
        override func accessibilityIncrement() { adjust(by: 1) }
        override func accessibilityDecrement() { adjust(by: -1) }
        private func updateCount(at point: CGPoint) {
            guard bounds.width > 0 else { return }
            let fraction = min(1, max(0, point.x / bounds.width))
            value = Float((Double(fraction) * Double(maximumValue)).rounded())
            changed?(Double(value))
        }
        private func adjust(by amount: Float) {
            guard isEnabled else { return }
            value = min(maximumValue, max(minimumValue, value + amount))
            changed?(Double(value)); committed?(Double(value))
        }
    }
}
