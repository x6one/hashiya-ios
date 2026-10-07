import SwiftUI
import PencilKit

// Sheet coordinates never depend on the size of the split pane.
final class MarginCanvas: PKCanvasView {
    var sheetSize = CGSize(width: 650, height: 900)
    var followsFit = true
    private var previousBounds = CGSize.zero
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
        if followsFit { fitSheet() }
        else {
            contentOffset = CGPoint(x: max(0, center.x * zoomScale - bounds.width / 2),
                                    y: max(0, center.y * zoomScale - bounds.height / 2))
        }
    }
    func fitSheet() {
        guard bounds.width > 0, bounds.height > 0 else { return }
        followsFit = true
        let scale = min(bounds.width / sheetSize.width, bounds.height / sheetSize.height)
        minimumZoomScale = min(0.1, scale)
        maximumZoomScale = max(4, scale)
        zoomScale = scale
        contentOffset = .zero
    }
}
@MainActor final class MarginCanvasControl: ObservableObject {
    weak var canvas: MarginCanvas?
    func action(_ name: String) {
        switch name {
        case "fit": canvas?.fitSheet()
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
        canvas.backgroundColor = PaperColor.cream.uiColor
        canvas.drawingPolicy = .anyInput
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
        if coordinator.pageID != page.id {
            coordinator.loading = true
            do {
                let ink = page.ink.isEmpty ? PKDrawing() : try PKDrawing(data: page.ink)
                canvas.drawing = ink
                canvas.undoManager?.removeAllActions()
                canvas.sheetSize = CGSize(width: page.width, height: page.height)
                canvas.zoomScale = 1; canvas.contentSize = canvas.sheetSize
                canvas.fitSheet(); coordinator.pageID = page.id
                canvas.accessibilityValue = String(ink.strokes.count)
            } catch { failed(error.localizedDescription) }
            coordinator.loading = false
        }
        canvas.drawingGestureRecognizer.isEnabled = drawing
        canvas.panGestureRecognizer.minimumNumberOfTouches = drawing ? 2 : 1
        canvas.tool = brush.tool(color: UIColor(color), width: width)
    }
    @MainActor final class Coordinator: NSObject, PKCanvasViewDelegate {
        var pageID: UUID?
        var loading = false
        var saved: (PKDrawing) -> Void
        var failed: (String) -> Void
        init(saved: @escaping (PKDrawing) -> Void, failed: @escaping (String) -> Void) { self.saved = saved; self.failed = failed }
        func canvasViewDrawingDidChange(_ canvas: PKCanvasView) {
            guard !loading else { return }
            canvas.accessibilityValue = String(canvas.drawing.strokes.count); saved(canvas.drawing)
        }
        func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) { (scrollView as? MarginCanvas)?.followsFit = false }
    }
}
