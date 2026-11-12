import XCTest
import SwiftUI
import PDFKit
import PencilKit
@testable import Hashiya

final class PrecisionInkPersistenceTests: XCTestCase {
    private func wavy() -> PKDrawing {
        let points = [CGPoint(x: 30, y: 80), CGPoint(x: 90, y: 93), CGPoint(x: 160, y: 80)].enumerated().map { index, point in
            PKStrokePoint(location: point, timeOffset: Double(index) * 0.02, size: CGSize(width: 4, height: 4), opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
        }
        return PKDrawing(strokes: [PKStroke(ink: PKInk(.pen, color: .red), path: PKStrokePath(controlPoints: points, creationDate: Date(timeIntervalSince1970: 70)))])
    }
    @MainActor func testDocumentSelectionActionSavesAndUndoRedoDoNotCreateAudioWritingMarkers() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let library = LibraryStore(root: root, seedDemo: false); library.create("Precision storage")
        let note = try XCTUnwrap(library.notebooks.first), original = wavy()
        let workspace = PDFWorkspace(note: note, root: root)
        let coordinator = NativePDF.Coordinator(workspace: workspace)
        let canvas = try XCTUnwrap(coordinator.pdfView(PDFView(), overlayViewFor: try XCTUnwrap(workspace.document.page(at: 0))) as? LassoCanvas)
        var markers = 0; workspace.onInkSaved = { _, _ in markers += 1 }
        coordinator.canvasViewDidBeginUsingTool(canvas); canvas.drawing = original
        coordinator.canvasViewDrawingDidChange(canvas); coordinator.canvasViewDidEndUsingTool(canvas)
        XCTAssertEqual(markers, 1)
        workspace.export()
        let beforeURL = try XCTUnwrap(workspace.exported)
        defer { try? FileManager.default.removeItem(at: beforeURL) }
        let beforeImage = try XCTUnwrap(PDFDocument(url: beforeURL)?.page(at: 0)?.thumbnail(of: CGSize(width: 650, height: 900), for: .mediaBox).pngData())
        workspace.tool = .lasso; coordinator.setDrawing(true); canvas.selected = [0]
        coordinator.applyInkAction("straighten")
        let url = workspace.storage.appendingPathComponent("0.drawing")
        let saved = try PKDrawing(data: Data(contentsOf: url))
        XCTAssertEqual(saved.strokes[0].path[1].location.y, 80, accuracy: 0.001)
        XCTAssertEqual(markers, 1)
        coordinator.applyInkAction("undo")
        XCTAssertEqual(try PKDrawing(data: Data(contentsOf: url)).strokes[0].path[1].location.y, 93, accuracy: 0.001)
        coordinator.applyInkAction("redo")
        XCTAssertEqual(try PKDrawing(data: Data(contentsOf: url)).strokes[0].path[1].location.y, 80, accuracy: 0.001)
        XCTAssertEqual(markers, 1, "An edit or its history cannot manufacture new writing timestamps")
        workspace.export()
        let afterURL = try XCTUnwrap(workspace.exported)
        defer { try? FileManager.default.removeItem(at: afterURL) }
        let afterImage = try XCTUnwrap(PDFDocument(url: afterURL)?.page(at: 0)?.thumbnail(of: CGSize(width: 650, height: 900), for: .mediaBox).pngData())
        XCTAssertNotEqual(beforeImage, afterImage, "The actual exported PDF must visibly contain the edited geometry")
        let reopened = PDFWorkspace(note: note, root: root)
        XCTAssertEqual(try reopened.loadDrawing(on: 0).dataRepresentation(), saved.dataRepresentation())
        XCTAssertEqual(reopened.page, 1)
    }
    @MainActor func testMountedNotesPrecisionEditsPersistWithoutWritingMarkersAndKeepOldPageIDs() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let notebookID = UUID()
        let notes = MarginPages(root: root, notebook: notebookID); notes.editor.handwriting = true
        let pageID = try XCTUnwrap(notes.currentID), ids = notes.pages.map(\.id), control = MarginCanvasControl()
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previous = scene.windows.first { $0.isKeyWindow }, window = UIWindow(windowScene: scene)
        window.frame = scene.coordinateSpace.bounds
        var markers = 0
        let pane = MarginPane(store: notes, editor: notes.editor, sourcePage: 1, expanded: true, toggleExpanded: {}, jump: { _ in },
                              inkSaved: { _, _ in markers += 1 }, textSaved: { _, _ in }, externalCanvasControl: control, showsInkToolbar: false)
        let host = UIHostingController(rootView: pane); window.rootViewController = host; window.makeKeyAndVisible(); host.view.layoutIfNeeded()
        defer { window.isHidden = true; window.rootViewController = nil; previous?.makeKeyAndVisible() }
        let mounted = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            control.canvas?.window === window && (control.canvas?.delegate as? MarginNotebook.Coordinator)?.pageID == pageID
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [mounted], timeout: 3), .completed)
        let canvas = try XCTUnwrap(control.canvas), coordinator = try XCTUnwrap(canvas.delegate as? MarginNotebook.Coordinator)
        coordinator.canvasViewDidBeginUsingTool(canvas); canvas.drawing = wavy()
        coordinator.canvasViewDrawingDidChange(canvas); coordinator.canvasViewDidEndUsingTool(canvas)
        let nativeSaved = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in markers == 1 }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [nativeSaved], timeout: 3), .completed)
        notes.editor.brush = .selection
        canvas.precisionInk.select([0]); control.action("straighten")
        let edited = try PKDrawing(data: try XCTUnwrap(notes.current?.ink))
        XCTAssertEqual(edited.strokes[0].path[1].location.y, 80, accuracy: 0.001)
        control.action("undo")
        XCTAssertEqual(try PKDrawing(data: try XCTUnwrap(notes.current?.ink)).strokes[0].path[1].location.y, 93, accuracy: 0.001)
        control.action("redo")
        XCTAssertEqual(try PKDrawing(data: try XCTUnwrap(notes.current?.ink)).strokes[0].path[1].location.y, 80, accuracy: 0.001)
        // Drain normal queued publication, then verify it did not enqueue writing callbacks.
        let published = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in notes.current?.ink == canvas.drawing.dataRepresentation() }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [published], timeout: 3), .completed)
        XCTAssertEqual(markers, 1)
        XCTAssertEqual(notes.pages.map(\.id), ids)
        let reopened = MarginPages(root: root, notebook: notebookID)
        XCTAssertEqual(reopened.currentID, pageID)
        XCTAssertEqual(reopened.current?.ink, notes.current?.ink)
        let committed = canvas.drawing.dataRepresentation()
        notes.editor.inkGeometry = .line
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in canvas.precisionInk.lineGesture.isEnabled }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 3), .completed)
        canvas.precisionInk.beginLine(at: CGPoint(x: 20, y: 100))
        XCTAssertTrue(notes.add(linkedTo: 2))
        let switched = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in coordinator.pageID == notes.currentID && coordinator.pageID != pageID }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [switched], timeout: 3), .completed)
        XCTAssertFalse(canvas.precisionInk.finishLine(at: CGPoint(x: 120, y: 100)))
        XCTAssertTrue(canvas.drawing.strokes.isEmpty, "A preview begun on the previous Notes page cannot land on the new one")
        XCTAssertEqual(notes.pages.first(where: { $0.id == pageID })?.ink, committed)
    }
}
