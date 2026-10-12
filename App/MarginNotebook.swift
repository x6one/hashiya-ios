import SwiftUI
import PencilKit

// Sheet coordinates never depend on the size of the split pane.
final class MarginCanvas: PKCanvasView {
    // Native UI diagnostics are available only to the dedicated regression test.
    override var accessibilityLabel: String? {
        get {
            let label = super.accessibilityLabel ?? ""
            guard ProcessInfo.processInfo.arguments.contains("--test-margin-viewport") else { return label }
            func describe(_ view: UIView, depth: Int) -> String {
                let own = "\(type(of: view)) frame=\(view.frame) bounds=\(view.bounds) transform=\(view.transform) hidden=\(view.isHidden)"
                return own + (depth > 0 ? view.subviews.map { describe($0, depth: depth - 1) }.joined(separator: " | ") : "")
            }
            return label + "; zoom=\(zoomScale) content=\(contentSize) offset=\(contentOffset) inset=\(contentInset) ink=\(drawing.bounds) sheet=\(sheetSize) views=" + subviews.map { describe($0, depth: 2) }.joined(separator: " | ")
        }
        set { super.accessibilityLabel = newValue }
    }
    var sheetSize = CGSize(width: 650, height: 900)
    var followsFit = true
    private var fitsWidth = true
    private var previousBounds = CGSize.zero
    private var updatingViewport = false
    var usingTool = false
    private var pendingSheetSize: CGSize?
    func setSheetSize(_ size: CGSize) {
        guard size != sheetSize else { return }
        if usingTool { pendingSheetSize = size; return }
        sheetSize = size
        // UIScrollView's content size is in the current zoomed coordinate space.
        // Never reset PencilKit to zoom 1 while it is committing a stroke.
        contentSize = CGSize(width: size.width * zoomScale, height: size.height * zoomScale)
    }
    func finishedUsingTool() {
        usingTool = false
        if let size = pendingSheetSize { pendingSheetSize = nil; setSheetSize(size) }
    }
    func beganUserZooming() {
        if !updatingViewport, pinchGestureRecognizer?.state == .began { followsFit = false }
    }
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil { becomeFirstResponder() }
    }
    override func layoutSubviews() {
        let changed = bounds.size != previousBounds
        let oldSize = previousBounds
        let center = CGPoint(x: (contentOffset.x + oldSize.width / 2) / max(zoomScale, 0.01),
                             y: (contentOffset.y + oldSize.height / 2) / max(zoomScale, 0.01))
        previousBounds = bounds.size
        super.layoutSubviews()
        guard changed, bounds.width > 0, bounds.height > 0 else { return }
        if followsFit { fitContent() }
        else {
            contentOffset = CGPoint(x: max(-contentInset.left, center.x * zoomScale - bounds.width / 2),
                                    y: max(-contentInset.top, center.y * zoomScale - bounds.height / 2))
        }
    }
    func fitSheet() {
        fitsWidth = false; fitContent()
    }
    func fitWidth() {
        fitsWidth = true; fitContent()
    }
    private func fitContent() {
        guard !updatingViewport, bounds.width > 0, bounds.height > 0 else { return }
        updatingViewport = true
        defer { updatingViewport = false }
        followsFit = true
        let sheet = CGRect(origin: .zero, size: sheetSize).union(drawing.bounds)
        let scale = fitsWidth ? bounds.width / sheet.width : min(bounds.width / sheet.width, bounds.height / sheet.height)
        minimumZoomScale = min(0.1, scale)
        maximumZoomScale = max(4, scale)
        zoomScale = scale
        contentSize = CGSize(width: sheetSize.width * scale, height: sheetSize.height * scale)
        let horizontalGap = max(0, (bounds.width - sheet.width * scale) / 2)
        // Writing starts at the top of a width-fit pane. Centering a short
        // sheet in a tall split leaves an invisible, non-drawable gap above it.
        let verticalGap = fitsWidth ? 0 : max(0, (bounds.height - sheet.height * scale) / 2)
        contentInset = UIEdgeInsets(top: max(0, -sheet.minY * scale) + verticalGap,
                                   left: max(0, -sheet.minX * scale) + horizontalGap,
                                   bottom: verticalGap, right: horizontalGap)
        contentOffset = CGPoint(x: sheet.minX * scale - horizontalGap, y: sheet.minY * scale - verticalGap)
    }
}
@MainActor final class MarginEditorState: ObservableObject {
    @Published var handwriting = false
    @Published var drawing = true
    @Published var brush: InkBrush = .pen
    @Published var color = TayyaTheme.brandInk
    @Published var width = 3.0
}
@MainActor final class MarginCanvasControl: ObservableObject {
    weak var canvas: MarginCanvas?
    func action(_ name: String) {
        switch name {
        case "fit": canvas?.fitSheet()
        case "fitWidth": canvas?.fitWidth()
        case "undo": canvas?.undoManager?.undo()
        case "redo": canvas?.undoManager?.redo()
        default: break
        }
    }
}
enum InkBrush: String, CaseIterable, Identifiable {
    case pen = "قلم", pencil = "رصاص", marker = "تظليل", eraser = "ممحاة"
    var id: String { rawValue }
    var symbol: String {
        switch self { case .pen: return "pencil.tip"; case .pencil: return "pencil"; case .marker: return "highlighter"; case .eraser: return "eraser" }
    }
    func tool(color: UIColor, width: CGFloat) -> PKTool {
        switch self {
        case .pen: return PKInkingTool(.pen, color: color, width: width)
        case .pencil: return PKInkingTool(.pencil, color: color, width: width)
        case .marker: return PKInkingTool(.marker, color: color.withAlphaComponent(0.4), width: width * 4)
        case .eraser: return PKEraserTool(.vector)
        }
    }
}
struct InkToolbar: View {
    @Binding var brush: InkBrush
    @Binding var color: Color
    @Binding var width: Double
    var allowsWidthFit = false
    let action: (String) -> Void
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                Menu { ForEach(InkBrush.allCases) { item in Button(item.rawValue, systemImage: item.symbol) { brush = item } } }
                label: { Label(brush.rawValue, systemImage: brush.symbol) }
                ColorPicker("لون الحبر", selection: $color, supportsOpacity: false).labelsHidden().accessibilityLabel("لون الحبر")
                Menu { ForEach([1, 2, 3, 5, 8, 12], id: \.self) { value in Button("سماكة \(value)") { width = Double(value) } } }
                label: { Text("\(Int(width))").monospacedDigit().padding(6).background(.quaternary, in: Circle()) }.accessibilityLabel("سماكة القلم")
                Button("تراجع", systemImage: "arrow.uturn.backward") { action("undo") }.labelStyle(.iconOnly)
                Button("إعادة", systemImage: "arrow.uturn.forward") { action("redo") }.labelStyle(.iconOnly)
                Button("إظهار الورقة كاملة", systemImage: "arrow.up.left.and.arrow.down.right") { action("fit") }.labelStyle(.iconOnly).accessibilityIdentifier("fitMargin")
                if allowsWidthFit {
                    Button("عرض مناسب للكتابة", systemImage: "arrow.left.and.right") { action("fitWidth") }.labelStyle(.iconOnly).accessibilityIdentifier("fitMarginWidth")
                }
            }.padding(.horizontal, 12).padding(.vertical, 8)
        }.background(TayyaTheme.surface)
    }
}
struct MarginNotebook: UIViewRepresentable {
    let page: MarginPage
    let drawing: Bool
    let brush: InkBrush
    let color: Color
    let width: Double
    let control: MarginCanvasControl
    let saved: (PKDrawing) -> Void
    let failed: (String) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(saved: saved, failed: failed) }
    func makeUIView(context: Context) -> MarginCanvas {
        let canvas = MarginCanvas()
        // PencilKit owns clipping of its zoomed tiles at the viewport boundary.
        // An additional SwiftUI mask must not wrap the native drawing surface.
        canvas.clipsToBounds = true
        canvas.backgroundColor = PaperColor.cream.uiColor
        canvas.drawingPolicy = .anyInput
        canvas.contentInsetAdjustmentBehavior = .never
        // Sheet coordinates keep their origin on the left in the Arabic UI too.
        canvas.semanticContentAttribute = .forceLeftToRight
        canvas.delegate = context.coordinator
        canvas.bounces = false
        canvas.isAccessibilityElement = true
        canvas.accessibilityIdentifier = "marginInkCanvas"
        canvas.accessibilityLabel = "ورقة الحاشية بخط اليد"
        configure(canvas, context: context)
        return canvas
    }
    func updateUIView(_ canvas: MarginCanvas, context: Context) { configure(canvas, context: context) }
    private func configure(_ canvas: MarginCanvas, context: Context) {
        let coordinator = context.coordinator
        coordinator.saved = saved; coordinator.failed = failed; control.canvas = canvas
        // Keep PencilKit's live strokes authoritative until the active gesture ends.
        // A SwiftUI re-render must not reload stale bytes over an in-flight stroke.
        if coordinator.pageID != page.id || (!coordinator.isStroking && coordinator.lastInk != page.ink) {
            coordinator.loading = true
            do {
                let ink = page.ink.isEmpty ? PKDrawing() : try PKDrawing(data: page.ink)
                canvas.drawing = ink
                canvas.undoManager?.removeAllActions()
                canvas.setSheetSize(CGSize(width: page.width, height: page.height))
                canvas.contentSize = CGSize(width: canvas.sheetSize.width * canvas.zoomScale, height: canvas.sheetSize.height * canvas.zoomScale)
                canvas.fitWidth(); coordinator.pageID = page.id; coordinator.lastInk = page.ink
                canvas.accessibilityValue = String(ink.strokes.count)
            } catch { failed(error.localizedDescription) }
            coordinator.loading = false
        }
        let size = CGSize(width: page.width, height: page.height)
        if canvas.sheetSize != size {
            canvas.setSheetSize(size)
        }
        if canvas.drawingGestureRecognizer.isEnabled != drawing {
            canvas.drawingGestureRecognizer.isEnabled = drawing
        }
        let panTouches = drawing ? 2 : 1
        if canvas.panGestureRecognizer.minimumNumberOfTouches != panTouches {
            canvas.panGestureRecognizer.minimumNumberOfTouches = panTouches
        }
        coordinator.applyTool(to: canvas, brush: brush, color: color, width: width)
    }
    @MainActor final class Coordinator: NSObject, PKCanvasViewDelegate {
        var pageID: UUID?
        var lastInk: Data?
        var loading = false
        var isStroking = false
        private var hasUncommittedStroke = false
        private var appliedBrush: InkBrush?
        private var appliedColor: Color?
        private var appliedWidth: Double?
        var saved: (PKDrawing) -> Void
        var failed: (String) -> Void
        init(saved: @escaping (PKDrawing) -> Void, failed: @escaping (String) -> Void) { self.saved = saved; self.failed = failed }
        func applyTool(to canvas: PKCanvasView, brush: InkBrush, color: Color, width: Double) {
            // Saving a stroke publishes a new page and updates this representable.
            // Do not replace PencilKit's tool while that same stroke is committing.
            guard appliedBrush != brush || appliedColor != color || appliedWidth != width else { return }
            canvas.tool = brush.tool(color: UIColor(color), width: width)
            appliedBrush = brush; appliedColor = color; appliedWidth = width
        }
        private func persist(_ canvas: PKCanvasView) {
            let data = canvas.drawing.dataRepresentation()
            guard data != lastInk else { return }
            lastInk = data
            saved(canvas.drawing)
        }
        func canvasViewDrawingDidChange(_ canvas: PKCanvasView) {
            guard !loading else { return }
            canvas.accessibilityValue = String(canvas.drawing.strokes.count)
            if isStroking {
                // Do not serialize and synchronously write every PencilKit frame.
                hasUncommittedStroke = true
            } else {
                persist(canvas) // Undo, redo, and programmatic drawing changes.
            }
        }
        func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
            isStroking = true
            (canvasView as? MarginCanvas)?.usingTool = true
        }
        func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
            isStroking = false
            if hasUncommittedStroke {
                hasUncommittedStroke = false
                persist(canvasView)
            }
            (canvasView as? MarginCanvas)?.finishedUsingTool()
        }
        func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) { (scrollView as? MarginCanvas)?.beganUserZooming() }
        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) { (scrollView as? MarginCanvas)?.followsFit = false }
    }
}
