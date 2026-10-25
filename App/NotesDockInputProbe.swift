#if DEBUG
import SwiftUI
import UIKit

/// Opt-in, read-only evidence for the lost Notes dock touch in run40143257947.
/// Never recognizes a gesture, changes state, retries a tap or writes user data.
struct NotesDockInputProbe: UIViewRepresentable {
    let visible: Bool
    let expanded: Bool
    func makeUIView(context: Context) -> ProbeView { ProbeView(frame: .zero) }
    func updateUIView(_ view: ProbeView, context: Context) {
        let state = "visible=\(visible) expanded=\(expanded)"
        if view.lastState != state {
            view.lastState = state
            NSLog("TayyaNotesDock render %@", state)
        }
    }

    final class ProbeView: UIView {
        private weak var observedWindow: UIWindow?
        private var observer: TouchObserver?
        var lastState: String?

        override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false
            isAccessibilityElement = false
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if observedWindow === window { return }
            disconnect()
            guard let window else { return }
            let observer = TouchObserver(target: nil, action: nil)
            observer.probe = self
            window.addGestureRecognizer(observer)
            self.observer = observer
            observedWindow = window
        }

        func disconnect() {
            if let observer { observedWindow?.removeGestureRecognizer(observer) }
            observer = nil; observedWindow = nil
        }
    }

    static func dismantleUIView(_ view: ProbeView, coordinator: ()) { view.disconnect() }

    final class TouchObserver: UIGestureRecognizer, UIGestureRecognizerDelegate {
        weak var probe: ProbeView?
        private var receivedTouches = 0

        override init(target: Any?, action: Selector?) {
            super.init(target: target, action: action)
            cancelsTouchesInView = false
            delaysTouchesBegan = false
            delaysTouchesEnded = false
            delegate = self
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        override func canPrevent(_ other: UIGestureRecognizer) -> Bool { false }
        override func canBePrevented(by other: UIGestureRecognizer) -> Bool { false }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard let probe, let window = probe.window else { return false }
            let point = touch.location(in: window)
            let dock = probe.convert(probe.bounds, to: window)
            // Keep only touches in this control; other document/ink is untouched.
            guard dock.contains(point) else { return false }
            receivedTouches += 1
            var ancestry: [String] = []
            var current = touch.view
            while let view = current, ancestry.count < 9 {
                let gestures = (view.gestureRecognizers ?? []).prefix(8).map {
                    "\(type(of: $0)):state=\($0.state.rawValue),enabled=\($0.isEnabled),cancel=\($0.cancelsTouchesInView)"
                }.joined(separator: ",")
                ancestry.append("\(type(of: view)) frame=\(view.convert(view.bounds, to: window)) gestures=[\(gestures)]")
                current = view.superview
            }
            NSLog("TayyaNotesDock touch count=%d time=%.6f point=%@ dock=%@ scene=%@ hit=%@",
                  receivedTouches, touch.timestamp, String(describing: point), String(describing: dock),
                  String(describing: window.windowScene?.activationState), ancestry.joined(separator: " > "))
            return false
        }
    }
}
#endif
