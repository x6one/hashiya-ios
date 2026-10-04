import UIKit
import PencilKit
/// Independent selection geometry keeps the stored PKDrawing editable.
/// The path uses PDF overlay coordinates and selects strokes whose sampled
/// points lie inside the user's lasso, rather than selecting the whole page.
enum InkSelection {
    static func indices(in drawing: PKDrawing, polygon: [CGPoint]) -> [Int] {
        guard polygon.count >= 3 else { return [] }
        let path = UIBezierPath(); path.move(to: polygon[0]); polygon.dropFirst().forEach { path.addLine(to: $0) }; path.close()
        return drawing.strokes.indices.filter { index in
            let stroke = drawing.strokes[index]
            return stroke.path.contains { point in path.contains(point.location.applying(stroke.transform)) }
        }
    }
    static func transform(_ drawing: PKDrawing, indices: [Int], by transform: CGAffineTransform) -> PKDrawing {
        let selected = Set(indices)
        return PKDrawing(strokes: drawing.strokes.enumerated().map { index, stroke in
            guard selected.contains(index) else { return stroke }
            return PKDrawing(strokes: [stroke]).transformed(using: transform).strokes[0]
        })
    }
}
final class LassoCanvas: PKCanvasView {
    var lassoMode = false { didSet { setNeedsDisplay() } }
    var points: [CGPoint] = []
    var selected: [Int] = []
    var selectionChanged: ((Int) -> Void)?
    lazy var lasso = UIPanGestureRecognizer(target: self, action: #selector(selectInk(_:)))
    override init(frame: CGRect) { super.init(frame: frame); addGestureRecognizer(lasso); lasso.isEnabled = false }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func enableLasso(_ value: Bool) {
        lassoMode = value; lasso.isEnabled = value; drawingGestureRecognizer.isEnabled = !value
        if !value { points = []; selected = []; selectionChanged?(0) }
    }
    @objc private func selectInk(_ gesture: UIPanGestureRecognizer) {
        if gesture.state == .began { points = []; selected = [] }
        points.append(gesture.location(in: self)); setNeedsDisplay()
        if gesture.state == .ended {
            selected = InkSelection.indices(in: drawing, polygon: points)
            selectionChanged?(selected.count)
        }
    }
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        guard lassoMode, points.count > 1 else { return }
        let path = UIBezierPath(); path.move(to: points[0]); points.dropFirst().forEach { path.addLine(to: $0) }; path.close()
        UIColor.systemBlue.setStroke(); path.lineWidth = 2; path.setLineDash([5, 4], count: 2, phase: 0); path.stroke()
    }
}
