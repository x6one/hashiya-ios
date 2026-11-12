import XCTest
import UIKit
import PencilKit
@testable import Hashiya

final class PrecisionInkControllerTests: XCTestCase {
    private func drawing(_ y: CGFloat) -> PKDrawing {
        let samples = [CGPoint(x: 20, y: y), CGPoint(x: 90, y: y + 10), CGPoint(x: 160, y: y)].enumerated().map { index, point in
            PKStrokePoint(location: point, timeOffset: Double(index) * 0.02, size: CGSize(width: 4, height: 4), opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
        }
        return PKDrawing(strokes: [PKStroke(ink: PKInk(.pen, color: .red), path: PKStrokePath(controlPoints: samples, creationDate: Date(timeIntervalSince1970: 90)))])
    }
    @MainActor func testOneEditUndoRedoRetainsOlderHistoryOnBothRealCanvasClasses() throws {
        let original = drawing(40), edited = drawing(80)
        let canvases: [PKCanvasView] = [LassoCanvas(frame: .zero), MarginCanvas(frame: .zero)]
        for canvas in canvases {
            let manager = try XCTUnwrap(canvas.undoManager); manager.groupsByEvent = false
            canvas.drawing = original; manager.removeAllActions()
            manager.beginUndoGrouping()
            manager.registerUndo(withTarget: canvas) { target in target.drawing = PKDrawing() }
            manager.endUndoGrouping()
            let controller = PrecisionInkController(canvas: canvas)
            var reasons: [InkCommitReason] = []
            controller.didCommit = { _, reason in reasons.append(reason) }
            XCTAssertTrue(controller.replaceDrawing(edited, reason: .edit, actionName: "استقامة"))
            XCTAssertEqual(canvas.drawing.dataRepresentation(), edited.dataRepresentation())
            for _ in 0..<2 {
                manager.undo(); XCTAssertEqual(canvas.drawing.dataRepresentation(), original.dataRepresentation())
                XCTAssertTrue(manager.canRedo)
                manager.redo(); XCTAssertEqual(canvas.drawing.dataRepresentation(), edited.dataRepresentation())
            }
            XCTAssertEqual(reasons.count, 5, "One durable commit per edit/history action, no setter duplicate")
            XCTAssertEqual(reasons.first, .edit)
            XCTAssertTrue(reasons.dropFirst().allSatisfy { $0 == .history })
            manager.undo(); XCTAssertTrue(manager.canUndo, "The precision edit must not erase older history")
            manager.undo(); XCTAssertTrue(canvas.drawing.strokes.isEmpty)
            manager.removeAllActions()
        }
    }
    @MainActor func testNoOpDoesNotAddUndoAndInvalidSelectionDoesNotEdit() throws {
        let canvas = LassoCanvas(frame: .zero); canvas.drawing = drawing(40)
        let manager = try XCTUnwrap(canvas.undoManager); manager.groupsByEvent = false; manager.removeAllActions()
        let controller = PrecisionInkController(canvas: canvas)
        XCTAssertFalse(controller.replaceDrawing(canvas.drawing, reason: .edit, actionName: "استقامة"))
        controller.select([0, 80]); XCTAssertFalse(controller.editSelection(.straighten))
        XCTAssertFalse(manager.canUndo)
    }
    @MainActor func testNativeChangeInvalidatesSelectedIndicesBeforeAnotherEdit() {
        let canvas = LassoCanvas(frame: .zero); canvas.drawing = drawing(40)
        let controller = PrecisionInkController(canvas: canvas)
        controller.select([0]); XCTAssertEqual(controller.selectedIndices, [0])
        controller.nativeToolBegan(); canvas.drawing = drawing(100)
        controller.nativeDrawingChanged(); controller.nativeToolEnded()
        let current = canvas.drawing.dataRepresentation()
        XCTAssertFalse(controller.editSelection(.recolor(.blue)))
        XCTAssertEqual(canvas.drawing.dataRepresentation(), current)
    }
    @MainActor func testNativeRulerAndDirectLineUseExclusiveGesturePolicies() {
        let canvas = MarginCanvas(frame: CGRect(x: 0, y: 0, width: 500, height: 700))
        let controller = PrecisionInkController(canvas: canvas)
        controller.configure(mode: .freehand, selection: false, ruler: true, brush: .pen, color: .black, width: 3, enabled: true)
        XCTAssertTrue(canvas.isRulerActive)
        XCTAssertTrue(canvas.drawingGestureRecognizer.isEnabled)
        controller.configure(mode: .line, selection: false, ruler: false, brush: .pen, color: .black, width: 3, enabled: true)
        XCTAssertFalse(canvas.isRulerActive)
        XCTAssertFalse(canvas.drawingGestureRecognizer.isEnabled)
        XCTAssertTrue(controller.lineGesture.isEnabled)
    }
    @MainActor func testDrawingCoordinateConversionDoesNotApplyOffsetTwice() {
        let canvas = MarginCanvas(frame: CGRect(x: 0, y: 0, width: 500, height: 700))
        canvas.minimumZoomScale = 0.1; canvas.maximumZoomScale = 4
        canvas.contentSize = CGSize(width: 1200, height: 1600)
        canvas.zoomScale = 0.5; canvas.contentOffset = CGPoint(x: 40, y: 60)
        XCTAssertEqual(canvas.zoomScale, 0.5, accuracy: 0.001)
        // Gesture points in the scroll view's bounds already contain its contentOffset.
        XCTAssertEqual(PrecisionInkController.drawingPoint(CGPoint(x: 120, y: 80), in: canvas), CGPoint(x: 240, y: 160))
    }
    @MainActor func testNativeStrokeDefersChangedToolAndRulerUntilItsCommitEnds() {
        let canvas = MarginCanvas(frame: .zero)
        // Retain the actual owner throughout the active native interval.
        let owner = PrecisionInkController(canvas: canvas)
        owner.configure(mode: .freehand, selection: false, ruler: false, brush: .pen, color: .red, width: 3, enabled: true)
        owner.nativeToolBegan()
        owner.configure(mode: .freehand, selection: false, ruler: true, brush: .pencil, color: .blue, width: 5, enabled: true)
        XCTAssertEqual((canvas.tool as? PKInkingTool)?.inkType, .pen)
        XCTAssertFalse(canvas.isRulerActive)
        owner.nativeToolEnded()
        XCTAssertEqual((canvas.tool as? PKInkingTool)?.inkType, .pencil)
        XCTAssertTrue(canvas.isRulerActive)
    }
    @MainActor func testPrecisionUndoStillWorksAfterReturningToReadMode() throws {
        let canvas = LassoCanvas(frame: .zero); canvas.drawing = drawing(40)
        let manager = try XCTUnwrap(canvas.undoManager); manager.groupsByEvent = false; manager.removeAllActions()
        let controller = PrecisionInkController(canvas: canvas)
        controller.configure(mode: .freehand, selection: false, ruler: false, brush: .pen, color: .red, width: 3, enabled: true)
        XCTAssertTrue(controller.replaceDrawing(drawing(80), reason: .edit, actionName: "Edit"))
        controller.configure(mode: .freehand, selection: false, ruler: false, brush: .pen, color: .red, width: 3, enabled: false)
        manager.undo(); XCTAssertEqual(canvas.drawing.strokes[0].path[0].location.y, 40)
        manager.redo(); XCTAssertEqual(canvas.drawing.strokes[0].path[0].location.y, 80)
        manager.removeAllActions()
    }
    @MainActor func testUnwritableSurfaceCannotBeEditedOrReceiveNewLines() {
        let canvas = LassoCanvas(frame: .zero); canvas.drawing = drawing(40)
        let controller = PrecisionInkController(canvas: canvas), original = canvas.drawing.dataRepresentation()
        controller.configure(mode: .line, selection: false, ruler: false, brush: .pen, color: .blue, width: 3, enabled: true, writable: false)
        XCTAssertFalse(controller.replaceDrawing(drawing(80), reason: .edit, actionName: "Edit"))
        controller.beginLine(at: CGPoint(x: 20, y: 40))
        XCTAssertFalse(controller.finishLine(at: CGPoint(x: 120, y: 40)))
        XCTAssertEqual(canvas.drawing.dataRepresentation(), original)
    }
    @MainActor func testCancelledOrReloadedDirectLineDoesNotCommitPreview() throws {
        let canvas = LassoCanvas(frame: CGRect(x: 0, y: 0, width: 500, height: 700)); canvas.drawing = drawing(40)
        let manager = try XCTUnwrap(canvas.undoManager); manager.groupsByEvent = false; manager.removeAllActions()
        let controller = PrecisionInkController(canvas: canvas)
        controller.configure(mode: .line, selection: false, ruler: false, brush: .pen, color: .black, width: 3, enabled: true)
        let before = canvas.drawing.dataRepresentation()
        controller.beginLine(at: CGPoint(x: 20, y: 40)); controller.updateLine(to: CGPoint(x: 120, y: 50))
        XCTAssertEqual(canvas.drawing.dataRepresentation(), before, "Live preview cannot serialize or replace real ink")
        controller.cancelInteraction(); XCTAssertFalse(controller.finishLine(at: CGPoint(x: 120, y: 50)))
        controller.beginLine(at: CGPoint(x: 20, y: 40)); controller.resetForLoadedPage()
        XCTAssertFalse(controller.finishLine(at: CGPoint(x: 120, y: 50)))
        XCTAssertEqual(canvas.drawing.dataRepresentation(), before); XCTAssertFalse(manager.canUndo)
    }
    @MainActor func testCompletedDirectHighlighterAddsExactlyOneUndoableUniformStroke() throws {
        let canvas = MarginCanvas(frame: CGRect(x: 0, y: 0, width: 500, height: 700))
        let manager = try XCTUnwrap(canvas.undoManager); manager.groupsByEvent = false; manager.removeAllActions()
        let controller = PrecisionInkController(canvas: canvas)
        var commits: [InkCommitReason] = []; controller.didCommit = { _, reason in commits.append(reason) }
        controller.configure(mode: .highlighter, selection: false, ruler: false, brush: .marker, color: .yellow, width: 5, enabled: true)
        controller.beginLine(at: CGPoint(x: 20, y: 40)); controller.updateLine(to: CGPoint(x: 120, y: 50))
        XCTAssertTrue(canvas.drawing.strokes.isEmpty)
        XCTAssertTrue(controller.finishLine(at: CGPoint(x: 120, y: 50)))
        XCTAssertEqual(canvas.drawing.strokes.count, 1)
        let stroke = try XCTUnwrap(canvas.drawing.strokes.first)
        XCTAssertEqual(stroke.ink.inkType, .marker)
        for point in stroke.path { XCTAssertEqual(point.size, CGSize(width: 20, height: 20)) }
        XCTAssertEqual(commits, [.newStroke])
        manager.undo(); XCTAssertTrue(canvas.drawing.strokes.isEmpty)
        manager.redo(); XCTAssertEqual(canvas.drawing.strokes.count, 1)
        XCTAssertEqual(commits, [.newStroke, .history, .history])
        manager.removeAllActions()
    }
}
