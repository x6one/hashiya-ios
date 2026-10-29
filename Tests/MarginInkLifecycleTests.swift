import XCTest
import SwiftUI
import PencilKit
@testable import Hashiya

final class MarginInkLifecycleTests: XCTestCase {
    @MainActor func testSwitchingNotesToTextFlushesUnfinishedInkToItsOriginalFile() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let notebook = UUID()
        let notes = MarginPages(root: root, notebook: notebook)
        let originalPage = try XCTUnwrap(notes.currentID)
        let originalInk = try XCTUnwrap(notes.current?.ink)
        notes.editor.handwriting = true
        let control = MarginCanvasControl()
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousWindow = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene); window.frame = scene.coordinateSpace.bounds
        let pane = MarginPane(store: notes, editor: notes.editor, sourcePage: 1,
                              expanded: true, toggleExpanded: {}, jump: { _ in },
                              inkSaved: { _, _ in }, textSaved: { _, _ in },
                              externalCanvasControl: control, showsInkToolbar: false)
        let host = UIHostingController(rootView: pane)
        window.rootViewController = host; window.makeKeyAndVisible(); host.view.layoutIfNeeded()
        defer { window.isHidden = true; window.rootViewController = nil; previousWindow?.makeKeyAndVisible() }
        let mounted = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            control.canvas?.window === window
                && (control.canvas?.delegate as? MarginNotebook.Coordinator)?.pageID == originalPage
        }, object: nil)
        guard XCTWaiter.wait(for: [mounted], timeout: 3) == .completed else {
            XCTFail("The actual Notes representable must mount before its lifecycle is exercised"); return
        }
        let canvas = try XCTUnwrap(control.canvas)
        let coordinator = try XCTUnwrap(canvas.delegate as? MarginNotebook.Coordinator)
        let points = [CGPoint(x: 20, y: 30), CGPoint(x: 120, y: 70)].map {
            PKStrokePoint(location: $0, timeOffset: 0, size: CGSize(width: 4, height: 4),
                          opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
        }
        let ink = PKDrawing(strokes: [PKStroke(ink: PKInk(.pen, color: .red),
            path: PKStrokePath(controlPoints: points, creationDate: Date()))])
        // A second interaction can remove the handwriting subtree before
        // PencilKit delivers its final tool-end callback. Exercise that order
        // through the real delegate, representable and atomic Notes store.
        coordinator.canvasViewDidBeginUsingTool(canvas)
        canvas.drawing = ink
        coordinator.canvasViewDrawingDidChange(canvas)
        XCTAssertTrue(coordinator.isStroking)
        XCTAssertEqual(notes.current?.ink, originalInk, "Live frames remain buffered until a commit boundary")
        notes.editor.handwriting = false
        host.view.setNeedsLayout(); host.view.layoutIfNeeded()
        let removed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in canvas.window == nil }, object: nil)
        guard XCTWaiter.wait(for: [removed], timeout: 3) == .completed else {
            XCTFail("The actual mode transition must dismantle the old handwriting view"); return
        }
        // Do not synthesize a later end callback: teardown itself must preserve
        // the last available PKDrawing, including an interrupted final stroke.
        let reopened = MarginPages(root: root, notebook: notebook)
        let data = try XCTUnwrap(reopened.pages.first { $0.id == originalPage }?.ink)
        let restored = data.isEmpty ? PKDrawing() : try PKDrawing(data: data)
        let pageFile = notes.folder.appendingPathComponent(originalPage.uuidString + ".json")
        let evidence = XCTAttachment(data: try Data(contentsOf: pageFile), uniformTypeIdentifier: "public.json")
        evidence.name = "ActualNotesPageAfterModeTeardown"; evidence.lifetime = .keepAlways; add(evidence)
        XCTAssertEqual(restored.strokes.count, 1, "Changing Notes mode must save unfinished ink before removing its canvas")
        XCTAssertEqual(restored.bounds, ink.bounds)
        XCTAssertEqual(reopened.currentID, originalPage)
        XCTAssertNil(reopened.error)
    }
}
