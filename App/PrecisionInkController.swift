import UIKit
import PencilKit

enum InkCommitReason: Equatable { case newStroke, edit, history }

/// Composition retains each production canvas and its independent native history.
@MainActor final class PrecisionInkController: NSObject, UIGestureRecognizerDelegate {
    weak var canvas: PKCanvasView?
    var didCommit: ((PKDrawing, InkCommitReason) -> Void)?
    var selectionDidChange: ((Int) -> Void)?
    private(set) var selectedIndices: [Int] = []
    private(set) var isApplying = false
    private var nativeActive = false
    private var selectionBytes: Data?
    private var assignedBytes: Data?
    private var configuration: Configuration?
    private var pendingConfiguration: Configuration?
    private var lineStart: CGPoint?
    private var lineBase: PKDrawing?
    private var lineStyle: (PKInk, CGFloat)?
    private let preview = CAShapeLayer()
    private let selectionOutline = CAShapeLayer()
    let lineGesture = UIPanGestureRecognizer()
    private let tapGesture = UITapGestureRecognizer()

    private struct Configuration: Equatable {
        var mode: InkGeometryMode
        var selection: Bool
        var ruler: Bool
        var brush: InkBrush
        var color: UIColor
        var width: CGFloat
        var enabled: Bool
    }

    init(canvas: PKCanvasView) {
        self.canvas = canvas
        super.init()
        lineGesture.addTarget(self, action: #selector(drawLine(_:)))
        lineGesture.maximumNumberOfTouches = 1
        lineGesture.delegate = self; lineGesture.isEnabled = false
        tapGesture.addTarget(self, action: #selector(selectAtTap(_:)))
        tapGesture.delegate = self; tapGesture.isEnabled = false
        canvas.addGestureRecognizer(lineGesture); canvas.addGestureRecognizer(tapGesture)
        preview.fillColor = UIColor.clear.cgColor; preview.lineCap = .butt; preview.zPosition = 101
        selectionOutline.strokeColor = UIColor(red: 0.14, green: 0.30, blue: 0.26, alpha: 1).cgColor
        selectionOutline.fillColor = UIColor.clear.cgColor; selectionOutline.lineWidth = 2
        selectionOutline.lineDashPattern = [5, 4]; selectionOutline.zPosition = 102
        canvas.layer.addSublayer(preview); canvas.layer.addSublayer(selectionOutline)
    }

    @discardableResult func replaceDrawing(_ drawing: PKDrawing, reason: InkCommitReason, actionName: String) -> Bool {
        guard let canvas, !nativeActive, configuration?.enabled != false,
              drawing.dataRepresentation() != canvas.drawing.dataRepresentation(), let manager = canvas.undoManager else { return false }
        let previous = canvas.drawing
        let history = manager.isUndoing || manager.isRedoing
        if !history { manager.beginUndoGrouping() }
        manager.registerUndo(withTarget: self) { target in
            target.replaceDrawing(previous, reason: .history, actionName: actionName)
        }
        manager.setActionName(actionName)
        // A programmatic setter must not add a second PencilKit action on top
        // of our inverse. Never clear native history or share another canvas's manager.
        manager.disableUndoRegistration()
        isApplying = true
        assignedBytes = drawing.dataRepresentation()
        canvas.drawing = drawing
        isApplying = false
        manager.enableUndoRegistration()
        if !history { manager.endUndoGrouping() }
        select([])
        canvas.accessibilityValue = String(drawing.strokes.count)
        didCommit?(drawing, reason)
        return true
    }

    func select(_ indices: [Int]) {
        guard let canvas, !nativeActive, indices.allSatisfy({ canvas.drawing.strokes.indices.contains($0) }) else {
            clearSelection(); return
        }
        selectedIndices = Array(Set(indices)).sorted()
        selectionBytes = selectedIndices.isEmpty ? nil : canvas.drawing.dataRepresentation()
        updateSelectionOutline()
        selectionDidChange?(selectedIndices.count)
    }
    private func clearSelection() {
        let changed = !selectedIndices.isEmpty
        selectedIndices = []; selectionBytes = nil; selectionOutline.path = nil
        if changed { selectionDidChange?(0) }
    }
    @discardableResult func editSelection(_ operation: InkEditOperation) -> Bool {
        guard let canvas, !nativeActive, let selectedBytes = selectionBytes,
              selectedBytes == canvas.drawing.dataRepresentation(),
              let edited = InkStrokeEditing.applying(operation, to: canvas.drawing, indices: selectedIndices) else {
            if let canvas, selectionBytes != canvas.drawing.dataRepresentation() { clearSelection() }
            return false
        }
        let indices = selectedIndices
        let changed = replaceDrawing(edited, reason: .edit, actionName: TayyaLocalized("تعديل الخط"))
        if changed { select(indices) }
        return changed
    }

    func configure(mode: InkGeometryMode, selection: Bool, ruler: Bool, brush: InkBrush, color: UIColor, width: CGFloat, enabled: Bool) {
        let value = Configuration(mode: mode, selection: selection, ruler: ruler, brush: brush, color: color, width: width, enabled: enabled)
        if nativeActive { pendingConfiguration = value; return }
        apply(value)
    }
    private func apply(_ value: Configuration) {
        guard let canvas, value != configuration else { return }
        cancelInteraction()
        let old = configuration
        configuration = value
        if value.selection != old?.selection || !value.enabled { clearSelection() }
        let direct = value.enabled && !value.selection && value.mode != .freehand && value.brush != .eraser
        let native = value.enabled && !value.selection && !direct
        if canvas.drawingGestureRecognizer.isEnabled != native { canvas.drawingGestureRecognizer.isEnabled = native }
        lineGesture.isEnabled = direct
        tapGesture.isEnabled = value.enabled && value.selection
        let ruler = native && value.ruler && value.brush != .eraser
        if canvas.isRulerActive != ruler { canvas.isRulerActive = ruler }
        if old?.brush != value.brush || old?.color != value.color || old?.width != value.width {
            canvas.tool = value.brush.tool(color: value.color, width: value.width)
        }
    }
    func nativeToolBegan() {
        nativeActive = true; assignedBytes = nil; cancelInteraction(); clearSelection()
    }
    /// True means our explicit commit already owns this setter notification.
    @discardableResult func nativeDrawingChanged() -> Bool {
        guard let canvas else { return false }
        if isApplying { return true }
        if nativeActive { return false }
        let current = canvas.drawing.dataRepresentation()
        if selectionBytes != nil && selectionBytes != current { clearSelection() }
        if assignedBytes == current { return true }
        assignedBytes = nil
        return false
    }
    func nativeToolEnded() {
        nativeActive = false
        if let pending = pendingConfiguration { pendingConfiguration = nil; apply(pending) }
    }
    func cancelInteraction() {
        lineStart = nil; lineBase = nil; lineStyle = nil; preview.path = nil
        (canvas as? MarginCanvas)?.finishedUsingTool()
    }
    func resetForLoadedPage() {
        cancelInteraction(); clearSelection(); nativeActive = false; assignedBytes = nil
    }

    func beginLine(at point: CGPoint) {
        guard let canvas, let value = configuration, value.enabled, !value.selection,
              value.mode != .freehand, value.brush != .eraser, !nativeActive else { return }
        clearSelection()
        lineStart = Self.drawingPoint(point, in: canvas); lineBase = canvas.drawing
        let marker = value.mode == .highlighter || value.brush == .marker
        lineStyle = (PKInk(marker ? .marker : value.brush == .pencil ? .pencil : .pen,
                           color: marker ? value.color.withAlphaComponent(0.4) : value.color), marker ? value.width * 4 : value.width)
        (canvas as? MarginCanvas)?.usingTool = true
    }
    func updateLine(to point: CGPoint) {
        guard let canvas, let start = lineStart, let style = lineStyle else { return }
        let end = Self.drawingPoint(point, in: canvas), scale = canvas.zoomScale
        let path = UIBezierPath(); path.move(to: CGPoint(x: start.x * scale, y: start.y * scale))
        path.addLine(to: CGPoint(x: end.x * scale, y: end.y * scale))
        preview.strokeColor = style.0.color.cgColor; preview.lineWidth = style.1 * scale; preview.path = path.cgPath
    }
    @discardableResult func finishLine(at point: CGPoint) -> Bool {
        guard let canvas, let start = lineStart, let original = lineBase, let style = lineStyle else { return false }
        defer { cancelInteraction() }
        guard original.dataRepresentation() == canvas.drawing.dataRepresentation(),
              let stroke = InkStrokeEditing.line(from: start, to: Self.drawingPoint(point, in: canvas), ink: style.0, width: style.1, creationDate: Date()) else { return false }
        return replaceDrawing(PKDrawing(strokes: original.strokes + [stroke]), reason: .newStroke, actionName: TayyaLocalized("خط مستقيم"))
    }
    static func drawingPoint(_ point: CGPoint, in canvas: PKCanvasView) -> CGPoint {
        let scale = max(canvas.zoomScale, 0.001)
        return CGPoint(x: point.x / scale, y: point.y / scale)
    }
    @objc private func drawLine(_ gesture: UIPanGestureRecognizer) {
        guard let canvas else { return }
        let point = gesture.location(in: canvas)
        switch gesture.state {
        case .began: beginLine(at: point)
        case .changed: updateLine(to: point)
        case .ended: finishLine(at: point)
        case .cancelled, .failed: cancelInteraction()
        default: break
        }
    }
    @objc private func selectAtTap(_ gesture: UITapGestureRecognizer) {
        guard let canvas, gesture.state == .ended else { return }
        let point = Self.drawingPoint(gesture.location(in: canvas), in: canvas)
        let index = InkStrokeEditing.hitIndex(in: canvas.drawing, at: point, tolerance: 12 / max(canvas.zoomScale, 0.001))
        select(index.map { [$0] } ?? [])
    }
    private func updateSelectionOutline() {
        guard let canvas, !selectedIndices.isEmpty else { selectionOutline.path = nil; return }
        let strokes = selectedIndices.map { canvas.drawing.strokes[$0] }
        let bounds = PKDrawing(strokes: strokes).bounds.applying(CGAffineTransform(scaleX: canvas.zoomScale, y: canvas.zoomScale)).insetBy(dx: -5, dy: -5)
        selectionOutline.path = UIBezierPath(roundedRect: bounds, cornerRadius: 4).cgPath
    }
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let canvas, !nativeActive else { return false }
        if gestureRecognizer === lineGesture {
            return configuration?.enabled == true && configuration?.selection == false && lineGesture.numberOfTouches <= 1
                && canvas.bounds.contains(lineGesture.location(in: canvas))
        }
        return configuration?.enabled == true && configuration?.selection == true
    }
}
