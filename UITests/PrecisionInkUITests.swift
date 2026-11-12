import XCTest

/// Real production controls and finger input; geometry/data assertions live in the native tests.
final class PrecisionInkUITests: XCTestCase {
    override func setUp() { super.setUp(); continueAfterFailure = false }
    private func openDocument() -> XCUIApplication {
        let app = XCUIApplication(); app.launchArguments = ["--test-review-entry", "--test-native-menu"]
        app.launch(); openProductionDemonstration(in: app)
        XCTAssertTrue(app.buttons["inkTool"].waitForExistence(timeout: 15))
        return app
    }
    private func reveal(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        let element = app.buttons[identifier]
        for _ in 0..<4 {
            if element.exists && element.isHittable && app.windows.firstMatch.frame.contains(element.frame) { return element }
            let scroll = app.scrollViews["inkToolbar"]
            if element.exists && element.frame.minX < scroll.frame.minX { scroll.swipeRight() }
            else { scroll.swipeLeft() }
        }
        XCTAssertTrue(element.isHittable, "The actual tool must be reachable in its contextual rail")
        return element
    }
    private func chooseMode(_ mode: String, in app: XCUIApplication) {
        reveal("inkGeometry", in: app).tap()
        tapCompletedNativeMenuItem(app.buttons["inkGeometry-" + mode])
        XCTAssertEqual(app.buttons["inkGeometry"].value as? String, mode)
    }
    private func waitCount(_ element: XCUIElement, _ count: Int) {
        let value = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", String(count)), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [value], timeout: 10), .completed)
    }
    private func capture(_ name: String) {
        let shot = XCTAttachment(data: XCUIScreen.main.screenshot().pngRepresentation, uniformTypeIdentifier: "public.png")
        shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
    private func openWorkspaceAction(_ identifier: String, in app: XCUIApplication) {
        let focus = app.buttons["focusToggle"]
        if focus.exists && focus.value as? String == "focused" { focus.tap() }
        app.buttons["workspaceActions"].tap()
        let action = app.buttons[identifier]
        XCTAssertTrue(action.waitForExistence(timeout: 10))
        XCTAssertTrue(action.isHittable)
        action.tap()
    }
    func testPDFPrecisionHighlighterSelectionAndHistoryUseRealControls() {
        let app = openDocument(); app.buttons["inkTool"].tap()
        let count = app.buttons["inkTool"], initial = Int(count.value as? String ?? "") ?? -1
        XCTAssertGreaterThanOrEqual(initial, 0)
        let page = app.textFields["pageNumber"].value as? String
        let canvas = app.otherElements["pdfCanvas"], frame = canvas.frame
        reveal("inkRuler", in: app).tap()
        XCTAssertEqual(app.buttons["inkRuler"].value as? String, "on")
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.25)).press(forDuration: 0.1,
            thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.25)))
        waitCount(count, initial + 1)
        capture("Precision-PDF-NativeRuler")
        reveal("inkUndo", in: app).tap(); waitCount(count, initial)
        chooseMode("highlighter", in: app)
        let start = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.4))
        let end = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.4))
        start.press(forDuration: 0.1, thenDragTo: end)
        waitCount(count, initial + 1)
        app.buttons["selectTool"].tap()
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4)).tap()
        let selection = app.buttons["straightenSelectedInk"]
        XCTAssertTrue(selection.waitForExistence(timeout: 5)); XCTAssertTrue(selection.isEnabled)
        app.buttons["selectedInkColor"].tap()
        tapCompletedNativeMenuItem(app.buttons["selectedInkColor-red"])
        app.buttons["selectionUndo"].tap(); waitCount(count, initial + 1)
        app.buttons["selectionRedo"].tap(); waitCount(count, initial + 1)
        app.buttons["selectionUndo"].tap()
        app.buttons["selectionUndo"].tap(); waitCount(count, initial)
        app.buttons["selectionRedo"].tap(); waitCount(count, initial + 1)
        XCTAssertEqual(app.textFields["pageNumber"].value as? String, page)
        XCTAssertEqual(canvas.frame, frame, "Choosing/editing a stroke cannot resize or cover the PDF")
        capture("Precision-PDF-SelectedHighlighter")
    }
    func testNotesLineRulerAndUndoDoNotChangeDocumentPage() {
        let app = openDocument()
        openWorkspaceAction("splitDocumentNotes", in: app)
        let mode = app.segmentedControls["marginMode"].buttons["خط اليد"]
        XCTAssertTrue(mode.waitForExistence(timeout: 5)); mode.tap()
        let canvas = app.scrollViews["marginInkCanvas"]
        XCTAssertTrue(canvas.waitForExistence(timeout: 5))
        let initial = Int(canvas.value as? String ?? "") ?? -1
        XCTAssertGreaterThanOrEqual(initial, 0)
        let page = app.textFields["pageNumber"].value as? String
        reveal("inkRuler", in: app).tap()
        XCTAssertEqual(app.buttons["inkRuler"].value as? String, "on")
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.25)).press(forDuration: 0.1,
            thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.25)))
        waitCount(canvas, initial + 1)
        capture("Precision-Notes-NativeRuler")
        reveal("inkUndo", in: app).tap(); waitCount(canvas, initial)
        chooseMode("line", in: app)
        XCTAssertEqual(app.buttons["inkRuler"].value as? String, "off")
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.4)).press(forDuration: 0.1,
            thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.4)))
        waitCount(canvas, initial + 1)
        reveal("inkUndo", in: app).tap(); waitCount(canvas, initial)
        reveal("inkRedo", in: app).tap(); waitCount(canvas, initial + 1)
        XCTAssertEqual(app.textFields["pageNumber"].value as? String, page)
        capture("Precision-Notes-UniformLine")
    }
}
