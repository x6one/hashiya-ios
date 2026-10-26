// Diagnostic control only. This target is never linked into or distributed as Tayya.
import UIKit
import PencilKit
import PDFKit

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
// There is no SwiftUI, model observer, PKCanvasViewDelegate or persistence.
class ControlCanvasBase: PKCanvasView {
    private let noKeyboard = UIView(frame: .zero)
    override var inputView: UIView? { noKeyboard }
    override var accessibilityValue: String? {
        get { String(drawing.strokes.count) }
        set { super.accessibilityValue = newValue }
    }
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil { becomeFirstResponder() }
    }
}

final class ControlCanvas: ControlCanvasBase {
    private var previousSize = CGSize.zero
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
}

final class ControlInkCount: UILabel {
    weak var canvas: PKCanvasView?
    weak var document: PKCanvasView?
    weak var notes: PKCanvasView?
    override var accessibilityValue: String? {
        get { canvas.map { String($0.drawing.strokes.count) } }
        set { super.accessibilityValue = newValue }
    }
    override var accessibilityLabel: String? {
        get {
            func state(_ canvas: PKCanvasView?) -> String {
                guard let canvas else { return "absent" }
                return "id=\(ObjectIdentifier(canvas)); window=\(canvas.window != nil); responder=\(canvas.isFirstResponder)"
            }
            return "document=[\(state(document))]; notes=[\(state(notes))]"
        }
        set { super.accessibilityLabel = newValue }
    }
}

final class ControlController: UIViewController, UIColorPickerViewControllerDelegate, PDFPageOverlayViewProvider {
    private lazy var canvas = ControlCanvas()
    private let documentCanvas = ControlCanvasBase(frame: CGRect(x: 0, y: 0, width: 612, height: 792))
    private let pdf = PDFView()
    private let count = ControlInkCount()
    private let twoCanvases = ProcessInfo.processInfo.arguments.contains("--two-canvases")
    private var notesVisible = false
    private let status = UILabel()
    private let controls = UIStackView()
    private var ink = PKInkingTool.InkType.pen
    private var color = UIColor(red: 0.07, green: 0.25, blue: 0.22, alpha: 1)
    private var picker: UIColorPickerViewController?
    private var activeCanvas: PKCanvasView { twoCanvases && !notesVisible ? documentCanvas : canvas }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        controls.axis = .horizontal; controls.spacing = twoCanvases ? 8 : 16
        var actions: [(String, String, Selector)] = [("Pencil", "controlPencil", #selector(selectPencil)),
                                                    ("Color", "controlColor", #selector(selectColor))]
        if twoCanvases {
            actions += [("Undo", "controlUndo", #selector(undoInk)), ("Redo", "controlRedo", #selector(redoInk)),
                        ("Fit", "controlFit", #selector(fitDocument)), ("Notes", "controlShowNotes", #selector(showNotes))]
            controls.distribution = .fillEqually
        }
        for (title, id, action) in actions {
            let button = UIButton(type: .system)
            button.setTitle(title, for: .normal); button.accessibilityIdentifier = id
            button.addTarget(self, action: action, for: .touchUpInside)
            button.widthAnchor.constraint(greaterThanOrEqualToConstant: twoCanvases ? 44 : 88).isActive = true
            button.heightAnchor.constraint(equalToConstant: 44).isActive = true
            controls.addArrangedSubview(button)
        }
        status.accessibilityIdentifier = "controlTool"
        status.font = .systemFont(ofSize: 14)
        view.addSubview(controls); view.addSubview(status)
        count.accessibilityIdentifier = "controlStrokeCount"; count.text = "Native stroke count"
        count.font = .systemFont(ofSize: 12); view.addSubview(count)
        if twoCanvases { configureDocument() }
        else { notesVisible = true; configureNotes() }
        applyTool()
    }
    private func configureNotes() {
        view.addSubview(canvas)
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
        count.canvas = canvas; count.notes = canvas
    }
    private func configureDocument() {
        documentCanvas.contentSize = documentCanvas.bounds.size
        documentCanvas.isScrollEnabled = false; documentCanvas.isOpaque = false
        documentCanvas.backgroundColor = .clear; documentCanvas.drawingPolicy = .anyInput
        documentCanvas.accessibilityIdentifier = "controlDocumentCanvas"
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
        let bytes = renderer.pdfData { context in
            for index in 1...3 {
                context.beginPage(); UIColor.white.setFill(); context.cgContext.fill(CGRect(x: 0, y: 0, width: 612, height: 792))
                ("Native control page \(index)" as NSString).draw(at: CGPoint(x: 40, y: 40), withAttributes: [.font: UIFont.systemFont(ofSize: 22)])
            }
        }
        pdf.pageOverlayViewProvider = self
        pdf.document = PDFDocument(data: bytes); pdf.autoScales = true
        pdf.displayMode = .singlePageContinuous; pdf.isInMarkupMode = true
        NotificationCenter.default.addObserver(self, selector: #selector(documentPageChanged), name: .PDFViewPageChanged, object: pdf)
        NotificationCenter.default.addObserver(self, selector: #selector(documentPageChanged), name: .PDFViewVisiblePagesChanged, object: pdf)
        pdf.accessibilityIdentifier = "controlPDF"; view.addSubview(pdf)
        count.canvas = documentCanvas; count.document = documentCanvas
    }
    func pdfView(_ view: PDFView, overlayViewFor page: PDFPage) -> UIView? {
        view.document?.index(for: page) == 0 ? documentCanvas : nil
    }
    func pdfView(_ view: PDFView, willDisplayOverlayView overlayView: UIView, for page: PDFPage) {
        // Preserve the preceding document's active native drawing context.
        if documentCanvas.window != nil { documentCanvas.becomeFirstResponder() }
    }
    @objc private func documentPageChanged() {
        guard let page = pdf.currentPage, pdf.document?.index(for: page) == 0, documentCanvas.window != nil else { return }
        documentCanvas.becomeFirstResponder()
    }
    deinit { NotificationCenter.default.removeObserver(self) }
    @objc private func showNotes() {
        guard !notesVisible else { return }
        notesVisible = true; ink = .pen; color = UIColor(red: 0.07, green: 0.25, blue: 0.22, alpha: 1)
        configureNotes(); applyTool(); view.setNeedsLayout()
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        controls.frame = twoCanvases ? CGRect(x: 16, y: 80, width: view.bounds.width - 32, height: 44)
            : CGRect(x: 62, y: 80, width: 300, height: 44)
        status.frame = CGRect(x: 62, y: 132, width: view.bounds.width - 124, height: 32)
        count.frame = CGRect(x: 16, y: 164, width: 200, height: 20)
        if twoCanvases {
            if !notesVisible { pdf.frame = CGRect(x: 0, y: 188, width: view.bounds.width, height: view.bounds.height - 198) }
            else if view.bounds.width > view.bounds.height { pdf.frame = CGRect(x: 445.3333333333333, y: 125.33333333333333, width: 448.66666666666663, height: 198.66666666666666) }
            else { pdf.frame = CGRect(x: 0, y: 188, width: view.bounds.width, height: 466.6666666666666) }
        }
        guard notesVisible else { return }
        if view.bounds.width > view.bounds.height {
            canvas.frame = CGRect(x: 62, y: 235.33333333333334, width: 367.3333333333333, height: 88.66666666666666)
        } else {
            // The failing app creates this SAME canvas in portrait before
            // rotating it. A landscape-only fresh canvas misses that boundary.
            canvas.frame = CGRect(x: 0, y: 670.6666666666666, width: 440, height: 147.33333333333331)
        }
    }
    private func applyTool() {
        activeCanvas.tool = PKInkingTool(ink, color: color, width: 8)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        status.text = String(format: "%@ rgba:%.4f,%.4f,%.4f,%.4f; width8", ink.rawValue, r, g, b, a)
        status.accessibilityValue = status.text
    }
    @objc private func selectPencil() { ink = .pencil; applyTool() }
    @objc private func undoInk() { activeCanvas.undoManager?.undo() }
    @objc private func redoInk() { activeCanvas.undoManager?.redo() }
    @objc private func fitDocument() { pdf.scaleFactor = pdf.scaleFactorForSizeToFit }
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
