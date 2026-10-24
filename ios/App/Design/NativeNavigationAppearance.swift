import SwiftUI
import UIKit

/// SwiftUI onAppear can run during an interactive transition. Publish shell
/// visibility only once UIKit finishes presenting the owning destination.
@MainActor private struct NativeNavigationAppearance: UIViewControllerRepresentable {
    let onPresented: @MainActor () -> Void
    func makeUIViewController(context: Context) -> Controller {
        let controller = Controller()
        controller.onPresented = onPresented
        return controller
    }
    func updateUIViewController(_ controller: Controller, context: Context) {
        controller.onPresented = onPresented
    }
    final class Controller: UIViewController {
        var onPresented: (@MainActor () -> Void)?
        override func loadView() {
            let surface = UIView()
            surface.backgroundColor = .clear
            surface.isUserInteractionEnabled = false
            surface.isAccessibilityElement = false
            view = surface
        }
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            guard let navigation = navigationController else { return }
            // An offscreen ancestor must not change the visible destination's chrome.
            var ancestor: UIViewController? = self
            while let current = ancestor, current !== navigation.topViewController { ancestor = current.parent }
            guard ancestor != nil else { return }
            onPresented?()
            guard navigation.viewControllers.count > 1 else { return }
            // Keep UIKit's own delegates/transition physics. Custom SwiftUI chrome
            // must not leave the public content/edge gestures disabled after a push.
            for gesture in [navigation.interactivePopGestureRecognizer, navigation.interactiveContentPopGestureRecognizer].compactMap({ $0 }) {
                if !gesture.isEnabled { gesture.isEnabled = true }
            }
        }
    }
}

extension View {
    @MainActor func diaryNavigationAppearance(tab: AppTab, detail: Bool, router: AppRouter) -> some View {
        background(NativeNavigationAppearance { router.setDetailVisibility(detail, tab: tab) }.frame(width: 0, height: 0))
    }
}
