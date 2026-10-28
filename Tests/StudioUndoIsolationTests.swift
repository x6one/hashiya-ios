import XCTest
import SwiftUI
import PencilKit
import PDFKit
@testable import Hashiya

private struct ProductionSplitUndoHost: View {
    @ObservedObject var workspace: PDFWorkspace
    @ObservedObject var notes: MarginPages
    let control: MarginCanvasControl
    var body: some View {
        HStack(spacing: 0) {
            NativePDF(workspace: workspace).frame(maxWidth: .infinity)
            MarginPane(store: notes, editor: notes.editor, sourcePage: workspace.page,
                       expanded: false, toggleExpanded: {}, jump: { _ in },
                       inkSaved: { _, _ in }, textSaved: { _, _ in },
                       externalCanvasControl: control, showsInkToolbar: false)
                .frame(maxWidth: .infinity)
        }
    }
}

/// Tests the retained production PDFKit overlay and workspace action route.
/// Programmatically registered operations isolate routing; only the unchanged
/// real-stroke XCUITest can prove PencilKit's gesture registration and hit area.
final class StudioUndoIsolationTests: XCTestCase {
    @MainActor private func apply(_ drawing: PKDrawing, to canvas: PKCanvasView) {
        let previous = canvas.drawing
        canvas.undoManager?.registerUndo(withTarget: canvas) { target in
            self.apply(previous, to: target)
        }
        canvas.drawing = drawing
    }

    @MainActor private func verifyMountedUndo(retainAcrossUpdate: Bool) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let library = LibraryStore(root: root, seedDemo: false)
        let workspace = PDFWorkspace(note: try library.installDemonstration(), root: root)
        workspace.tool = .ink
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousWindow = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 440, height: 956)
        let host = UIHostingController(rootView: NativePDF(workspace: workspace))
        window.rootViewController = host; window.makeKeyAndVisible(); host.view.layoutIfNeeded()
        defer { window.isHidden = true; window.rootViewController = nil; previousWindow?.makeKeyAndVisible() }
        func canvases(in view: UIView) -> [LassoCanvas] {
            (view as? LassoCanvas).map { [$0] } ?? view.subviews.flatMap { canvases(in: $0) }
        }
        let mounted = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard let pdf = workspace.view else { return false }
            return canvases(in: pdf).contains { $0.tag == 0 && $0.window === window }
        }, object: nil)
        guard XCTWaiter.wait(for: [mounted], timeout: 3) == .completed else {
            XCTFail("Production PDFKit must mount its actual first-page overlay before testing Undo"); return
        }
        let pdf = try XCTUnwrap(workspace.view)
        let canvas = try XCTUnwrap(canvases(in: pdf).first { $0.tag == 0 })
        XCTAssertTrue(canvas.becomeFirstResponder())
        let manager = try XCTUnwrap(canvas.undoManager)
        manager.removeAllActions()
        let groupedByEvent = manager.groupsByEvent
        manager.groupsByEvent = false
        defer { manager.removeAllActions(); manager.groupsByEvent = groupedByEvent }
        let points = [CGPoint(x: 20, y: 30), CGPoint(x: 120, y: 70)].map {
            PKStrokePoint(location: $0, timeOffset: 0, size: CGSize(width: 4, height: 4),
                          opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
        }
        let ink = PKDrawing(strokes: [PKStroke(ink: PKInk(.pen, color: .red),
            path: PKStrokePath(controlPoints: points, creationDate: Date()))])
        manager.beginUndoGrouping(); apply(ink, to: canvas); manager.endUndoGrouping()
        XCTAssertTrue(manager.canUndo, "The mounted PDF canvas must own a known operation before testing routing")
        if retainAcrossUpdate {
            host.rootView = NativePDF(workspace: workspace, presented: false)
            host.view.setNeedsLayout(); host.view.layoutIfNeeded()
            let hidden = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in pdf.isHidden }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [hidden], timeout: 3), .completed)
            host.rootView = NativePDF(workspace: workspace)
            host.view.setNeedsLayout(); host.view.layoutIfNeeded()
            let shown = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in !pdf.isHidden }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [shown], timeout: 3), .completed)
        }
        XCTAssertTrue(workspace.view === pdf)
        XCTAssertTrue(canvases(in: pdf).contains { $0 === canvas })
        XCTAssertTrue(canvas.undoManager === manager)
        let action = try XCTUnwrap(workspace.inkAction)
        action("undo")
        XCTAssertEqual(canvas.drawing.strokes.count, 0, "The retained workspace callback must reach the actual mounted PDF canvas")
        XCTAssertTrue(manager.canRedo)
        action("redo")
        XCTAssertEqual(canvas.drawing.strokes.count, 1, "Redo must use the same native manager")
        XCTAssertEqual(canvas.drawing.bounds, ink.bounds)
        XCTAssertEqual(workspace.page, 1)
    }

    @MainActor func testMountedDocumentUndoAndRedoUseTheRealPDFOverlay() throws {
        try verifyMountedUndo(retainAcrossUpdate: false)
    }

    @MainActor func testRetainedPDFPresentationKeepsItsUndoOwnerAndActionRoute() throws {
        try verifyMountedUndo(retainAcrossUpdate: true)
    }

    @MainActor func testSwitchingNotesPagePreservesDocumentUndoInActualSplit() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let library = LibraryStore(root: root, seedDemo: false)
        let note = try library.installDemonstration()
        let workspace = PDFWorkspace(note: note, root: root)
        let notes = MarginPages(root: root, notebook: note.id)
        notes.editor.handwriting = true; workspace.tool = .ink
        let control = MarginCanvasControl()
        let originalPageIDs = notes.pages.map(\.id)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousWindow = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene); window.frame = scene.coordinateSpace.bounds
        let host = UIHostingController(rootView: ProductionSplitUndoHost(workspace: workspace, notes: notes, control: control))
        window.rootViewController = host; window.makeKeyAndVisible(); host.view.layoutIfNeeded()
        defer { window.isHidden = true; window.rootViewController = nil; previousWindow?.makeKeyAndVisible() }
        func documentCanvas(in view: UIView) -> LassoCanvas? {
            if let canvas = view as? LassoCanvas, canvas.tag == 0 { return canvas }
            return view.subviews.lazy.compactMap { documentCanvas(in: $0) }.first
        }
        let mounted = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard let pdf = workspace.view else { return false }
            return documentCanvas(in: pdf)?.window === window && control.canvas?.window === window
                && (control.canvas?.delegate as? MarginNotebook.Coordinator)?.pageID == notes.currentID
        }, object: nil)
        guard XCTWaiter.wait(for: [mounted], timeout: 3) == .completed else {
            XCTFail("Both actual production writing surfaces must mount before testing page reload"); return
        }
        let canvas = try XCTUnwrap(documentCanvas(in: try XCTUnwrap(workspace.view)))
        XCTAssertTrue(canvas.becomeFirstResponder())
        let manager = try XCTUnwrap(canvas.undoManager)
        manager.removeAllActions()
        let groupedByEvent = manager.groupsByEvent; manager.groupsByEvent = false
        defer { manager.removeAllActions(); manager.groupsByEvent = groupedByEvent }
        let points = [CGPoint(x: 20, y: 30), CGPoint(x: 120, y: 70)].map {
            PKStrokePoint(location: $0, timeOffset: 0, size: CGSize(width: 4, height: 4),
                          opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
        }
        let ink = PKDrawing(strokes: [PKStroke(ink: PKInk(.pen, color: .red),
            path: PKStrokePath(controlPoints: points, creationDate: Date()))])
        manager.beginUndoGrouping(); apply(ink, to: canvas); manager.endUndoGrouping()
        XCTAssertTrue(manager.canUndo, "The actual document canvas must own the operation before Notes changes")
        XCTAssertTrue(notes.add(linkedTo: workspace.page))
        let updated = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            (control.canvas?.delegate as? MarginNotebook.Coordinator)?.pageID == notes.currentID
        }, object: nil)
        guard XCTWaiter.wait(for: [updated], timeout: 3) == .completed else {
            XCTFail("The real Notes representable must finish loading its new page"); return
        }
        XCTAssertEqual(Array(notes.pages.dropLast()).map(\.id), originalPageIDs, "All original Notes pages remain intact")
        XCTAssertTrue(manager.canUndo, "Loading a different Notes page must not clear document drawing history")
        let action = try XCTUnwrap(workspace.inkAction)
        action("undo")
        XCTAssertEqual(canvas.drawing.strokes.count, 0, "Document Undo must survive an actual split Notes page reload")
        XCTAssertEqual(control.canvas?.drawing.strokes.count, 0, "Document Undo must not modify Notes")
        action("redo")
        XCTAssertEqual(canvas.drawing.strokes.count, 1)
        XCTAssertEqual(notes.current?.sourcePage, workspace.page)
    }
}
