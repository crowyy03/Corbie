import SwiftUI
import UIKit

extension View {
    func keepsEdgeSwipeBack() -> some View {
        background(EdgeSwipeBack().frame(width: 0, height: 0))
    }
}

private struct EdgeSwipeBack: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> EdgeSwipeBackController {
        EdgeSwipeBackController()
    }

    func updateUIViewController(_ controller: EdgeSwipeBackController, context: Context) {}
}

private final class EdgeSwipeBackController: UIViewController, UIGestureRecognizerDelegate {
    private weak var gesture: UIGestureRecognizer?
    private weak var systemDelegate: UIGestureRecognizerDelegate?

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard let gesture = navigationController?.interactivePopGestureRecognizer, gesture.delegate !== self else {
            return
        }
        self.gesture = gesture
        systemDelegate = gesture.delegate
        gesture.delegate = self
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        guard let gesture, gesture.delegate === self else { return }
        gesture.delegate = systemDelegate
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let navigation = navigationController, navigation.transitionCoordinator == nil else { return false }
        return navigation.viewControllers.count > 1
    }
}
