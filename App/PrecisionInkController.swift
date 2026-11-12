import UIKit
import PencilKit

enum InkCommitReason: Equatable { case newStroke, edit, history }

/// Interface checkpoint for focused native-history/gesture contracts.
@MainActor final class PrecisionInkController: NSObject {
    weak var canvas: PKCanvasView?
    var didCommit: ((PKDrawing, InkCommitReason) -> Void)?
    var selectionDidChange: ((Int) -> Void)?
    private(set) var selectedIndices: [Int] = []
    let lineGesture = UIPanGestureRecognizer()
    init(canvas: PKCanvasView) { self.canvas = canvas; super.init() }
    @discardableResult func replaceDrawing(_ drawing: PKDrawing, reason: InkCommitReason, actionName: String) -> Bool { false }
    func select(_ indices: [Int]) {}
    @discardableResult func editSelection(_ operation: InkEditOperation) -> Bool { false }
    func configure(mode: InkGeometryMode, selection: Bool, ruler: Bool, brush: InkBrush, color: UIColor, width: CGFloat, enabled: Bool) {}
    func nativeToolBegan() {}
    func nativeDrawingChanged() {}
    func nativeToolEnded() {}
    func cancelInteraction() {}
    func resetForLoadedPage() {}
    func beginLine(at point: CGPoint) {}
    func updateLine(to point: CGPoint) {}
    @discardableResult func finishLine(at point: CGPoint) -> Bool { false }
    static func drawingPoint(_ point: CGPoint, in canvas: PKCanvasView) -> CGPoint { point }
}
