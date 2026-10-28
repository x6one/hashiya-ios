import XCTest
import SwiftUI
import PencilKit
@testable import Hashiya

private struct UndoCanvasPair: UIViewRepresentable {
    let first: PKCanvasView
    let second: PKCanvasView
    func makeUIView(context: Context) -> UIView {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 440, height: 956))
        first.frame = CGRect(x: 0, y: 0, width: 210, height: 500)
        second.frame = CGRect(x: 220, y: 0, width: 210, height: 500)
        container.addSubview(first); container.addSubview(second)
        return container
    }
    func updateUIView(_ view: UIView, context: Context) {}
}

final class StudioUndoIsolationTests: XCTestCase {
    @MainActor private func verifyIndependentUndo(active: PKCanvasView, reloaded: PKCanvasView) throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousWindow = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 440, height: 956)
        let host = UIHostingController(rootView: UndoCanvasPair(first: active, second: reloaded))
        window.rootViewController = host; window.makeKeyAndVisible(); host.view.layoutIfNeeded()
        defer { window.isHidden = true; window.rootViewController = nil; previousWindow?.makeKeyAndVisible() }
        let mounted = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            active.window === window && reloaded.window === window
        }, object: nil)
        guard XCTWaiter.wait(for: [mounted], timeout: 3) == .completed else {
            XCTFail("Both real canvases must mount in the native window before testing Undo"); return
        }
        XCTAssertTrue(active.becomeFirstResponder())
        let points = [CGPoint(x: 20, y: 30), CGPoint(x: 120, y: 70)].map {
            PKStrokePoint(location: $0, timeOffset: 0, size: CGSize(width: 4, height: 4),
                          opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
        }
        let empty = PKDrawing()
        active.drawing = PKDrawing(strokes: [PKStroke(ink: PKInk(.pen, color: .red),
            path: PKStrokePath(controlPoints: points, creationDate: Date()))])
        let manager = try XCTUnwrap(active.undoManager)
        manager.removeAllActions()
        let groupedByEvent = manager.groupsByEvent
        manager.groupsByEvent = false
        defer { manager.removeAllActions(); manager.groupsByEvent = groupedByEvent }
        manager.beginUndoGrouping()
        manager.registerUndo(withTarget: active) { canvas in canvas.drawing = empty }
        manager.endUndoGrouping()
        XCTAssertTrue(manager.canUndo, "The active real canvas must have native undo history before its peer reloads")
        // This is the actual reset primitive used while a different Notes page
        // is loaded. It must never remove another canvas's fresh drawing undo.
        reloaded.undoManager?.removeAllActions()
        manager.undo()
        XCTAssertEqual(active.drawing.strokes.count, 0, "Reloading the peer canvas must preserve active drawing Undo")
        XCTAssertEqual(reloaded.drawing.strokes.count, 0)
    }

    @MainActor func testReloadingNotesCannotClearDocumentDrawingUndo() throws {
        try verifyIndependentUndo(active: LassoCanvas(frame: .zero), reloaded: MarginCanvas(frame: .zero))
    }

    @MainActor func testReloadingDocumentCannotClearNotesDrawingUndo() throws {
        try verifyIndependentUndo(active: MarginCanvas(frame: .zero), reloaded: LassoCanvas(frame: .zero))
    }
}
