import Foundation

/// Each canvas owns one instance for its whole lifetime. UIKit/PencilKit use it
/// on the main thread. Registering and grouping native strokes remain untouched;
/// an unfinished gesture blocks execution before an action can be consumed.
final class CanvasUndoManager: UndoManager {
    var interactionActive = false
    override var canUndo: Bool { !interactionActive && super.canUndo }
    override var canRedo: Bool { !interactionActive && super.canRedo }
    override func undo() { guard !interactionActive else { return }; super.undo() }
    override func redo() { guard !interactionActive else { return }; super.redo() }
}
