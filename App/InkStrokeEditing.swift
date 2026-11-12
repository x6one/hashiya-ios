import UIKit
import PencilKit

enum InkGeometryMode: String, CaseIterable {
    case freehand, line, highlighter
}
enum InkEditOperation {
    case straighten
    case recolor(UIColor)
    case width(CGFloat)
}
/// Geometry contracts; behavior is implemented only after the new regression tests fail.
enum InkStrokeEditing {
    static func applying(_ edit: InkEditOperation, to drawing: PKDrawing, indices: [Int]) -> PKDrawing? { nil }
    static func hitIndex(in drawing: PKDrawing, at point: CGPoint, tolerance: CGFloat) -> Int? { nil }
    static func line(from start: CGPoint, to end: CGPoint, ink: PKInk, width: CGFloat, creationDate: Date) -> PKStroke? { nil }
}
