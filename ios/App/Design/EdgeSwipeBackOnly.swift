import SwiftUI
import UIKit

/// Horizontal content controls must not start iOS 26's full-content navigation pop.
/// Keep the standard leading-edge Back gesture and navigation Back button intact.
struct EdgeSwipeBackOnly: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller { Controller() }
    func updateUIViewController(_ controller: Controller, context: Context) { }
    final class Controller: UIViewController {
        private weak var gesture: UIGestureRecognizer?
        private var previous: Bool?
        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            guard let navigation = navigationController, let gesture = navigation.interactiveContentPopGestureRecognizer else { return }
            self.gesture = gesture; previous = gesture.isEnabled; gesture.isEnabled = false
        }
        override func viewWillDisappear(_ animated: Bool) {
            if let previous { gesture?.isEnabled = previous }
            previous = nil; gesture = nil
            super.viewWillDisappear(animated)
        }
    }
}
