import XCTest

// Diagnostic-only structural validation; not a replacement for the original
// five-second atomic mount expectations or any original LaunchTests assertion.
final class MarginAXScopeDiagnostics: XCTestCase {
    private struct Counts {
        var panes = 0, modes = 0, canvases = 0, texts = 0, nodes = 0
        var values: [String] = []
    }

    private func counts(in root: any XCUIElementSnapshot) -> Counts {
        var result = Counts()
        var pending: [any XCUIElementSnapshot] = [root]
        while let node = pending.popLast() {
            result.nodes += 1
            if node.identifier == "marginPane" { result.panes += 1 }
            if node.elementType == .segmentedControl && node.identifier == "marginMode" {
                result.modes += 1
                result.values.append(node.value as? String ?? "missing")
            }
            if node.elementType == .scrollView && node.identifier == "marginInkCanvas" { result.canvases += 1 }
            if node.elementType == .textView && node.identifier == "splitNotes" { result.texts += 1 }
            pending.append(contentsOf: node.children)
        }
        return result
    }

    private func attach(_ value: String, name: String) {
        let attachment = XCTAttachment(string: value)
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }

    private func compareSettledHierarchies(in app: XCUIApplication, mode: String) throws {
        let started = ProcessInfo.processInfo.systemUptime
        let whole = try app.snapshot()
        let wholeCaptured = ProcessInfo.processInfo.systemUptime
        let global = counts(in: whole)
        attach("rootIdentifier=\(whole.identifier); rootType=\(whole.elementType.rawValue); capture=\(wholeCaptured - started); nodes=\(global.nodes); panes=\(global.panes); modes=\(global.modes); values=\(global.values); canvases=\(global.canvases); texts=\(global.texts)",
               name: "MarginScope-\(mode)-WholeApp")
        XCTAssertEqual(global.panes, 1, "Detect duplicate containers or inherited pane identifiers")
        let pane = app.descendants(matching: .any).matching(identifier: "marginPane").element
        let paneStarted = ProcessInfo.processInfo.systemUptime
        let scoped: any XCUIElementSnapshot
        do { scoped = try pane.snapshot() }
        catch {
            attach("scope=marginPane; error=\(error.localizedDescription)", name: "MarginScope-\(mode)-PaneError")
            throw error
        }
        let paneCaptured = ProcessInfo.processInfo.systemUptime
        let local = counts(in: scoped)
        attach("rootIdentifier=\(scoped.identifier); rootType=\(scoped.elementType.rawValue); capture=\(paneCaptured - paneStarted); total=\(ProcessInfo.processInfo.systemUptime - started); nodes=\(local.nodes); panes=\(local.panes); modes=\(local.modes); values=\(local.values); canvases=\(local.canvases); texts=\(local.texts)",
               name: "MarginScope-\(mode)-Pane")
        XCTAssertEqual(scoped.identifier, "marginPane")
        XCTAssertEqual(local.panes, 1)
        XCTAssertEqual(local.modes, 1)
        XCTAssertEqual(local.values, [mode])
        XCTAssertEqual(global.modes, local.modes)
        XCTAssertEqual(global.values, local.values)
        XCTAssertEqual(global.canvases, local.canvases, "Detect a canvas hidden by containment or escaped outside the pane")
        XCTAssertEqual(global.texts, local.texts, "Detect a text editor hidden by containment or escaped outside the pane")
        if mode == "text" {
            XCTAssertEqual(local.texts, 1)
            XCTAssertEqual(local.canvases, 0)
        } else {
            XCTAssertGreaterThan(local.canvases, 0)
            XCTAssertEqual(local.texts, 0)
        }
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "MarginScope-\(mode)-Screen"; screenshot.lifetime = .keepAlways; add(screenshot)
    }

    func testMarginPaneKeepsNativeChildrenInBothModes() throws {
        let app = XCUIApplication()
        defer { app.terminate() }
        app.launchArguments = ["--test-review-entry", "--test-reset-entrance", "--test-reduce-motion", "--test-margin-viewport"]
        app.launch()
        let demo = app.buttons["welcomeDemonstration"]
        guard demo.waitForExistence(timeout: 15) else { XCTFail("Missing local demonstration"); return }
        if !demo.isHittable { app.swipeUp() }
        demo.tap()
        let split = app.buttons["splitDocumentNotes"]
        guard split.waitForExistence(timeout: 15) else { XCTFail("Missing split action"); return }
        split.tap()
        let mode = app.segmentedControls["marginMode"]
        let text = app.textViews["splitNotes"]
        guard text.waitForExistence(timeout: 15), mode.value as? String == "text" else {
            XCTFail("Text mode must be present before structural inspection"); return
        }
        try compareSettledHierarchies(in: app, mode: "text")
        mode.buttons["خط اليد"].tap()
        let settled = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            mode.value as? String == "handwriting" && app.scrollViews["marginInkCanvas"].exists && !text.exists
        }, object: app)
        guard XCTWaiter.wait(for: [settled], timeout: 15) == .completed else {
            XCTFail("Handwriting must settle before separate structural inspection"); return
        }
        // Serial snapshots here validate containment after settlement; they do
        // not claim the original atomic five-second mount deadline was met.
        try compareSettledHierarchies(in: app, mode: "handwriting")
    }
}
