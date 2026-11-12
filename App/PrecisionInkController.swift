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
    let lineGesture = InkPanGestureRecognizer()
    private let tapGesture = UITapGestureRecognizer()
    let endpointGesture = InkPanGestureRecognizer()
    private let notesLasso = UIPanGestureRecognizer()
    private let handles = CAShapeLayer()
    private var copiedInk: PKDrawing?
    private var polygon: [CGPoint] = []
    private var endpointIndex: Int?
    private var endpointBase: PKDrawing?
    private var endpointLocations: (CGPoint, CGPoint)?
    var selectionAllowsGeometry: Bool {
        guard let canvas, !selectedIndices.isEmpty else { return false }
        return selectedIndices.allSatisfy { index in
            guard canvas.drawing.strokes.indices.contains(index) else { return false }
            let stroke = canvas.drawing.strokes[index]
            guard stroke.mask == nil, let start = stroke.path.first?.location, let end = stroke.path.last?.location else { return false }
            return hypot(start.x - end.x, start.y - end.y) > 0.01
        }
    }

    private struct Configuration: Equatable {
        var mode: InkGeometryMode
        var selection: Bool
        var ruler: Bool
        var brush: InkBrush
        var color: UIColor
        var width: CGFloat
        var enabled: Bool
        var writable: Bool
    }

    init(canvas: PKCanvasView) {
        self.canvas = canvas
        super.init()
        lineGesture.addTarget(self, action: #selector(drawLine(_:)))
        lineGesture.maximumNumberOfTouches = 1
        lineGesture.delegate = self; lineGesture.isEnabled = false
        tapGesture.addTarget(self, action: #selector(selectAtTap(_:)))
        tapGesture.delegate = self; tapGesture.isEnabled = false
        endpointGesture.addTarget(self, action: #selector(adjustEndpoint(_:)))
        endpointGesture.maximumNumberOfTouches = 1; endpointGesture.delegate = self; endpointGesture.isEnabled = false
        notesLasso.addTarget(self, action: #selector(selectNotesPolygon(_:)))
        notesLasso.maximumNumberOfTouches = 1; notesLasso.delegate = self; notesLasso.isEnabled = false
        notesLasso.require(toFail: endpointGesture)
        tapGesture.require(toFail: endpointGesture)
        canvas.addGestureRecognizer(lineGesture); canvas.addGestureRecognizer(tapGesture)
        canvas.addGestureRecognizer(endpointGesture)
        if canvas is MarginCanvas { canvas.addGestureRecognizer(notesLasso) }
        preview.fillColor = UIColor.clear.cgColor; preview.lineCap = .butt; preview.zPosition = 101
        selectionOutline.strokeColor = UIColor(red: 0.14, green: 0.30, blue: 0.26, alpha: 1).cgColor
        selectionOutline.fillColor = UIColor.clear.cgColor; selectionOutline.lineWidth = 2
        selectionOutline.lineDashPattern = [5, 4]; selectionOutline.zPosition = 102
        handles.fillColor = UIColor.white.cgColor; handles.strokeColor = selectionOutline.strokeColor
        handles.lineWidth = 2; handles.zPosition = 103
        canvas.layer.addSublayer(preview); canvas.layer.addSublayer(selectionOutline); canvas.layer.addSublayer(handles)
    }

    @discardableResult func replaceDrawing(_ drawing: PKDrawing, reason: InkCommitReason, actionName: String) -> Bool {
        guard let canvas, !nativeActive, configuration?.writable != false,
              (reason == .history || configuration?.enabled != false),
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
        guard changed || selectionBytes != nil || !polygon.isEmpty else { return }
        selectedIndices = []; selectionBytes = nil; selectionOutline.path = nil; handles.path = nil
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

    @discardableResult func perform(_ action: String) -> Bool {
        guard let canvas else { return false }
        if action == "undo" { canvas.undoManager?.undo(); return true }
        if action == "redo" { canvas.undoManager?.redo(); return true }
        if action == "straighten" { return editSelection(.straighten) }
        let colors: [String: UIColor] = ["red": .systemRed, "blue": .systemBlue, "green": UIColor(red: 0.14, green: 0.30, blue: 0.26, alpha: 1), "black": .black, "yellow": .systemYellow]
        if action.hasPrefix("rgba:") {
            let values = action.dropFirst(5).split(separator: ",").compactMap { Double($0) }
            guard values.count == 4, values.allSatisfy({ $0.isFinite && (0...1).contains($0) }) else { return false }
            return editSelection(.recolor(UIColor(red: values[0], green: values[1], blue: values[2], alpha: values[3])))
        }
        if action.hasPrefix("color-"), let color = colors[String(action.dropFirst(6))] { return editSelection(.recolor(color)) }
        if action == "paste", let copiedInk {
            return replaceDrawing(PKDrawing(strokes: canvas.drawing.strokes + copiedInk.strokes), reason: .newStroke, actionName: TayyaLocalized("لصق"))
        }
        guard !selectedIndices.isEmpty, selectionBytes == canvas.drawing.dataRepresentation() else { clearSelection(); return false }
        let selected = selectedIndices
        if action == "copy" { copiedInk = PKDrawing(strokes: selected.map { canvas.drawing.strokes[$0] }); return true }
        if action.hasPrefix("width-"), let width = Double(action.dropFirst(6)), width.isFinite, width > 0 {
            var edited = canvas.drawing
            for index in selected {
                let actualWidth = CGFloat(width) * (edited.strokes[index].ink.inkType == .marker ? 4 : 1)
                if let changed = InkStrokeEditing.applying(.width(actualWidth), to: edited, indices: [index]) { edited = changed }
            }
            let changed = replaceDrawing(edited, reason: .edit, actionName: TayyaLocalized("سماكة الخط"))
            if changed { select(selected) }; return changed
        }
        if action == "lengthen" || action == "shorten" {
            guard selected.count == 1, let ends = visibleEndpoints() else { return false }
            let stroke = canvas.drawing.strokes[selected[0]], start = stroke.path[0].location, end = stroke.path[stroke.path.count - 1].location
            let length = hypot(end.x - start.x, end.y - start.y), delta: CGFloat = action == "lengthen" ? 10 : -10
            guard length + delta > 1, ends.0 != ends.1 else { return false }
            return editSelection(.endpoints(start: start, end: CGPoint(x: start.x + (end.x - start.x) * (length + delta) / length, y: start.y + (end.y - start.y) * (length + delta) / length)))
        }
        let bounds = PKDrawing(strokes: selected.map { canvas.drawing.strokes[$0] }).bounds
        let transform: CGAffineTransform
        switch action {
        case "left": transform = CGAffineTransform(translationX: -10, y: 0)
        case "right": transform = CGAffineTransform(translationX: 10, y: 0)
        case "up": transform = CGAffineTransform(translationX: 0, y: -10)
        case "down": transform = CGAffineTransform(translationX: 0, y: 10)
        case "grow", "shrink":
            let factor: CGFloat = action == "grow" ? 1.1 : 0.9
            transform = CGAffineTransform(translationX: -bounds.midX, y: -bounds.midY).concatenating(CGAffineTransform(scaleX: factor, y: factor)).concatenating(CGAffineTransform(translationX: bounds.midX, y: bounds.midY))
        default: return false
        }
        let changed = replaceDrawing(InkSelection.transform(canvas.drawing, indices: selected, by: transform), reason: .edit, actionName: TayyaLocalized("تعديل الخط"))
        if changed { select(selected) }; return changed
    }

    func configure(mode: InkGeometryMode, selection: Bool, ruler: Bool, brush: InkBrush, color: UIColor, width: CGFloat, enabled: Bool, writable: Bool = true) {
        let value = Configuration(mode: mode, selection: selection, ruler: ruler, brush: brush, color: color, width: width, enabled: enabled, writable: writable)
        if nativeActive { pendingConfiguration = value; return }
        if lineStart != nil || endpointIndex != nil {
            if value.enabled && value.writable && value.mode == configuration?.mode && value.selection == configuration?.selection {
                pendingConfiguration = value; return
            }
            cancelInteraction()
        }
        apply(value)
    }
    private func apply(_ value: Configuration) {
        // The newest model state supersedes any style queued by an older gesture.
        pendingConfiguration = nil
        guard let canvas, value != configuration else { return }
        cancelInteraction()
        let old = configuration
        configuration = value
        if value.selection != old?.selection || !value.enabled { clearSelection() }
        let direct = value.enabled && value.writable && !value.selection && value.mode != .freehand && value.brush != .eraser
        if old?.mode != value.mode || old?.selection != value.selection || old?.enabled != value.enabled || old?.writable != value.writable {
            // A pending first contact belongs to the old tool, even if its pan
            // has not crossed the recognition threshold yet.
            lineGesture.isEnabled = false; endpointGesture.isEnabled = false
        }
        let native = value.enabled && value.writable && !value.selection && !direct
        if canvas.drawingGestureRecognizer.isEnabled != native { canvas.drawingGestureRecognizer.isEnabled = native }
        lineGesture.isEnabled = direct
        tapGesture.isEnabled = value.enabled && value.writable && value.selection
        endpointGesture.isEnabled = value.enabled && value.writable && value.selection
        notesLasso.isEnabled = value.enabled && value.writable && value.selection && canvas is MarginCanvas
        let ruler = native && value.ruler && value.brush != .eraser
        if canvas.isRulerActive != ruler { canvas.isRulerActive = ruler }
        if old?.brush != value.brush || old?.color != value.color || old?.width != value.width {
            canvas.tool = value.brush.tool(color: value.color, width: value.width)
        }
    }
    func nativeToolBegan() {
        nativeActive = true; updateHistoryAvailability()
        assignedBytes = nil; cancelInteraction(); clearSelection()
    }
    /// True means our explicit commit already owns this setter notification.
    @discardableResult func nativeDrawingChanged() -> Bool {
        guard let canvas else { return false }
        if isApplying { return true }
        if nativeActive { return false }
        guard selectionBytes != nil || assignedBytes != nil else { return false }
        let current = canvas.drawing.dataRepresentation()
        if selectionBytes != nil && selectionBytes != current { clearSelection() }
        if assignedBytes == current { return true }
        assignedBytes = nil
        return false
    }
    func nativeToolEnded() {
        nativeActive = false; updateHistoryAvailability()
        applyPendingConfiguration()
    }
    private func applyPendingConfiguration() {
        if let pending = pendingConfiguration { pendingConfiguration = nil; apply(pending) }
    }
    func cancelInteraction() {
        let hadInteraction = lineStart != nil || endpointIndex != nil
        guard hadInteraction || !polygon.isEmpty else { return }
        lineStart = nil; lineBase = nil; lineStyle = nil; preview.path = nil
        if !polygon.isEmpty { selectionOutline.path = nil }
        endpointIndex = nil; endpointBase = nil; endpointLocations = nil; polygon = []
        updateHistoryAvailability()
        if hadInteraction { (canvas as? MarginCanvas)?.finishedUsingTool() }
    }
    private func updateHistoryAvailability() {
        (canvas?.undoManager as? CanvasUndoManager)?.interactionActive = nativeActive || lineStart != nil || endpointIndex != nil
    }
    func resetForLoadedPage() {
        pendingConfiguration = nil; cancelInteraction(); clearSelection(); nativeActive = false; assignedBytes = nil
        let recognizers: [UIGestureRecognizer] = [lineGesture, endpointGesture, tapGesture, notesLasso]
        for recognizer in recognizers {
            let enabled = recognizer.isEnabled
            recognizer.isEnabled = false; recognizer.isEnabled = enabled
        }
        updateHistoryAvailability()
    }

    func beginLine(at point: CGPoint) {
        guard let canvas, let value = configuration, value.enabled, value.writable, !value.selection,
              value.mode != .freehand, value.brush != .eraser, !nativeActive else { return }
        clearSelection()
        lineStart = Self.drawingPoint(point, in: canvas); lineBase = canvas.drawing
        updateHistoryAvailability()
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
        defer { cancelInteraction(); applyPendingConfiguration() }
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
        case .began: beginLine(at: Self.initialPoint(of: gesture, in: canvas))
        case .changed: updateLine(to: point)
        case .ended: finishLine(at: point)
        case .cancelled, .failed: cancelInteraction(); applyPendingConfiguration()
        default: break
        }
    }
    static func initialPoint(of gesture: UIPanGestureRecognizer, in canvas: PKCanvasView) -> CGPoint {
        if let contact = (gesture as? InkPanGestureRecognizer)?.firstContact {
            return gesture.view === canvas ? contact : canvas.convert(contact, from: gesture.view)
        }
        let point = gesture.location(in: canvas), movement = gesture.translation(in: canvas)
        return CGPoint(x: point.x - movement.x, y: point.y - movement.y)
    }
    @objc private func selectAtTap(_ gesture: UITapGestureRecognizer) {
        guard let canvas, gesture.state == .ended else { return }
        let point = Self.drawingPoint(gesture.location(in: canvas), in: canvas)
        let index = InkStrokeEditing.hitIndex(in: canvas.drawing, at: point, tolerance: 12 / max(canvas.zoomScale, 0.001))
        select(index.map { [$0] } ?? [])
    }
    func viewportDidChange() {
        guard !nativeActive, lineStart == nil, endpointIndex == nil, polygon.isEmpty, !selectedIndices.isEmpty else { return }
        updateSelectionOutline()
    }
    private func updateSelectionOutline() {
        guard let canvas, !selectedIndices.isEmpty else { selectionOutline.path = nil; handles.path = nil; return }
        let strokes = selectedIndices.map { canvas.drawing.strokes[$0] }
        let bounds = PKDrawing(strokes: strokes).bounds.applying(CGAffineTransform(scaleX: canvas.zoomScale, y: canvas.zoomScale)).insetBy(dx: -5, dy: -5)
        selectionOutline.path = UIBezierPath(roundedRect: bounds, cornerRadius: 4).cgPath
        let path = UIBezierPath()
        if let endpoints = visibleEndpoints() {
            for point in [endpoints.0, endpoints.1] {
                path.append(UIBezierPath(ovalIn: CGRect(x: point.x - 6, y: point.y - 6, width: 12, height: 12)))
            }
        }
        handles.path = path.cgPath
    }
    private func visibleEndpoints() -> (CGPoint, CGPoint)? {
        guard let canvas, selectedIndices.count == 1, selectionAllowsGeometry else { return nil }
        let stroke = canvas.drawing.strokes[selectedIndices[0]]
        guard let start = stroke.path.first?.location, let end = stroke.path.last?.location else { return nil }
        let dx = end.x - start.x, dy = end.y - start.y, length = hypot(dx, dy)
        guard length > 0.01, stroke.path.allSatisfy({ abs(($0.location.x - start.x) * dy - ($0.location.y - start.y) * dx) / length < 1 }) else { return nil }
        let scale = CGAffineTransform(scaleX: canvas.zoomScale, y: canvas.zoomScale)
        return (start.applying(stroke.transform).applying(scale), end.applying(stroke.transform).applying(scale))
    }
    func endpointIndex(near point: CGPoint) -> Int? {
        guard let ends = visibleEndpoints() else { return nil }
        let startDistance = hypot(point.x - ends.0.x, point.y - ends.0.y)
        let endDistance = hypot(point.x - ends.1.x, point.y - ends.1.y)
        guard min(startDistance, endDistance) <= 22 else { return nil }
        return startDistance <= endDistance ? 0 : 1
    }
    @objc private func adjustEndpoint(_ gesture: UIPanGestureRecognizer) {
        guard let canvas else { return }
        let point = gesture.location(in: canvas)
        switch gesture.state {
        case .began:
            guard let index = endpointIndex(near: Self.initialPoint(of: gesture, in: canvas)) else { return }
            endpointIndex = index
            updateHistoryAvailability()
            endpointBase = canvas.drawing
            let stroke = canvas.drawing.strokes[selectedIndices[0]]
            endpointLocations = (stroke.path[0].location, stroke.path[stroke.path.count - 1].location)
            (canvas as? MarginCanvas)?.usingTool = true
        case .changed, .ended:
            guard let index = endpointIndex, let original = endpointBase, let locations = endpointLocations,
                  selectedIndices.count == 1 else { cancelInteraction(); return }
            if gesture.state == .ended && original.dataRepresentation() != canvas.drawing.dataRepresentation() { cancelInteraction(); return }
            let stroke = original.strokes[selectedIndices[0]]
            let moved = Self.drawingPoint(point, in: canvas).applying(stroke.transform.inverted())
            let start = index == 0 ? moved : locations.0, end = index == 1 ? moved : locations.1
            let path = UIBezierPath(), scale = CGAffineTransform(scaleX: canvas.zoomScale, y: canvas.zoomScale)
            path.move(to: start.applying(stroke.transform).applying(scale)); path.addLine(to: end.applying(stroke.transform).applying(scale))
            preview.strokeColor = stroke.ink.color.cgColor; preview.lineWidth = stroke.path[0].size.width * canvas.zoomScale; preview.path = path.cgPath
            if gesture.state == .ended {
                editSelection(.endpoints(start: start, end: end)); cancelInteraction(); applyPendingConfiguration()
            }
        case .cancelled, .failed: cancelInteraction(); updateSelectionOutline(); applyPendingConfiguration()
        default: break
        }
    }
    @objc private func selectNotesPolygon(_ gesture: UIPanGestureRecognizer) {
        guard let canvas else { return }
        let point = Self.drawingPoint(gesture.location(in: canvas), in: canvas)
        if gesture.state == .began { clearSelection(); polygon = [] }
        polygon.append(point)
        let path = UIBezierPath()
        for (index, point) in polygon.enumerated() {
            let scaled = CGPoint(x: point.x * canvas.zoomScale, y: point.y * canvas.zoomScale)
            if index == 0 { path.move(to: scaled) } else { path.addLine(to: scaled) }
        }
        selectionOutline.path = path.cgPath
        if gesture.state == .ended { select(InkSelection.indices(in: canvas.drawing, polygon: polygon)); polygon = [] }
        if gesture.state == .cancelled || gesture.state == .failed { clearSelection(); polygon = [] }
    }
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let canvas, !nativeActive else { return false }
        if gestureRecognizer === endpointGesture {
            guard configuration?.selection == true, let ends = visibleEndpoints() else { return false }
            let point = Self.initialPoint(of: endpointGesture, in: canvas)
            return min(hypot(point.x - ends.0.x, point.y - ends.0.y), hypot(point.x - ends.1.x, point.y - ends.1.y)) <= 22
        }
        if gestureRecognizer === lineGesture {
            return configuration?.enabled == true && configuration?.selection == false && lineGesture.numberOfTouches <= 1
                && canvas.bounds.contains(lineGesture.location(in: canvas))
        }
        return configuration?.enabled == true && configuration?.selection == true
    }
}
