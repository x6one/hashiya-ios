import SwiftUI
import PencilKit

final class MarginCanvas: PKCanvasView {
    let picker = PKToolPicker()
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil { becomeFirstResponder(); picker.setVisible(true, forFirstResponder: self) }
        else { picker.setVisible(false, forFirstResponder: self) }
    }
}
struct MarginNotebook: UIViewRepresentable {
    let url: URL
    let saved: (Int) -> Void
    let failed: (String) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(url: url, saved: saved, failed: failed) }
    func makeUIView(context: Context) -> MarginCanvas {
        let canvas = MarginCanvas()
        canvas.backgroundColor = UIColor(red: 1, green: 0.995, blue: 0.96, alpha: 1)
        canvas.contentSize = CGSize(width: 650, height: 1200)
        canvas.minimumZoomScale = 0.3; canvas.maximumZoomScale = 2; canvas.zoomScale = 0.65
        canvas.drawingPolicy = .anyInput
        canvas.tool = PKInkingTool(.pen, color: .darkGray, width: 3)
        if FileManager.default.fileExists(atPath: url.path) {
            do { canvas.drawing = try PKDrawing(data: Data(contentsOf: url)) }
            catch { failed(error.localizedDescription) }
        }
        canvas.delegate = context.coordinator; canvas.picker.addObserver(canvas)
        canvas.accessibilityIdentifier = "marginInkCanvas"
        canvas.accessibilityLabel = "دفتر الحاشية بخط اليد"
        return canvas
    }
    func updateUIView(_ view: MarginCanvas, context: Context) { context.coordinator.saved = saved; context.coordinator.failed = failed }
    @MainActor final class Coordinator: NSObject, PKCanvasViewDelegate {
        let url: URL
        var saved: (Int) -> Void
        var failed: (String) -> Void
        init(url: URL, saved: @escaping (Int) -> Void, failed: @escaping (String) -> Void) { self.url = url; self.saved = saved; self.failed = failed }
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            do { try canvasView.drawing.dataRepresentation().write(to: url, options: .atomic); saved(canvasView.drawing.strokes.count) }
            catch { failed(error.localizedDescription) }
        }
    }
}
