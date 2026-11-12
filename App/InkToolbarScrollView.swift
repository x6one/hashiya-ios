import SwiftUI
import UIKit

// A delayed touch can start tracking a tool button before the rail's pan begins.
// Let the native scroll view cancel that button's tracking when a drag wins.
struct InkToolbarScrollView<Content: View>: UIViewControllerRepresentable {
    private let content: Content

    init(@ViewBuilder content: () -> Content) { self.content = content() }

    func makeUIViewController(context: Context) -> Controller {
        Controller(content: hostedContent(context.environment))
    }

    func updateUIViewController(_ controller: Controller, context: Context) {
        controller.update(content: hostedContent(context.environment))
    }

    static func dismantleUIViewController(_ controller: Controller, coordinator: ()) {
        controller.detach()
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiViewController: Controller,
                      context: Context) -> CGSize? {
        uiViewController.fittingSize(proposedWidth: proposal.width)
    }

    private func hostedContent(_ environment: EnvironmentValues) -> AnyView {
        AnyView(content.environment(\.self, environment)
            .fixedSize(horizontal: true, vertical: true))
    }

    final class Controller: UIViewController {
        private let scroll = RailScrollView()
        private let host: UIHostingController<AnyView>

        init(content: AnyView) {
            host = UIHostingController(rootView: content)
            super.init(nibName: nil, bundle: nil)
            host.sizingOptions = .intrinsicContentSize
            // The enclosing scroll view alone applies the viewport's safe area.
            host.safeAreaRegions = []
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override func loadView() {
            view = scroll
            scroll.backgroundColor = .clear
            scroll.semanticContentAttribute = .forceLeftToRight
            scroll.contentInsetAdjustmentBehavior = .automatic
            scroll.showsHorizontalScrollIndicator = false
            scroll.showsVerticalScrollIndicator = false
            scroll.alwaysBounceHorizontal = true
            scroll.accessibilityIdentifier = "inkToolbar"
            addChild(host)
            host.view.backgroundColor = .clear
            host.view.translatesAutoresizingMaskIntoConstraints = false
            scroll.addSubview(host.view)
            NSLayoutConstraint.activate([
                host.view.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
                host.view.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
                host.view.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
                host.view.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
                host.view.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor)
            ])
            host.didMove(toParent: self)
        }

        func update(content: AnyView) {
            host.rootView = content
            host.view.invalidateIntrinsicContentSize()
            viewIfLoaded?.setNeedsLayout()
        }

        func fittingSize(proposedWidth: CGFloat?) -> CGSize {
            loadViewIfNeeded()
            let ideal = host.sizeThatFits(in: UIView.layoutFittingExpandedSize)
            let width = proposedWidth ?? ideal.width
            return CGSize(width: width.isFinite ? width : ideal.width, height: ideal.height)
        }

        func detach() {
            if host.parent != nil {
                host.willMove(toParent: nil)
                host.view.removeFromSuperview()
                host.removeFromParent()
            }
            host.rootView = AnyView(EmptyView())
        }
    }
}

private final class RailScrollView: UIScrollView {
    override func touchesShouldCancel(in view: UIView) -> Bool {
        let inherited = super.touchesShouldCancel(in: view)
        let cancel = view is UIControl || inherited
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--test-margin-viewport") {
            let control = view as? UIControl
            NSLog("TayyaRescueRailCancel uptime=%f scroll=%@ pan=%@ view=%@ inherited=%d cancel=%d controlTracking=%d scrollTracking=%d dragging=%d",
                  ProcessInfo.processInfo.systemUptime, String(describing: ObjectIdentifier(self)),
                  String(describing: ObjectIdentifier(panGestureRecognizer)),
                  "\(type(of: view)):\(ObjectIdentifier(view))", inherited ? 1 : 0, cancel ? 1 : 0,
                  control?.isTracking == true ? 1 : 0, isTracking ? 1 : 0, isDragging ? 1 : 0)
        }
#endif
        return cancel
    }
}

