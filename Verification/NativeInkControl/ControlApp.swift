// Diagnostic control only. This target is never linked into or distributed as Tayya.
import UIKit
import PencilKit

@main final class ControlApp: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting session: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: "Native control", sessionRole: session.role)
        config.delegateClass = ControlScene.self
        return config
    }
}

final class ControlScene: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let scene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: scene)
        window.rootViewController = ControlController()
        self.window = window
        window.makeKeyAndVisible()
    }
}

// Match the actual failed compact viewport/zoom and seeded native drawing.
// There is no SwiftUI, PDF, model observer, PKCanvasViewDelegate or persistence.
final class ControlCanvas: PKCanvasView {
    private let noKeyboard = UIView(frame: .zero)
    private var previousSize = CGSize.zero
    override var inputView: UIView? { noKeyboard }
    override var accessibilityValue: String? {
        get { String(drawing.strokes.count) }
        set { super.accessibilityValue = newValue }
    }
    override func layoutSubviews() {
        let changed = bounds.size != previousSize
        previousSize = bounds.size
        super.layoutSubviews()
        guard changed, bounds.width > 0 else { return }
        let scale = bounds.width / 650
        minimumZoomScale = min(0.1, scale)
        maximumZoomScale = 4
        zoomScale = scale
        contentSize = CGSize(width: 650 * scale, height: 900 * scale)
        contentInset = .zero
        contentOffset = .zero
    }
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil { becomeFirstResponder() }
    }
}

final class ControlController: UIViewController, UIColorPickerViewControllerDelegate {
    private let canvas = ControlCanvas()
    private let status = UILabel()
    private let controls = UIStackView()
    private var ink = PKInkingTool.InkType.pen
    private var color = UIColor(red: 0.07, green: 0.25, blue: 0.22, alpha: 1)
    private var picker: UIColorPickerViewController?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        controls.axis = .horizontal; controls.spacing = 16
        for (title, id, action) in [("Pencil", "controlPencil", #selector(selectPencil)),
                                     ("Color", "controlColor", #selector(selectColor))] {
            let button = UIButton(type: .system)
            button.setTitle(title, for: .normal); button.accessibilityIdentifier = id
            button.addTarget(self, action: action, for: .touchUpInside)
            button.widthAnchor.constraint(greaterThanOrEqualToConstant: 88).isActive = true
            button.heightAnchor.constraint(equalToConstant: 44).isActive = true
            controls.addArrangedSubview(button)
        }
        status.accessibilityIdentifier = "controlTool"
        status.font = .systemFont(ofSize: 14)
        view.addSubview(controls); view.addSubview(status); view.addSubview(canvas)
        canvas.backgroundColor = UIColor(red: 1, green: 0.992, blue: 0.94, alpha: 1)
        canvas.drawingPolicy = .anyInput
        canvas.contentInsetAdjustmentBehavior = .never
        canvas.semanticContentAttribute = .forceLeftToRight
        canvas.bounces = false; canvas.clipsToBounds = true
        canvas.panGestureRecognizer.minimumNumberOfTouches = 2
        canvas.isAccessibilityElement = true
        canvas.accessibilityIdentifier = "controlCanvas"
        canvas.accessibilityLabel = "Isolated native PencilKit control"
        let locations = [CGPoint(x: 70, y: 110), CGPoint(x: 200, y: 150),
                         CGPoint(x: 340, y: 100), CGPoint(x: 480, y: 145)]
        let points = locations.enumerated().map { index, point in
            PKStrokePoint(location: point, timeOffset: Double(index) * 0.1, size: CGSize(width: 4, height: 4),
                          opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
        }
        canvas.drawing = PKDrawing(strokes: [PKStroke(ink: PKInk(.pen, color: color),
            path: PKStrokePath(controlPoints: points, creationDate: Date()))])
        applyTool()
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        controls.frame = CGRect(x: 62, y: 80, width: 300, height: 44)
        status.frame = CGRect(x: 62, y: 132, width: view.bounds.width - 124, height: 32)
        if view.bounds.width > view.bounds.height {
            canvas.frame = CGRect(x: 62, y: 235.33333333333334, width: 367.3333333333333, height: 88.66666666666666)
        } else {
            // The failing app creates this SAME canvas in portrait before
            // rotating it. A landscape-only fresh canvas misses that boundary.
            canvas.frame = CGRect(x: 0, y: 670.6666666666666, width: 440, height: 147.33333333333331)
        }
    }
    private func applyTool() {
        canvas.tool = PKInkingTool(ink, color: color, width: 8)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        status.text = String(format: "%@ rgba:%.4f,%.4f,%.4f,%.4f; width8", ink.rawValue, r, g, b, a)
        status.accessibilityValue = status.text
    }
    @objc private func selectPencil() { ink = .pencil; applyTool() }
    @objc private func selectColor() {
        let picker = UIColorPickerViewController()
        picker.supportsAlpha = false; picker.selectedColor = color; picker.delegate = self
        picker.view.accessibilityIdentifier = "controlPicker"
        let done = UIButton(type: .system)
        done.setTitle("Done", for: .normal); done.accessibilityIdentifier = "controlCloseColor"
        done.addTarget(self, action: #selector(closeColor), for: .touchUpInside)
        done.translatesAutoresizingMaskIntoConstraints = false; picker.view.addSubview(done)
        NSLayoutConstraint.activate([
            done.topAnchor.constraint(equalTo: picker.view.safeAreaLayoutGuide.topAnchor, constant: 8),
            done.trailingAnchor.constraint(equalTo: picker.view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            done.widthAnchor.constraint(greaterThanOrEqualToConstant: 44), done.heightAnchor.constraint(equalToConstant: 44)
        ])
        self.picker = picker; present(picker, animated: true)
    }
    @objc private func closeColor() { picker?.dismiss(animated: true); picker = nil }
    func colorPickerViewController(_ viewController: UIColorPickerViewController,
                                   didSelect selectedColor: UIColor, continuously: Bool) {
        color = selectedColor; applyTool()
    }
    func colorPickerViewControllerDidFinish(_ viewController: UIColorPickerViewController) { closeColor() }
}
