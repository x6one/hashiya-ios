import XCTest
import SwiftUI
import PencilKit
import Combine
@testable import Hashiya

final class MarginInkLifecycleTests: XCTestCase {
    @MainActor func testNotesStrokeCommitsBeforePublishingIntoSwiftUI() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let notes = MarginPages(root: root, notebook: UUID())
        let pageID = try XCTUnwrap(notes.currentID)
        notes.editor.handwriting = true
        let control = MarginCanvasControl()
        var insideNativeCallback = false
        var inlinePublications = 0, inlinePresentationEffects = 0, savedEffects = 0
        let pane = MarginPane(store: notes, editor: notes.editor, sourcePage: 1,
                              expanded: true, toggleExpanded: {}, jump: { _ in },
                              inkSaved: { _, id in
                                  XCTAssertEqual(id, pageID)
                                  savedEffects += 1
                                  if insideNativeCallback { inlinePresentationEffects += 1 }
                              }, textSaved: { _, _ in },
                              externalCanvasControl: control, showsInkToolbar: false)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousWindow = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene); window.frame = scene.coordinateSpace.bounds
        let host = UIHostingController(rootView: pane)
        window.rootViewController = host; window.makeKeyAndVisible(); host.view.layoutIfNeeded()
        defer { window.isHidden = true; window.rootViewController = nil; previousWindow?.makeKeyAndVisible() }
        let mounted = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            control.canvas?.window === window
                && (control.canvas?.delegate as? MarginNotebook.Coordinator)?.pageID == pageID
        }, object: nil)
        guard XCTWaiter.wait(for: [mounted], timeout: 3) == .completed else {
            XCTFail("The production Notes canvas must mount before committing a stroke"); return
        }
        let canvas = try XCTUnwrap(control.canvas)
        let coordinator = try XCTUnwrap(canvas.delegate as? MarginNotebook.Coordinator)
        let observer = notes.objectWillChange.sink { if insideNativeCallback { inlinePublications += 1 } }
        defer { observer.cancel() }
        let points = [CGPoint(x: 20, y: 30), CGPoint(x: 120, y: 70)].map {
            PKStrokePoint(location: $0, timeOffset: 0, size: CGSize(width: 4, height: 4),
                          opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
        }
        let stroke = PKStroke(ink: PKInk(.pen, color: .red),
                              path: PKStrokePath(controlPoints: points, creationDate: Date()))
        // PencilKit can end its tool before delivering the final drawing change.
        // Both real delegate orders must commit bytes before notifying SwiftUI
        // or the parent workspace that consumes the saved-ink callback.
        for (index, changeAfterEnd) in [false, true].enumerated() {
            let beforeEffects = savedEffects
            let ink = PKDrawing(strokes: Array(repeating: stroke, count: index + 1))
            insideNativeCallback = true
            coordinator.canvasViewDidBeginUsingTool(canvas)
            if changeAfterEnd { coordinator.canvasViewDidEndUsingTool(canvas) }
            canvas.drawing = ink
            coordinator.canvasViewDrawingDidChange(canvas)
            if !changeAfterEnd { coordinator.canvasViewDidEndUsingTool(canvas) }
            insideNativeCallback = false
            XCTAssertEqual(inlinePublications, 0, "Do not recompose a live PencilKit host inside its final delegate callback")
            XCTAssertEqual(inlinePresentationEffects, 0, "Parent workspace updates must wait until native handoff returns")
            let file = notes.folder.appendingPathComponent(pageID.uuidString + ".json")
            let saved = try JSONDecoder().decode(MarginPage.self, from: Data(contentsOf: file))
            XCTAssertEqual(try PKDrawing(data: saved.ink).strokes.count, index + 1, "Durability must remain synchronous")
            XCTAssertEqual(try PKDrawing(data: try XCTUnwrap(notes.current?.ink)).strokes.count, index + 1)
            let notified = expectation(description: "Saved ink presentation effects have been delivered")
            DispatchQueue.main.async { notified.fulfill() }
            XCTAssertEqual(XCTWaiter.wait(for: [notified], timeout: 3), .completed)
            XCTAssertEqual(savedEffects, beforeEffects + 1)
            XCTAssertEqual(canvas.drawing.strokes.count, index + 1)
            XCTAssertEqual(coordinator.pageID, pageID)
            XCTAssertTrue(canvas.window === window)
            XCTAssertFalse(coordinator.isStroking)
        }
        XCTAssertNil(notes.error)
    }

    @MainActor func testTransitionSaveIsDurableBeforePublicationAndCannotRollbackLaterEdits() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let notes = MarginPages(root: root, notebook: UUID())
        let id = try XCTUnwrap(notes.currentID)
        let points = [CGPoint(x: 20, y: 30), CGPoint(x: 120, y: 70)].map {
            PKStrokePoint(location: $0, timeOffset: 0, size: CGSize(width: 4, height: 4),
                          opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
        }
        let first = PKDrawing(strokes: [PKStroke(ink: PKInk(.pen, color: .red),
            path: PKStrokePath(controlPoints: points, creationDate: Date()))])
        let second = PKDrawing(strokes: first.strokes + first.transformed(using: CGAffineTransform(translationX: 30, y: 0)).strokes)
        var publications = 0
        let observer = notes.objectWillChange.sink { publications += 1 }
        defer { observer.cancel() }
        XCTAssertTrue(notes.saveInkDuringViewUpdate(first, page: id))
        XCTAssertEqual(publications, 0, "A representable transition must not publish into SwiftUI's active graph update")
        let file = notes.folder.appendingPathComponent(id.uuidString + ".json")
        let immediate = try JSONDecoder().decode(MarginPage.self, from: Data(contentsOf: file))
        XCTAssertEqual(try PKDrawing(data: immediate.ink).strokes.count, 1, "Disk persistence must not wait for an async notification")
        XCTAssertEqual(try PKDrawing(data: try XCTUnwrap(notes.current?.ink)).strokes.count, 1)
        notes.editText("Later text", page: id)
        notes.saveInk(second, page: id)
        let drained = expectation(description: "The queued publication has completed")
        DispatchQueue.main.async { drained.fulfill() }
        XCTAssertEqual(XCTWaiter.wait(for: [drained], timeout: 3), .completed)
        let final = try JSONDecoder().decode(MarginPage.self, from: Data(contentsOf: file))
        XCTAssertEqual(try PKDrawing(data: final.ink).strokes.count, 2)
        XCTAssertEqual(final.text, "Later text")
        XCTAssertEqual(try PKDrawing(data: try XCTUnwrap(notes.current?.ink)).strokes.count, 2)
        XCTAssertEqual(notes.current?.text, "Later text")
        XCTAssertTrue(notes.saved)
        XCTAssertNil(notes.error)
    }

    @MainActor func testSwitchingNotesToTextFlushesUnfinishedInkToItsOriginalFile() throws {
        try verifyUnfinishedInk(changePage: false)
    }

    @MainActor func testSwitchingNotesPageFlushesUnfinishedInkToItsOriginalFile() throws {
        try verifyUnfinishedInk(changePage: true)
    }

    @MainActor func testDeletingAndRestoringNotesPageKeepsItsUnfinishedInkAndFinishesTool() throws {
        try verifyUnfinishedInk(changePage: true, deleting: true)
    }

    @MainActor private func verifyUnfinishedInk(changePage: Bool, deleting: Bool = false) throws {
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
        var retainedPageID: UUID?
        var retainedInk: PKDrawing?
        if deleting {
            XCTAssertTrue(notes.add(linkedTo: 2))
            let otherID = try XCTUnwrap(notes.currentID)
            let otherInk = ink.transformed(using: CGAffineTransform(translationX: 0, y: 1200))
            notes.saveInk(otherInk, page: otherID)
            retainedPageID = otherID; retainedInk = otherInk
            XCTAssertTrue(notes.select(originalPage))
        }
        // A second interaction can remove the handwriting subtree before
        // PencilKit delivers its final tool-end callback. Exercise that order
        // through the real delegate, representable and atomic Notes store.
        coordinator.canvasViewDidBeginUsingTool(canvas)
        canvas.drawing = ink
        coordinator.canvasViewDrawingDidChange(canvas)
        XCTAssertTrue(coordinator.isStroking)
        XCTAssertEqual(notes.current?.ink, originalInk, "Live frames remain buffered until a commit boundary")
        if changePage {
            if deleting { XCTAssertTrue(notes.delete(originalPage)) }
            else { XCTAssertTrue(notes.add(linkedTo: 2)) }
            let reloaded = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                coordinator.pageID == notes.currentID && coordinator.pageID != originalPage
            }, object: nil)
            guard XCTWaiter.wait(for: [reloaded], timeout: 3) == .completed else {
                XCTFail("The actual Notes page transition must load its new page"); return
            }
        } else {
            notes.editor.handwriting = false
            host.view.setNeedsLayout(); host.view.layoutIfNeeded()
            let removed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in canvas.window == nil }, object: nil)
            guard XCTWaiter.wait(for: [removed], timeout: 3) == .completed else {
                XCTFail("The actual mode transition must dismantle the old handwriting view"); return
            }
        }
        if deleting {
            XCTAssertFalse(canvas.usingTool, "The retired gesture must not keep the next page's extent deferred")
            let next = try XCTUnwrap(notes.current)
            XCTAssertEqual(canvas.sheetSize, CGSize(width: next.width, height: next.height))
            XCTAssertTrue(notes.restore(originalPage))
        }
        // Do not synthesize a later end callback: the transition itself must preserve
        // the last available PKDrawing, including an interrupted final stroke.
        let reopened = MarginPages(root: root, notebook: notebook)
        let data = try XCTUnwrap(reopened.pages.first { $0.id == originalPage }?.ink)
        let restored = data.isEmpty ? PKDrawing() : try PKDrawing(data: data)
        let pageFile = notes.folder.appendingPathComponent(originalPage.uuidString + ".json")
        let evidence = XCTAttachment(data: try Data(contentsOf: pageFile), uniformTypeIdentifier: "public.json")
        evidence.name = changePage ? "ActualNotesPageAfterPageReload" : "ActualNotesPageAfterModeTeardown"; evidence.lifetime = .keepAlways; add(evidence)
        XCTAssertEqual(restored.strokes.count, 1, "Changing Notes mode or page must save unfinished ink to its original page")
        XCTAssertEqual(restored.bounds, ink.bounds)
        XCTAssertEqual(reopened.currentID, changePage ? notes.currentID : originalPage)
        if deleting {
            let otherID = try XCTUnwrap(retainedPageID), otherInk = try XCTUnwrap(retainedInk)
            let other = try XCTUnwrap(reopened.pages.first { $0.id == otherID })
            XCTAssertEqual(try PKDrawing(data: other.ink).bounds, otherInk.bounds, "The surviving page must retain its own distinct ink")
        } else if changePage {
            let currentInk = try XCTUnwrap(reopened.current?.ink)
            let newDrawing = currentInk.isEmpty ? PKDrawing() : try PKDrawing(data: currentInk)
            XCTAssertEqual(newDrawing.strokes.count, 0, "Pending old-page ink must never be assigned to the new Notes page")
        }
        XCTAssertNil(reopened.error)
    }
}
