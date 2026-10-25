import XCTest
import UIKit

final class LaunchTests: XCTestCase {
    private func revealWorkspaceTools(in app: XCUIApplication) {
        let focus = app.buttons["focusToggle"]
        if focus.exists && focus.value as? String == "focused" { focus.tap() }
    }
    private func openWorkspaceAction(_ identifier: String, in app: XCUIApplication) {
        revealWorkspaceTools(in: app)
        app.buttons["workspaceActions"].tap()
        let action = app.buttons[identifier]
        XCTAssertTrue(action.waitForExistence(timeout: 10), "Real document action must be available: " + identifier)
        XCTAssertTrue(action.isHittable, "Real document action must be tappable: " + identifier)
        action.tap()
    }
    private func openExpandedNotes(in app: XCUIApplication) {
        revealWorkspaceTools(in: app)
        let expand = app.buttons["expandMargin"]
        let divider = app.descendants(matching: .any)["splitDivider"].firstMatch
        // The Notes dock cycles closed -> split -> expanded -> closed.
        // Reopening existing Notes must not blindly advance that cycle.
        if !expand.exists {
            app.buttons["openMargin"].tap()
            XCTAssertTrue(expand.waitForExistence(timeout: 5))
        }
        if divider.exists { expand.tap() }
        let expanded = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            expand.exists && expand.label == "العودة إلى المستند"
        }, object: app)
        XCTAssertEqual(XCTWaiter.wait(for: [expanded], timeout: 5), .completed,
                       "Notes must actually enter expanded mode before continuing")
        // An absent-node AX lookup can retry longer than the predicate's whole
        // deadline on iPad. Keep the same assertion outside that timed poll.
        XCTAssertFalse(divider.exists, "Expanded Notes must remove the split divider")
    }
    private func visibleMarginInkPixels(_ canvas: XCUIElement, in app: XCUIApplication) -> Int {
        inkPixels(in: XCUIScreen.main.screenshot().image, frame: canvas.frame)
    }
    private func inkPixels(in screenshot: UIImage, frame canvasFrame: CGRect) -> Int {
        // CGImage pixels do not apply UIImage's orientation metadata. Normalize
        // before comparing the screen pixels with XCTest's oriented element frame.
        let format = UIGraphicsImageRendererFormat(); format.scale = screenshot.scale
        let upright = UIGraphicsImageRenderer(size: screenshot.size, format: format).image { _ in
            screenshot.draw(in: CGRect(origin: .zero, size: screenshot.size))
        }
        guard let image = upright.cgImage else { return 0 }
        let scale = CGFloat(image.width) / screenshot.size.width
        // A fit-to-sheet canvas can be only 110 pt high; retain ink near its edges.
        let frame = canvasFrame.insetBy(dx: 2, dy: 2)
        let crop = CGRect(x: frame.minX * scale, y: frame.minY * scale, width: frame.width * scale, height: frame.height * scale)
        guard let ink = image.cropping(to: crop), ink.width > 0, ink.height > 0 else { return 0 }
        var pixels = [UInt8](repeating: 0, count: ink.width * ink.height * 4)
        return pixels.withUnsafeMutableBytes { bytes in
            guard let context = CGContext(data: bytes.baseAddress, width: ink.width, height: ink.height, bitsPerComponent: 8,
                                          bytesPerRow: ink.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else { return 0 }
            context.draw(ink, in: CGRect(x: 0, y: 0, width: ink.width, height: ink.height))
            var count = 0
            for index in stride(from: 0, to: bytes.count, by: 4) {
                let red = Int(bytes[index]), green = Int(bytes[index + 1]), blue = Int(bytes[index + 2])
                // Include antialiased green edges at small fit scales; blank cream/gray pixels do not qualify.
                if red < 235 && green > red + 3 && green > blue + 3 { count += 1 }
            }
            return count
        }
    }
    func testInkPixelMeasurementRespectsScreenshotOrientationAndExcludesControls() throws {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let raw = UIGraphicsImageRenderer(size: CGSize(width: 120, height: 80), format: format).image { _ in
            UIColor.white.setFill(); UIRectFill(CGRect(x: 0, y: 0, width: 120, height: 80))
            UIColor(red: 0.07, green: 0.25, blue: 0.22, alpha: 1).setFill()
            UIRectFill(CGRect(x: 20, y: 10, width: 60, height: 4))
            UIRectFill(CGRect(x: 2, y: 60, width: 10, height: 10)) // Adjacent toolbar control.
        }
        let pixels = try XCTUnwrap(raw.cgImage)
        let cases: [(UIImage.Orientation, CGRect, CGRect)] = [
            (.up, CGRect(x: 10, y: 5, width: 80, height: 20), CGRect(x: 80, y: 50, width: 30, height: 20)),
            (.right, CGRect(x: 60, y: 10, width: 15, height: 80), CGRect(x: 0, y: 20, width: 20, height: 80)),
            (.left, CGRect(x: 5, y: 30, width: 20, height: 80), CGRect(x: 50, y: 20, width: 20, height: 80)),
            (.down, CGRect(x: 30, y: 60, width: 80, height: 15), CGRect(x: 0, y: 0, width: 30, height: 30))
        ]
        for (orientation, inkFrame, blankFrame) in cases {
            let screen = UIImage(cgImage: pixels, scale: 1, orientation: orientation)
            XCTAssertGreaterThan(inkPixels(in: screen, frame: inkFrame), 40, "Visible ink in orientation \(orientation.rawValue)")
            XCTAssertEqual(inkPixels(in: screen, frame: blankFrame), 0, "Adjacent controls must not qualify as canvas ink")
        }
    }
    private func assertMarginInkVisible(_ canvas: XCUIElement, in app: XCUIApplication, stage: String, file: StaticString = #filePath, line: UInt = #line) {
        let visible = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in self.visibleMarginInkPixels(canvas, in: app) > 40 }, object: canvas)
        let result = XCTWaiter.wait(for: [visible], timeout: 10)
        let screen = XCUIScreen.main.screenshot().image
        print("Margin screenshot " + stage + ": size=\(screen.size) scale=\(screen.scale) orientation=\(screen.imageOrientation.rawValue) frame=\(canvas.frame) pixels=\(visibleMarginInkPixels(canvas, in: app))")
        print("Margin viewport " + stage + ": " + (canvas.value as? String ?? "") + "; " + canvas.label)
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); shot.name = "MarginInkVisible-" + stage; shot.lifetime = .keepAlways; add(shot)
        let element = XCTAttachment(screenshot: canvas.screenshot()); element.name = "MarginCanvas-" + stage; element.lifetime = .keepAlways; add(element)
        XCTAssertEqual(result, .completed, "Saved strokes must remain visible in the canvas after " + stage + "; frame: " + String(describing: canvas.frame), file: file, line: line)
    }
    func testAReviewEntryProvidesCompleteLocalDemonstrationWithoutLogin() {
        let app = XCUIApplication(); app.launchArguments = ["--test-review-entry"]; app.launch()
        let demo = app.buttons["welcomeDemonstration"]
        XCTAssertTrue(demo.waitForExistence(timeout: 15)); XCTAssertTrue(demo.isHittable)
        demo.tap()
        XCTAssertTrue(app.buttons["inkTool"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.textFields["Username"].exists)
        openWorkspaceAction("splitDocumentNotes", in: app)
        XCTAssertTrue(app.textViews["splitNotes"].waitForExistence(timeout: 10))
        XCTAssertTrue((app.textViews["splitNotes"].value as? String)?.contains("ملاحظة تجريبية") == true)
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "FirstLaunchReviewAccess"; shot.lifetime = .keepAlways; add(shot)
    }
    func testDeleteAddedDocumentAndMarginPagesThroughVisibleToolbar() {
        let app = XCUIApplication(); app.launch()
        XCTAssertTrue(app.buttons["createNotebook"].waitForExistence(timeout: 15)); app.buttons["createNotebook"].tap()
        let name = "Page recovery " + String(UUID().uuidString.prefix(8))
        let title = app.textFields["notebookTitle"]; title.tap(); title.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 30) + name)
        app.buttons["إنشاء"].tap()
        let note = visibleLibraryDocument(name, in: app); note.tap()
        XCTAssertTrue(app.buttons["workspaceActions"].waitForExistence(timeout: 10))
        openWorkspaceAction("addWritingPaper", in: app); app.buttons["نقاط"].tap()
        XCTAssertEqual(app.textFields["pageNumber"].value as? String, "2")
        openWorkspaceAction("deleteDocumentPage", in: app)
        XCTAssertTrue(app.staticTexts["حذف صفحة المستند 2 وكتابتها؟"].waitForExistence(timeout: 5))
        let confirmation = app.sheets["حذف صفحة المستند 2 وكتابتها؟"]
        let actions = confirmation.buttons.matching(identifier: "confirmDocumentPageDeletion").allElementsBoundByIndex
        let leafActions = actions.filter { $0.descendants(matching: .button).count == 0 }
        XCTAssertEqual(leafActions.count, 1, "The confirmation must have exactly one deletion action")
        guard leafActions.count == 1, let confirm = leafActions.first else { return }
        guard confirm.exists && confirm.isHittable else {
            XCTFail("The native deletion confirmation must be visible and tappable"); return
        }
        confirm.tap()
        let removed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            (app.textFields["pageNumber"].value as? String) == "1"
                && !app.buttons["nextDocumentPage"].isEnabled
        }, object: app)
        XCTAssertEqual(XCTWaiter.wait(for: [removed], timeout: 5), .completed)
        XCTAssertEqual(app.textFields["pageNumber"].value as? String, "1")
        app.buttons["workspaceActions"].tap()
        XCTAssertTrue(app.buttons["undoDocumentPageDeletion"].isEnabled)
        app.buttons["undoDocumentPageDeletion"].tap()
        XCTAssertTrue(app.buttons["nextDocumentPage"].isEnabled)
        openExpandedNotes(in: app)
        app.buttons["addMarginPage"].tap()
        app.segmentedControls["marginMode"].buttons["نص"].tap()
        let text = app.textViews["splitNotes"]; text.tap(); text.typeText("Recover this page")
        // Dismiss the keyboard through a real mode change before using the footer.
        app.segmentedControls["marginMode"].buttons["خط اليد"].tap()
        app.buttons["deleteMarginPage"].tap(); app.sheets.buttons["حذف صفحة الملاحظات"].tap()
        let deleted = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "1/1"), object: app.buttons["marginPages"])
        XCTAssertEqual(XCTWaiter.wait(for: [deleted], timeout: 5), .completed)
        XCTAssertEqual(app.buttons["marginPages"].value as? String, "1/1")
        app.buttons["deletedMarginPages"].tap(); app.buttons["استعادة"].tap()
        XCTAssertEqual(app.buttons["marginPages"].value as? String, "2/2")
        app.segmentedControls["marginMode"].buttons["نص"].tap()
        XCTAssertEqual(text.value as? String, "Recover this page")
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "VisibleToolbarAndPageRecovery"; shot.lifetime = .keepAlways; add(shot)
    }
    func testZDemonstrationIsAvailableWithoutLoginAndOpensPopulatedPages() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["librarySettings"].tap()
        let demo = app.buttons["openDemonstration"]
        XCTAssertTrue(demo.waitForExistence(timeout: 15))
        if !demo.isHittable { app.swipeDown() }
        demo.tap()
        XCTAssertTrue(app.textFields["pageNumber"].waitForExistence(timeout: 15))
        openWorkspaceAction("splitDocumentNotes", in: app)
        XCTAssertTrue(app.segmentedControls["marginMode"].waitForExistence(timeout: 10))
        app.segmentedControls["marginMode"].buttons["نص"].tap()
        XCTAssertTrue((app.textViews["splitNotes"].value as? String)?.contains("ملاحظة تجريبية") == true)
        XCTAssertTrue(app.buttons["nextMarginPage"].isEnabled)
        app.buttons["nextMarginPage"].tap()
        XCTAssertTrue((app.textViews["splitNotes"].value as? String)?.contains("صفحة مستقلة") == true)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "DemonstrationReadyForReview"; shot.lifetime = .keepAlways; add(shot)
    }
    private func prepareExternalFixture(in app: XCUIApplication, name: String) -> Bool {
        // Create the provider-owned fixture immediately before its import,
        // without retaining it across unrelated PDF picker sessions.
        exportExternalFixture(in: app, office: name == "Picker-office")
    }

    private func exportExternalFixture(in app: XCUIApplication, office: Bool) -> Bool {
        app.launchArguments = ["--test-export-fixtures"] + (office ? ["--test-export-office"] : [])
        app.launch()
        let location = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", "On My ")).firstMatch
        let browse = app.buttons["Browse"].firstMatch
        let loaded = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            (location.exists && location.isHittable) || (browse.exists && browse.isHittable)
        }, object: app)
        guard XCTWaiter.wait(for: [loaded], timeout: 60) == .completed else {
            XCTFail("Files export did not load: " + app.debugDescription); return false
        }
        if browse.exists && browse.isHittable { browse.tap() }
        guard location.waitForExistence(timeout: 15) else { XCTFail(app.debugDescription); return false }
        let locationFrame = location.frame
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: locationFrame.midX, dy: locationFrame.midY)).tap()
        // Save directly in Files' writable On My device root. Creating and
        // renaming a folder is unrelated to importing documents and stalls
        // inline editing in the iOS 26 simulator. Files still owns this export.
        let save = app.buttons["Save"].firstMatch
        guard save.waitForExistence(timeout: 15) else { XCTFail(app.debugDescription); return false }
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == true"), object: save)
        guard XCTWaiter.wait(for: [enabled], timeout: 15) == .completed else {
            XCTFail("Files must enable saving the staged fixture: " + app.debugDescription); return false
        }
        save.tap()
        let status = app.staticTexts["fixtureExportStatus"]
        let saved = XCTNSPredicateExpectation(predicate: NSPredicate(format:
            "exists == true AND label == %@", "Fixtures exported"), object: status)
        // Files can finish its provider write before delivering the export
        // callback. Keep waiting for the real completion, rather than failing
        // just before "Fixtures exported" appears on a cold simulator.
        guard XCTWaiter.wait(for: [saved], timeout: 60) == .completed else {
            XCTFail("Files export did not complete: " + app.debugDescription); return false
        }
        app.terminate()
        return true
    }
    func testDrawingToolDoesNotTurnPagesInDocumentOrSplit() {
        let app = XCUIApplication(); app.launch()
        visibleLibraryDocument("ملف التجربة", in: app).tap()
        let page = app.textFields["pageNumber"]
        XCTAssertTrue(page.waitForExistence(timeout: 10))
        let previous = app.buttons["previousDocumentPage"]
        if previous.isEnabled { previous.tap() }
        let pen = app.buttons["inkTool"]
        for stage in ["document", "split"] {
            if stage == "split" { openWorkspaceAction("splitDocumentNotes", in: app) }
            let initial = page.value as? String
            let margin = stage == "split" ? app.buttons["marginPages"].value as? String : nil
            for _ in 0..<12 {
                pen.tap()
                XCTAssertEqual(page.value as? String, initial, "Toggling the pen must not turn pages in " + stage)
                if stage == "split" { XCTAssertEqual(app.buttons["marginPages"].value as? String, margin) }
            }
            pen.tap()
            let before = Int(pen.value as? String ?? "") ?? 0
            let canvas = app.otherElements["pdfCanvas"]
            canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.3)).press(forDuration: 0.1,
                thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.4)))
            let saved = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                (Int(pen.value as? String ?? "") ?? 0) > before
            }, object: pen)
            XCTAssertEqual(XCTWaiter.wait(for: [saved], timeout: 10), .completed, "Document ink must work in " + stage)
            XCTAssertEqual(page.value as? String, initial, "Writing must not change the document page")
            pen.tap()
            let shot = XCTAttachment(screenshot: app.screenshot())
            shot.name = "PenKeepsPage-" + stage; shot.lifetime = .keepAlways; add(shot)
        }
    }

    func testNewMarginStrokesWorkAfterSplitResizeRotationAndExpansion() {
        let app = XCUIApplication(); app.launch()
        XCTAssertTrue(app.buttons["createNotebook"].waitForExistence(timeout: 15)); app.buttons["createNotebook"].tap()
        let name = "Handwriting stages " + String(UUID().uuidString.prefix(8))
        let title = app.textFields["notebookTitle"]; title.tap()
        title.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 30) + name)
        // A prior run saved a title missing its final character. Confirm
        // complete input before submitting, rather than assuming typing is ready.
        let entered = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", name), object: title)
        guard XCTWaiter.wait(for: [entered], timeout: 5) == .completed else {
            XCTFail("Notebook title input was incomplete: " + String(describing: title.value)); return
        }
        print("Margin creation verified title: " + String(describing: title.value))
        app.buttons["saveNotebook"].tap(); visibleLibraryDocument(name, in: app).tap()
        openWorkspaceAction("splitDocumentNotes", in: app)
        let text = app.textViews["splitNotes"]
        XCTAssertTrue(text.waitForExistence(timeout: 5)); text.tap(); text.typeText("Switch from text to handwriting")
        app.segmentedControls["marginMode"].buttons["خط اليد"].tap()
        let canvas = app.scrollViews["marginInkCanvas"]
        XCTAssertTrue(canvas.waitForExistence(timeout: 5))
        for stage in ["split", "resized", "landscape", "expanded"] {
            if stage == "resized" {
                let previousFrame = canvas.frame
                let divider = app.descendants(matching: .any)["splitDivider"].firstMatch
                let start = divider.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: -50, dy: -40)))
                XCTAssertNotEqual(canvas.frame.size, previousFrame.size, "The divider must really resize the handwriting viewport")
            } else if stage == "landscape" {
                XCUIDevice.shared.orientation = .landscapeLeft
                let rotated = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in app.frame.width > app.frame.height }, object: app)
                XCTAssertEqual(XCTWaiter.wait(for: [rotated], timeout: 5), .completed)
            } else if stage == "expanded" { app.buttons["expandMargin"].tap() }
            let initial = Int(canvas.value as? String ?? "") ?? 0
            let start = stage == "split" ? CGVector(dx: 0.2, dy: 0.2) : CGVector(dx: 0.2, dy: 0.3)
            let end = stage == "split" ? CGVector(dx: 0.4, dy: 0.85) : CGVector(dx: 0.7, dy: 0.6)
            canvas.coordinate(withNormalizedOffset: start).press(forDuration: 0.1,
                thenDragTo: canvas.coordinate(withNormalizedOffset: end))
            let saved = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                (Int(canvas.value as? String ?? "") ?? 0) > initial
            }, object: canvas)
            XCTAssertEqual(XCTWaiter.wait(for: [saved], timeout: 10), .completed, "A new stroke must be accepted after " + stage)
            assertMarginInkVisible(canvas, in: app, stage: "new-stroke-" + stage)
        }
        let count = canvas.value as? String
        XCUIDevice.shared.orientation = .portrait
        app.terminate(); app.launch()
        visibleLibraryDocument(name, in: app).tap(); openWorkspaceAction("splitDocumentNotes", in: app)
        app.segmentedControls["marginMode"].buttons["خط اليد"].tap()
        XCTAssertEqual(canvas.value as? String, count, "All newly drawn strokes must survive reopening")
    }

    func testTouchInkPersistsAfterRelaunch() {
        let app = XCUIApplication()
        app.launch()
        let demo = visibleLibraryDocument("ملف التجربة", in: app)
        XCTAssertTrue(demo.waitForExistence(timeout: 15))
        demo.tap()
        let inkTool = app.buttons["inkTool"]
        XCTAssertTrue(inkTool.waitForExistence(timeout: 10))
        inkTool.tap()
        // PDFKit excludes its overlay canvas from the accessibility tree.
        // Draw on the visible PDF and verify the saved count on the tool button.
        let canvas = app.otherElements["pdfCanvas"]
        XCTAssertTrue(canvas.waitForExistence(timeout: 10))
        let initial = Int(inkTool.value as? String ?? "") ?? 0
        let start = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.35))
        let end = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.45))
        start.press(forDuration: 0.1, thenDragTo: end)
        let saved = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            (Int(inkTool.value as? String ?? "") ?? 0) > initial
        }, object: inkTool)
        XCTAssertEqual(XCTWaiter.wait(for: [saved], timeout: 10), .completed, "A real touch gesture must create ink")
        XCTAssertTrue(app.textFields["pageNumber"].isHittable, "Page navigation must remain accessible while drawing")
        XCTAssertTrue(app.buttons["goToPage"].isHittable)
        let count = inkTool.value as? String
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "TouchInk"
        shot.lifetime = .keepAlways
        add(shot)
        app.terminate()
        app.launch()
        let reopened = visibleLibraryDocument("ملف التجربة", in: app)
        XCTAssertTrue(reopened.waitForExistence(timeout: 15))
        reopened.tap()
        XCTAssertTrue(canvas.waitForExistence(timeout: 10))
        XCTAssertTrue(inkTool.waitForExistence(timeout: 10))
        XCTAssertEqual(inkTool.value as? String, count, "Ink must survive a real app relaunch")
        inkTool.tap()
        XCTAssertTrue(app.scrollViews["inkToolbar"].waitForExistence(timeout: 5), "Reopened document must enter ink mode")
        assertFreshInkUndoRedo(in: app, canvas: canvas, count: inkTool)

    }

    // Exercise new edits after reopening; prior-session undo history is not asserted.
    private func assertFreshInkUndoRedo(in app: XCUIApplication, canvas: XCUIElement, count: XCUIElement,
                                       strokeStart: CGVector = CGVector(dx: 0.3, dy: 0.35),
                                       strokeEnd: CGVector = CGVector(dx: 0.7, dy: 0.45)) {
        let restored = count.value as? String
        guard let initial = Int(restored ?? "") else {
            XCTFail("Reopened native ink surface must expose its saved stroke count"); return
        }
        canvas.coordinate(withNormalizedOffset: strokeStart).press(forDuration: 0.1,
            thenDragTo: canvas.coordinate(withNormalizedOffset: strokeEnd))
        let saved = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            (Int(count.value as? String ?? "") ?? -1) > initial
        }, object: count)
        guard XCTWaiter.wait(for: [saved], timeout: 10) == .completed else {
            XCTFail("A fresh stroke must be saved after reopening"); return
        }
        guard let edited = count.value as? String, let editedCount = Int(edited), editedCount > initial else {
            XCTFail("Saved post-reopen stroke count must remain available"); return
        }
        guard tapInkTarget("inkUndo", in: app, writingSurface: canvas) else { return }
        let undone = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            count.value as? String == restored
        }, object: count)
        XCTAssertEqual(XCTWaiter.wait(for: [undone], timeout: 5), .completed,
            "Undo after reopening must remove only the fresh stroke")
        guard tapInkTarget("inkRedo", in: app, writingSurface: canvas) else { return }
        let redone = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            count.value as? String == edited
        }, object: count)
        XCTAssertEqual(XCTWaiter.wait(for: [redone], timeout: 5), .completed,
            "Redo after reopening must restore the fresh stroke")
        let screenshot = XCTAttachment(screenshot: canvas.screenshot())
        screenshot.name = "PostReopenRedoResult"; screenshot.lifetime = .keepAlways; add(screenshot)
    }

    private func visibleLibraryDocument(_ title: String, in app: XCUIApplication) -> XCUIElement {
        XCTAssertTrue(app.buttons["librarySections"].waitForExistence(timeout: 15))
        let document = app.buttons["openNotebook-" + title].firstMatch
        // Imports add real cards. LazyVGrid instantiates visible rows only;
        // reach the document through the same scrolling a user performs.
        for _ in 0..<6 {
            if document.exists && document.isHittable {
                // A partially visible card can be hittable while its default
                // tap lands under the phone's persistent bottom navigation.
                let center = document.frame.midY
                let navigation = app.navigationBars.firstMatch
                let top = navigation.exists ? navigation.frame.maxY : app.frame.minY
                let home = app.buttons["libraryHome"]
                let bottom = home.exists && home.frame.minY > app.frame.midY ? home.frame.minY : app.frame.maxY
                if center > top + 8 && center < bottom - 8 { return document }
            }
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTFail("Library document was not reachable: " + title + "\n" + app.debugDescription)
        return document
    }

    func testActualDocumentPickerImportsPDF() {
        verifyPickerImport(name: "Picker-fixture", editor: "textTool")
    }

    func testActualDocumentPickerImportsPowerPoint() {
        verifyPickerImport(name: "Picker-office", editor: "officeMedia")
    }

    func testAppOwnedDocumentPickerImportsPDF() {
        verifyPickerImport(name: "Owned-fixture", editor: "textTool", appOwned: true)
    }

    private func verifyPickerImport(name: String, editor: String, appOwned: Bool = false) {
        let app = XCUIApplication()
        if !appOwned && !prepareExternalFixture(in: app, name: name) { return }
        app.launchArguments = appOwned ? ["--test-app-owned-picker"] : []
        app.launch()
        let importButton = app.buttons["importDocument"]
        XCTAssertTrue(importButton.waitForExistence(timeout: 15))
        importButton.tap()
        let file = app.cells.matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch
        let browse = app.buttons["Browse"].firstMatch
        let location = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", "On My ")).firstMatch
        // A cold iPad simulator can spend tens of seconds starting the remote
        // Documents service. Wait for actual Files controls, not its blank host.
        let filesLoaded = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            (file.exists && file.isHittable) || (browse.exists && browse.isHittable) ||
                (location.exists && location.isHittable)
        }, object: app)
        guard XCTWaiter.wait(for: [filesLoaded], timeout: 60) == .completed else {
            XCTFail("Native Files did not finish loading: " + app.debugDescription); return
        }
        // Browse through Files' actual provider hierarchy instead of injecting
        // directoryURL. That shortcut can produce stale provider IDs on iOS 26.
        if !file.exists {
            if browse.exists && browse.isHittable { browse.tap() }
            guard location.waitForExistence(timeout: 15) else { XCTFail(app.debugDescription); return }
            let locationFrame = location.frame
            app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: locationFrame.midX, dy: locationFrame.midY)).tap()
            if appOwned {
                let folder = app.cells.matching(NSPredicate(format:
                    "label CONTAINS %@ OR label CONTAINS %@", "طَيّة", "Hashiya")).firstMatch
                guard folder.waitForExistence(timeout: 15) else { XCTFail(app.debugDescription); return }
                let frame = folder.frame
                app.coordinate(withNormalizedOffset: .zero)
                    .withOffset(CGVector(dx: frame.midX, dy: frame.midY)).tap()
            }
        }
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isHittable == true"), object: file)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 25), .completed, app.debugDescription)
        // Use Files' real list mode: row actions stay stable while thumbnails
        // finish rendering. This still selects through UIDocumentPicker.
        if app.collectionViews["File View"].value as? String != "List Mode" {
            let icons = app.buttons["DOC.itemCollectionMenuButton.Icons"]
            let viewOptions = icons.exists ? icons : app.buttons["More"].firstMatch
            guard viewOptions.waitForExistence(timeout: 5) else { XCTFail(app.debugDescription); return }
            viewOptions.tap()
            let list = app.buttons["List"].firstMatch
            guard list.waitForExistence(timeout: 5) else { XCTFail(app.debugDescription); return }
            list.tap()
        }
        XCTAssertTrue(file.waitForExistence(timeout: 10))
        if appOwned {
            // New note resources can put Owned-fixture at the clipped bottom
            // of the iPad picker. Scroll the provider's actual list before
            // taking its thumbnail geometry; an off-sheet tap dismisses it.
            app.collectionViews["File View"].swipeUp()
            XCTAssertTrue(file.waitForExistence(timeout: 10))
            XCTAssertTrue(file.isHittable)
        }
        let pickerShot = XCTAttachment(screenshot: app.screenshot())
        pickerShot.name = "NativeFilePicker"
        pickerShot.lifetime = .keepAlways
        add(pickerShot)
        XCTAssertTrue(file.isEnabled, "Files must permit this document type")
        // External provider files remain visible after thumbnail taps on iPadOS 26.
        // Tap the real filename rather than the thumbnail inside Files' list row.
        let filename = file.staticTexts.matching(NSPredicate(format: "label == %@", name)).firstMatch
        XCTAssertTrue(filename.waitForExistence(timeout: 10), "Files must expose the filename")
        XCTAssertTrue(filename.isHittable, "The selected filename must be visible in Files")
        let target = XCTAttachment(string: "File frame: \(file.frame); filename frame: \(filename.frame)")
        target.name = "FilesTapGeometry"; target.lifetime = .keepAlways; add(target)
        filename.tap()
        // Single selection delivers on the row tap; no second Open action.
        let status = app.staticTexts.matching(NSPredicate(format:
            "identifier == %@ AND (label CONTAINS %@ OR label CONTAINS %@)",
            "importStatus", "تم استيراد", "لم يتم الاستيراد")).firstMatch
        // A cold Documents service may delay accessibility snapshots after
        // it has already delivered the URL. Wait for the real library result,
        // then assert the success message and open the imported document.
        guard status.waitForExistence(timeout: 120) else {
            XCTFail("Files did not deliver the selected document: " + app.debugDescription); return
        }
        XCTAssertTrue(status.label.contains("تم استيراد"), status.label)
        let card = visibleLibraryDocument(name, in: app)
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        XCTAssertTrue(card.isHittable)
        card.tap()
        XCTAssertTrue(app.buttons[editor].waitForExistence(timeout: 10))
    }

    func testCreateNotebookFromLibrary() {
        let app = XCUIApplication()
        app.launch()
        let create = app.buttons["createNotebook"]
        XCTAssertTrue(create.waitForExistence(timeout: 15))
        create.tap()
        let name = "Created notebook " + String(UUID().uuidString.prefix(8))
        let title = app.textFields["notebookTitle"]; title.tap(); title.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 30) + name)
        app.buttons["إنشاء"].tap()
        XCTAssertTrue(app.buttons["openNotebook-" + name].waitForExistence(timeout: 10))
    }

    func testLibraryLaunchAndDocumentOpen() {
        let app = XCUIApplication()
        app.launch()
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isHittable == true"), object: app.buttons["librarySections"])
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 15), .completed)
        let opening = app.otherElements["openingAnimation"]
        _ = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: opening)], timeout: 5)
        XCTAssertTrue(app.navigationBars["مكتبتك"].waitForExistence(timeout: 15))
        let demo = visibleLibraryDocument("ملف التجربة", in: app)
        XCTAssertTrue(demo.waitForExistence(timeout: 10))
        let library = XCTAttachment(screenshot: app.screenshot())
        library.name = "Library"
        library.lifetime = .keepAlways
        add(library)
        demo.tap()
        XCTAssertTrue(app.navigationBars["ملف التجربة"].waitForExistence(timeout: 10))
        let document = XCTAttachment(screenshot: app.screenshot())
        document.name = "Document"
        document.lifetime = .keepAlways
        add(document)
    }

    func testOfficePreviewAndEmbeddedMedia() {
        let app = XCUIApplication()
        app.launchArguments = ["--test-office-preview"]
        app.launch()
        let card = app.staticTexts["ملف Office للاختبار"].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        card.tap()
        XCTAssertTrue(app.navigationBars["ملف Office للاختبار"].waitForExistence(timeout: 10))
        let media = app.buttons["officeMedia"]
        XCTAssertTrue(media.waitForExistence(timeout: 15))
        let loading = app.staticTexts["LOADING"]
        if loading.waitForExistence(timeout: 3) {
            let finished = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: loading)
            XCTAssertEqual(XCTWaiter.wait(for: [finished], timeout: 30), .completed)
        }
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = "OfficeAccessibility"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
        let preview = XCTAttachment(screenshot: app.screenshot())
        preview.name = "OfficePreview"
        preview.lifetime = .keepAlways
        add(preview)
        media.tap()
        let video = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", ".mp4")).firstMatch
        XCTAssertTrue(video.waitForExistence(timeout: 20))
        video.tap()
        let playback = XCTAttachment(screenshot: app.screenshot())
        playback.name = "EmbeddedVideo"
        playback.lifetime = .keepAlways
        add(playback)
    }

    func testPageJumpAndTextEditor() {
        let app = XCUIApplication()
        app.launch()
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isHittable == true"), object: app.buttons["librarySections"])
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 15), .completed)
        let demo = visibleLibraryDocument("ملف التجربة", in: app)
        XCTAssertTrue(demo.waitForExistence(timeout: 15))
        demo.tap()
        let page = app.textFields["pageNumber"]
        XCTAssertTrue(page.waitForExistence(timeout: 10))
        page.tap()
        page.typeText("2")
        XCTAssertEqual(page.value as? String, "2")
        app.buttons["goToPage"].tap()
        app.buttons["textTool"].tap()
        app.otherElements["pdfCanvas"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4)).tap()
        let tapped = XCTAttachment(screenshot: app.screenshot())
        tapped.name = "AfterTextTap"
        tapped.lifetime = .keepAlways
        add(tapped)
        let editor = app.textViews["annotationText"]
        XCTAssertTrue(editor.waitForExistence(timeout: 10))
        editor.tap(); editor.typeText("Study note")
        app.buttons["saveAnnotation"].tap()
        XCTAssertTrue(app.buttons["textTool"].waitForExistence(timeout: 10))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "TextAnnotation"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
    func testRecordingDoesNotOpenOrResizeMargins() {
        let app = XCUIApplication(); app.launch()
        visibleLibraryDocument("ملف التجربة", in: app).tap()
        let canvas = app.otherElements["pdfCanvas"]
        XCTAssertTrue(canvas.waitForExistence(timeout: 10))
        let initial = canvas.frame
        let record = app.buttons["recordLinkedAudio"]
        XCTAssertTrue(record.isHittable)
        addUIInterruptionMonitor(withDescription: "Microphone permission") { alert in
            let allow = alert.buttons["Allow"]
            if allow.exists { allow.tap(); return true }
            let ok = alert.buttons["OK"]
            if ok.exists { ok.tap(); return true }
            return false
        }
        record.tap()
        let permission = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.buttons["Allow"]
        if permission.waitForExistence(timeout: 5) { permission.tap() }
        let started = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "جارٍ التسجيل"), object: record)
        XCTAssertEqual(XCTWaiter.wait(for: [started], timeout: 15), .completed)
        XCTAssertFalse(app.buttons["marginPages"].exists, "Microphone must never open the margin")
        XCTAssertFalse(app.descendants(matching: .any)["splitDivider"].firstMatch.exists)
        XCTAssertEqual(canvas.frame, initial, "Recording must preserve reading area")
        record.tap()
        XCTAssertFalse(app.buttons["marginPages"].exists)
        XCTAssertEqual(canvas.frame, initial)
        openWorkspaceAction("splitDocumentNotes", in: app)
        let pages = app.buttons["marginPages"]
        XCTAssertTrue(pages.waitForExistence(timeout: 5))
        let splitFrame = canvas.frame, position = pages.value as? String
        record.tap()
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "جارٍ التسجيل"), object: record)], timeout: 10), .completed)
        XCTAssertEqual(canvas.frame, splitFrame)
        XCTAssertEqual(pages.value as? String, position)
        record.tap()
        XCTAssertEqual(canvas.frame, splitFrame)
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "RecordingPreservesWorkspace"; shot.lifetime = .keepAlways; add(shot)
    }

    func testPersistentLibraryDestinations() {
        let app = XCUIApplication(); app.launch()
        for id in ["libraryHome", "librarySections", "libraryReview", "librarySettings"] {
            XCTAssertTrue(app.buttons[id].waitForExistence(timeout: 15))
            XCTAssertTrue(app.buttons[id].isHittable)
        }
        app.buttons["libraryReview"].tap()
        XCTAssertTrue(app.navigationBars["المراجعة"].waitForExistence(timeout: 5))
        app.buttons["librarySettings"].tap()
        XCTAssertTrue(app.buttons["openDemonstration"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["libraryBackup"].exists)
        app.buttons["libraryHome"].tap()
        XCTAssertTrue(app.buttons["createNotebook"].waitForExistence(timeout: 5))
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "CalmLibraryNavigation"; shot.lifetime = .keepAlways; add(shot)
    }

    func testVisibleSectionsTrashAndSplitNotes() {
        let app = XCUIApplication(); app.launch()
        let sections = app.buttons["librarySections"]
        XCTAssertTrue(sections.waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["libraryTrash"].exists)
        sections.tap()
        XCTAssertTrue(app.navigationBars["الأقسام"].waitForExistence(timeout: 5))
        app.buttons["تم"].tap()
        let library = XCTAttachment(screenshot: app.screenshot()); library.name = "VisibleLibraryNavigation"; library.lifetime = .keepAlways; add(library)
        let demo = visibleLibraryDocument("ملف التجربة", in: app)
        XCTAssertTrue(demo.waitForExistence(timeout: 10)); demo.tap()
        openWorkspaceAction("splitDocumentNotes", in: app)
        XCTAssertTrue(app.textViews["splitNotes"].waitForExistence(timeout: 5))
        let split = XCTAttachment(screenshot: app.screenshot()); split.name = "AdaptiveSplitNotes"; split.lifetime = .keepAlways; add(split)
    }
    func testPagedMarginsKeepInkTextAndNavigationAfterResizeRotationAndRelaunch() {
        let app = XCUIApplication(); app.launchArguments = ["--test-margin-viewport"]; app.launch()
        XCTAssertTrue(app.buttons["createNotebook"].waitForExistence(timeout: 15)); app.buttons["createNotebook"].tap()
        let name = "Margin continuity " + String(UUID().uuidString.prefix(8))
        let title = app.textFields["notebookTitle"]; title.tap(); title.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 30) + name)
        app.buttons["إنشاء"].tap()
        let note = visibleLibraryDocument(name, in: app); XCTAssertTrue(note.waitForExistence(timeout: 10)); note.tap()
        openWorkspaceAction("splitDocumentNotes", in: app)
        let text = app.textViews["splitNotes"]; XCTAssertTrue(text.waitForExistence(timeout: 5)); text.tap()
        let firstText = "First margin page - keep this text."
        text.typeText(firstText)
        app.segmentedControls["marginMode"].buttons["خط اليد"].tap()
        // PKCanvasView exposes itself as a ScrollView in UIKit's real AX tree.
        let canvas = app.scrollViews["marginInkCanvas"]
        XCTAssertTrue(canvas.waitForExistence(timeout: 5))
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.2)).press(forDuration: 0.1,
            thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: 0.85)))
        let saved = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in (Int(canvas.value as? String ?? "") ?? 0) > 0 }, object: canvas)
        XCTAssertEqual(XCTWaiter.wait(for: [saved], timeout: 10), .completed)
        let count = canvas.value as? String
        assertMarginInkVisible(canvas, in: app, stage: "drawing")
        XCTAssertTrue(app.buttons["addMarginPage"].isHittable)
        app.buttons["addMarginPage"].tap()
        XCTAssertEqual(app.buttons["marginPages"].value as? String, "2/2")
        XCTAssertEqual(canvas.value as? String, "0", "Pages must have independent ink")
        app.segmentedControls["marginMode"].buttons["نص"].tap(); text.tap(); text.typeText("Second margin page")
        app.buttons["previousMarginPage"].tap()
        XCTAssertEqual(text.value as? String, firstText)
        app.segmentedControls["marginMode"].buttons["خط اليد"].tap()
        XCTAssertEqual(canvas.value as? String, count)
        let divider = app.descendants(matching: .any)["splitDivider"].firstMatch
        XCTAssertTrue(divider.exists)
        let start = divider.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: -60, dy: -50)))
        XCTAssertEqual(canvas.value as? String, count)
        app.buttons["fitMargin"].tap(); XCTAssertEqual(canvas.value as? String, count)
        assertMarginInkVisible(canvas, in: app, stage: "fit-sheet")
        app.buttons["fitMarginWidth"].tap(); XCTAssertEqual(canvas.value as? String, count)
        for index in 0..<4 {
            let handle = divider.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            handle.press(forDuration: 0.1, thenDragTo: handle.withOffset(CGVector(dx: index.isMultiple(of: 2) ? 50 : -50, dy: index.isMultiple(of: 2) ? 30 : -30)))
            XCTAssertEqual(canvas.value as? String, count, "Resizing must retain every saved stroke")
            assertMarginInkVisible(canvas, in: app, stage: "resize-\(index + 1)")
        }
        XCUIDevice.shared.orientation = .landscapeLeft
        let landscape = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in app.frame.width > app.frame.height }, object: app)
        XCTAssertEqual(XCTWaiter.wait(for: [landscape], timeout: 5), .completed)
        XCTAssertTrue(app.buttons["addMarginPage"].waitForExistence(timeout: 5)); XCTAssertTrue(app.buttons["addMarginPage"].isHittable)
        XCTAssertEqual(canvas.value as? String, count)
        XCTAssertGreaterThan(canvas.frame.height, 44, "Landscape controls must reserve visible handwriting space")
        assertMarginInkVisible(canvas, in: app, stage: "landscape")
        XCUIDevice.shared.orientation = .portrait
        // Window bounds change before the system finishes rotating the screen.
        // Wait for the physical screenshot orientation as well before tapping.
        let portrait = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let screen = XCUIScreen.main.screenshot().image
            return app.frame.height > app.frame.width && screen.size.height > screen.size.width
                && screen.imageOrientation == .up
        }, object: app)
        XCTAssertEqual(XCTWaiter.wait(for: [portrait], timeout: 5), .completed)
        openExpandedNotes(in: app)
        XCTAssertEqual(canvas.frame.width, app.frame.width, accuracy: 1, "Expanded handwriting must fill the document area")
        XCTAssertTrue(app.buttons["addMarginPage"].isHittable); XCTAssertEqual(canvas.value as? String, count)
        assertMarginInkVisible(canvas, in: app, stage: "full-screen")
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "PagedHandwritingFullScreen"; shot.lifetime = .keepAlways; add(shot)
        app.buttons["expandMargin"].tap()
        openExpandedNotes(in: app)
        XCTAssertEqual(canvas.frame.width, app.frame.width, accuracy: 1, "Reopened handwriting must remain expanded")
        XCTAssertEqual(canvas.value as? String, count, "The Notes menu must reuse the same drawing")
        app.buttons["expandMargin"].tap()
        openWorkspaceAction("addWritingPaper", in: app); app.buttons["نقاط"].tap()
        XCTAssertEqual(app.textFields["pageNumber"].value as? String, "2")
        XCTAssertEqual(app.buttons["marginPages"].value as? String, "1/2", "Document navigation must not turn the notes page")
        app.buttons["previousDocumentPage"].tap(); XCTAssertEqual(app.textFields["pageNumber"].value as? String, "1")
        let split = XCTAttachment(screenshot: app.screenshot()); split.name = "PagedMarginsSplit"; split.lifetime = .keepAlways; add(split)
        app.terminate(); app.launch()
        let reopened = visibleLibraryDocument(name, in: app); XCTAssertTrue(reopened.waitForExistence(timeout: 10)); reopened.tap()
        openWorkspaceAction("splitDocumentNotes", in: app)
        XCTAssertEqual(app.buttons["marginPages"].value as? String, "1/2")
        XCTAssertEqual(app.textViews["splitNotes"].value as? String, firstText)
        app.segmentedControls["marginMode"].buttons["خط اليد"].tap(); XCTAssertEqual(canvas.value as? String, count)
        app.buttons["fitMargin"].tap()
        assertMarginInkVisible(canvas, in: app, stage: "relaunch")
        // Fit Sheet centers a narrow page inside a wide viewport. Begin on
        // that page, rather than in its non-drawable horizontal gutter.
        assertFreshInkUndoRedo(in: app, canvas: canvas, count: canvas,
            strokeStart: CGVector(dx: 0.5, dy: 0.25), strokeEnd: CGVector(dx: 0.5, dy: 0.75))
        assertMarginInkVisible(canvas, in: app, stage: "relaunch-redo")

        app.buttons["nextMarginPage"].tap(); app.segmentedControls["marginMode"].buttons["نص"].tap()
        XCTAssertEqual(app.textViews["splitNotes"].value as? String, "Second margin page")
    }

    // CGRect edge subtraction can report 43.99999999999994 for a 44pt target.
    // Allow only 1e-6pt arithmetic noise; 43.99pt remains an undersized target.
    private let targetFrameTolerance: CGFloat = 1e-6

    private func capturePaperStudio(_ name: String, in app: XCUIApplication) {
        // Capture the complete simulator display after rotation, avoiding an
        // application-rectangle screenshot that can clip landscape content.
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "PaperStudio-" + name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func recordingSeconds(_ element: XCUIElement) -> Int? {
        guard let value = element.value as? String else { return nil }
        let components = value.split(separator: ":").compactMap { Int($0) }
        guard components.count == 2 || components.count == 3 else { return nil }
        return components.reduce(0) { $0 * 60 + $1 }
    }

    private func assertExpandedNotesHideRetainedPDF(_ document: XCUIElement, in app: XCUIApplication) {
        // Retention is required to preserve PDF/ink state. "exists" alone also
        // includes XCTest's hidden identified nodes (proved in39610168480).
        XCTAssertEqual(app.buttons["expandMargin"].label, "العودة إلى المستند")
        XCTAssertFalse(app.descendants(matching: .any)["splitDivider"].firstMatch.exists,
                       "This must be expanded Notes, not an accidental lost PDF in a split")
        let canvas = app.scrollViews["marginInkCanvas"]
        XCTAssertTrue(canvas.exists)
        XCTAssertGreaterThan(canvas.frame.height, 44)
        if document.exists {
            XCTAssertFalse(document.isHittable, "The hidden retained PDF must never accept input through full-screen Notes")
            let trace = document.value as? String ?? ""
            XCTAssertTrue(trace.contains("hidden=true; axHidden=true;"), "Verify the actual native UIKit visibility and accessibility flags: " + trace)
            XCTAssertTrue(trace.contains("pdfCenterReceives=") && trace.contains("MarginCanvas"),
                          "The Notes canvas must receive the actual UIKit hit test at the retained PDF's center: " + trace)
        }
    }

    private func captureAdvancingRecording(in app: XCUIApplication, name: String, requiresDocument: Bool, margin: XCUIElement? = nil) {
        let strip = app.descendants(matching: .any)["recordingStrip"].firstMatch
        let record = app.buttons["recordLinkedAudio"]
        let elapsed = app.staticTexts["recordingElapsed"]
        let document = app.otherElements["pdfCanvas"]
        XCTAssertTrue(strip.waitForExistence(timeout: 5))
        XCTAssertTrue(record.isHittable)
        XCTAssertGreaterThanOrEqual(record.frame.width, 44)
        XCTAssertGreaterThanOrEqual(record.frame.height, 44)
        if requiresDocument {
            guard document.waitForExistence(timeout: 5) else {
                XCTFail("Split recording must retain the PDF canvas"); return
            }
        } else {
            assertExpandedNotesHideRetainedPDF(document, in: app)
        }
        let stripFrame = strip.frame, documentFrame = requiresDocument ? document.frame : nil
        let marginFrame = margin?.frame
        let marginPosition = app.buttons["marginPages"].value as? String
        let initialSeconds = recordingSeconds(elapsed) ?? 0
        record.tap()
        let permission = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.matching(
            NSPredicate(format: "label CONTAINS[c] %@ OR label CONTAINS %@", "Microphone", "الميكروفون")).firstMatch
        func allowRequestedMicrophone() {
            let allow = permission.buttons["Allow"], ok = permission.buttons["OK"]
            if allow.exists { allow.tap() } else if ok.exists { ok.tap() }
        }
        if permission.waitForExistence(timeout: 2) { allowRequestedMicrophone() }
        // The native prompt can appear after the initial observation. Handle it
        // inside the same start deadline, before requiring actual recording.
        // A later Stop tap must not be the first input that grants permission.
        let started = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            if permission.exists { allowRequestedMicrophone() }
            return record.value as? String == "جارٍ التسجيل"
        }, object: record)
        XCTAssertEqual(XCTWaiter.wait(for: [started], timeout: 10), .completed)
        let advancing = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            (self.recordingSeconds(elapsed) ?? 0) >= initialSeconds + 2
        }, object: elapsed)
        XCTAssertEqual(XCTWaiter.wait(for: [advancing], timeout: 10), .completed, "Duration must advance from actual recording")
        XCTAssertEqual(strip.frame, stripFrame, "The strip must retain its idle geometry")
        if let documentFrame {
            XCTAssertTrue(document.exists, "PDF must remain present during split recording")
            XCTAssertEqual(document.frame, documentFrame, "Recording must preserve the document viewport")
        }
        if !requiresDocument { assertExpandedNotesHideRetainedPDF(document, in: app) }
        if let marginFrame, let margin { XCTAssertEqual(margin.frame, marginFrame, "Recording must preserve the handwriting viewport") }
        XCTAssertEqual(app.buttons["marginPages"].value as? String, marginPosition)
        let level = app.descendants(matching: .any)["recordingLevel"].firstMatch
        XCTAssertTrue(level.exists, "The strip must expose real microphone level")
        let levelValue = (level.value as? String ?? "").filter { $0.isNumber }
        XCTAssertTrue((0...100).contains(Int(levelValue) ?? -1), "Microphone level must remain bounded")
        capturePaperStudio(name + "-Recording", in: app)
        record.tap()
        let stopped = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "متوقف"), object: record)
        XCTAssertEqual(XCTWaiter.wait(for: [stopped], timeout: 5), .completed)
        XCTAssertEqual(strip.frame, stripFrame)
        if let documentFrame {
            XCTAssertTrue(document.exists, "PDF must remain present after split recording")
            XCTAssertEqual(document.frame, documentFrame)
        }
        if !requiresDocument { assertExpandedNotesHideRetainedPDF(document, in: app) }
        if let marginFrame, let margin { XCTAssertEqual(margin.frame, marginFrame) }
    }

    private func capturePaperStudioAppearanceJourney(_ appearance: String) {
        // CI executes each real appearance journey on both device families.
        // Each fresh launch has its own unchanged 240-second XCTest allowance.
        defer { XCUIDevice.shared.orientation = .portrait }
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        defer { app.terminate() }
        app.launchArguments = ["--test-review-entry", "--test-reset-entrance", "--test-appearance-" + appearance, "--test-motion-enabled"]
        app.launch()
        let demo = app.buttons["welcomeDemonstration"]
        XCTAssertTrue(demo.waitForExistence(timeout: 15))
        XCTAssertTrue(demo.isHittable)
        capturePaperStudio(appearance + "-FirstLaunchWelcome", in: app)
        demo.tap()
        let pdf = app.otherElements["pdfCanvas"]
        XCTAssertTrue(pdf.waitForExistence(timeout: 15))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["librarySections"].waitForExistence(timeout: 10))
        capturePaperStudio(appearance + "-LibraryPortrait", in: app)
        visibleLibraryDocument("ابدأ هنا — دليل طَيّة", in: app).tap()
        XCTAssertTrue(app.buttons["inkTool"].waitForExistence(timeout: 10))
        capturePaperStudio(appearance + "-DocumentToolsPortrait", in: app)
        openWorkspaceAction("splitDocumentNotes", in: app)
        app.segmentedControls["marginMode"].buttons["خط اليد"].tap()
        let margin = app.scrollViews["marginInkCanvas"]
        XCTAssertTrue(margin.waitForExistence(timeout: 5))
        let before = Int(margin.value as? String ?? "") ?? 0
        margin.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.3)).press(forDuration: 0.1,
            thenDragTo: margin.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.6)))
        let saved = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            (Int(margin.value as? String ?? "") ?? 0) > before
        }, object: margin)
        XCTAssertEqual(XCTWaiter.wait(for: [saved], timeout: 10), .completed)
        assertMarginInkVisible(margin, in: app, stage: "paper-studio-" + appearance)
        capturePaperStudio(appearance + "-SplitHandwritingPortrait", in: app)
        XCUIDevice.shared.orientation = .landscapeLeft
        let rotated = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in app.frame.width > app.frame.height }, object: app)
        XCTAssertEqual(XCTWaiter.wait(for: [rotated], timeout: 5), .completed)
        XCTAssertGreaterThan(margin.frame.height, 44, "Compact landscape must retain handwriting space")
        for identifier in ["addMarginPage", "nextDocumentPage"] {
            let control = app.buttons[identifier]
            XCTAssertTrue(control.isHittable)
            XCTAssertGreaterThanOrEqual(control.frame.width + targetFrameTolerance, 44, identifier)
            XCTAssertGreaterThanOrEqual(control.frame.height + targetFrameTolerance, 44, identifier)
        }
        capturePaperStudio(appearance + "-SplitHandwritingLandscape", in: app)
        captureAdvancingRecording(in: app, name: appearance + "-Landscape", requiresDocument: true, margin: margin)
        // Return to the library in landscape to capture the adaptive covers/navigation.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["librarySections"].waitForExistence(timeout: 10))
        capturePaperStudio(appearance + "-LibraryLandscape", in: app)
    }

    func testPaperStudioLightVisualCaptureJourney() {
        capturePaperStudioAppearanceJourney("light")
    }

    func testPaperStudioDarkVisualCaptureJourney() {
        capturePaperStudioAppearanceJourney("dark")
    }

    func testNotesDockOpensFromOnePressAcrossScrollTouchDelayBoundary() {
        // Characterize the lost first touch, not a retry of the failing journey.
        // A dropped handler leaves Notes closed; a duplicate handler skips split.
        // Each duration starts from a fresh review root and a closed Notes dock.
        defer { XCUIDevice.shared.orientation = .portrait }
        XCUIDevice.shared.orientation = .portrait
        let durations: [TimeInterval] = [0.05, 0.18, 0.35]
        for duration in durations {
            XCTContext.runActivity(named: "First Notes press \(duration)s") { _ in
                let app = XCUIApplication()
                defer { app.terminate() }
                app.launchArguments = ["--test-review-entry", "--test-reset-entrance", "--test-appearance-light", "--test-accessibility-type", "--test-reduce-motion", "--test-native-menu", "--test-native-visibility", "--test-notes-dock-input"]
                app.launch()
                let demo = app.buttons["welcomeDemonstration"]
                guard demo.waitForExistence(timeout: 15), demo.isHittable else {
                    XCTFail("The real demonstration must be ready before testing its Notes dock"); return
                }
                demo.tap()
                guard app.buttons["inkTool"].waitForExistence(timeout: 15) else {
                    XCTFail("The real document must open before its first Notes press"); return
                }
                let notes = app.buttons["openMargin"]
                XCTAssertTrue(notes.isHittable)
                XCTAssertTrue(app.windows.firstMatch.frame.contains(notes.frame), "Press a fully visible Notes control")
                let expand = app.buttons["expandMargin"]
                XCTAssertFalse(expand.exists, "Each independent contact begins with Notes closed")
                capturePaperStudio("NotesContact-\(duration)-Before", in: app)
                print("NotesContact firstPressSeconds=\(duration) target=\(notes.frame)")
                notes.press(forDuration: duration)
                guard expand.waitForExistence(timeout: 5) else {
                    capturePaperStudio("NotesContact-\(duration)-Failure", in: app)
                    XCTFail("One valid \(duration)s Notes press must open Notes without another press"); return
                }
                let isPad = UIDevice.current.userInterfaceIdiom == .pad
                XCTAssertEqual(expand.label, isPad ? "تكبير الملاحظات" : "العودة إلى المستند",
                               "One press must make exactly the first Notes transition")
                XCTAssertEqual(app.descendants(matching: .any)["splitDivider"].firstMatch.exists, isPad)
                capturePaperStudio("NotesContact-\(duration)-After", in: app)
            }
        }
    }

    func testPaperStudioAccessibilityReduceMotionVisualCaptureJourney() {
        defer { XCUIDevice.shared.orientation = .portrait }
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        defer { app.terminate() }
        app.launchArguments = ["--test-review-entry", "--test-reset-entrance", "--test-appearance-light", "--test-accessibility-type", "--test-reduce-motion", "--test-native-menu", "--test-native-visibility", "--test-notes-dock-input"]
        app.launch()
        let demo = app.buttons["welcomeDemonstration"]
        XCTAssertTrue(demo.waitForExistence(timeout: 15))
        if !demo.isHittable { app.swipeUp() }
        XCTAssertTrue(demo.isHittable)
        XCTAssertFalse(app.otherElements["openingAnimation"].exists, "Reduce Motion must skip the entrance")
        capturePaperStudio("AccessibilityType-ReduceMotion-Welcome", in: app)
        demo.tap()
        XCTAssertTrue(app.buttons["inkTool"].waitForExistence(timeout: 15))
        capturePaperStudio("AccessibilityType-DocumentTools", in: app)
        openExpandedNotes(in: app)
        XCTAssertTrue(app.segmentedControls["marginMode"].waitForExistence(timeout: 5))
        app.segmentedControls["marginMode"].buttons["خط اليد"].tap()
        let margin = app.scrollViews["marginInkCanvas"]
        XCTAssertTrue(margin.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(margin.frame.height, 44)
        capturePaperStudio("AccessibilityType-ExpandedHandwriting", in: app)
        captureAdvancingRecording(in: app, name: "AccessibilityType-Expanded", requiresDocument: false, margin: margin)
    }

    func testColdExternalPDFIntakeSurvivesFirstLaunchEntrance() throws {
        try verifyExternalPDFIntake(reduceMotion: false, welcomeAlreadyVisible: false)
    }

    func testColdExternalPDFIntakeWithReduceMotion() throws {
        try verifyExternalPDFIntake(reduceMotion: true, welcomeAlreadyVisible: false)
    }

    func testExternalPDFIntakeDismissesAlreadyVisibleWelcome() throws {
        try verifyExternalPDFIntake(reduceMotion: false, welcomeAlreadyVisible: true)
    }

    private func verifyExternalPDFIntake(reduceMotion: Bool, welcomeAlreadyVisible: Bool) throws {
        let app = XCUIApplication()
        app.terminate()
        app.launchArguments = ["--test-review-entry", "--test-reset-entrance",
            reduceMotion ? "--test-reduce-motion" : "--test-motion-enabled"]
        if welcomeAlreadyVisible {
            app.launch()
            let welcome = app.buttons["welcomeDemonstration"]
            guard welcome.waitForExistence(timeout: 15), welcome.isHittable else {
                XCTFail("External intake must be delivered while welcome is already presented"); return
            }
            capturePaperStudio("ExternalIntake-WelcomeBeforeDelivery", in: app)
        }
        let variant = welcomeAlreadyVisible ? "VisibleWelcome" : reduceMotion ? "ColdReduceMotion" : "ColdMotion"
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("ColdIntake-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let title = "Cold entrance " + String(UUID().uuidString.prefix(8))
        let url = folder.appendingPathComponent(title + ".pdf")
        let marker = "Cold intake content " + String(UUID().uuidString.prefix(8))
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
        try renderer.writePDF(to: url) { context in
            for page in 1...2 {
                context.beginPage()
                ((marker + " page \(page)") as NSString).draw(at: CGPoint(x: 40, y: 60), withAttributes: [.font: UIFont.systemFont(ofSize: 24)])
            }
        }
        // Cold variants launch by URL; the visible-welcome variant delivers
        // to the running app. Every variant exercises the same real onOpenURL.
        app.open(url)
        let status = app.staticTexts.matching(NSPredicate(format: "identifier == %@ AND label CONTAINS %@",
            "importStatus", "تم استيراد " + title)).firstMatch
        XCTAssertTrue(status.waitForExistence(timeout: 20), "Cold launch must complete the external PDF import")
        XCTAssertTrue(status.label.contains("تم استيراد " + title), status.label)
        XCTAssertFalse(app.buttons["welcomeDemonstration"].exists, "Welcome must not interrupt external intake")
        let card = visibleLibraryDocument(title, in: app)
        XCTAssertTrue(card.isHittable)
        capturePaperStudio("ExternalIntake-" + variant + "-Library", in: app)
        // Search the actual PDF contents, then open the imported card through
        // the real library. The filename alone cannot satisfy this check.
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5)); search.tap(); search.typeText(marker)
        guard tapVisibleContentResult(title: title, marker: marker, in: app) else { return }
        let page = app.textFields["pageNumber"]
        XCTAssertTrue(page.waitForExistence(timeout: 10))
        XCTAssertTrue(app.otherElements["pdfCanvas"].exists, "Actual imported content must open in the native PDF reader")
        XCTAssertEqual(page.value as? String, "1")
        XCTAssertTrue(app.buttons["nextDocumentPage"].isEnabled)
        app.buttons["nextDocumentPage"].tap()
        XCTAssertEqual(page.value as? String, "2", "Both generated PDF pages must reach the real reader")
        XCTAssertFalse(app.buttons["nextDocumentPage"].isEnabled)
        capturePaperStudio("ExternalIntake-" + variant + "-ImportedDocument", in: app)
    }

    private func tapVisibleContentResult(title: String, marker: String, in app: XCUIApplication) -> Bool {
        let matchingContent = NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", title, marker)
        let result = app.buttons.matching(matchingContent).firstMatch
        guard result.waitForExistence(timeout: 10) else {
            XCTFail("Imported PDF text must appear in a real search result"); return false
        }
        let results = app.scrollViews.containing(matchingContent).firstMatch
        guard results.exists else { XCTFail("Content results must belong to the real scrollable library"); return false }
        for _ in 0..<4 {
            let window = app.windows.firstMatch.frame
            var visible = results.frame.intersection(window)
            let keyboard = app.keyboards.firstMatch
            if keyboard.exists {
                visible = visible.intersection(CGRect(x: window.minX, y: window.minY,
                    width: window.width, height: max(0, keyboard.frame.minY - window.minY)))
            }
            let home = app.buttons["libraryHome"], sections = app.buttons["librarySections"]
            if home.exists && sections.exists && abs(home.frame.midY - sections.frame.midY) < 1 {
                // A horizontal destination dock clips results above the keyboard.
                // The iPad's vertical sidebar is outside this scrolling column.
                visible.size.height = max(0, min(visible.maxY, home.frame.minY) - visible.minY)
            }
            let target = result.frame
            if !visible.isEmpty && visible.contains(target) && result.isHittable {
                XCTAssertGreaterThanOrEqual(target.width + targetFrameTolerance, 44)
                XCTAssertGreaterThanOrEqual(target.height + targetFrameTolerance, 44)
                let receipt = XCTAttachment(string: "result=\(target); visibleLibrary=\(visible); label=\(result.label)")
                receipt.name = "ExternalIntake-VisibleContentResult"; receipt.lifetime = .keepAlways; add(receipt)
                result.tap(); return true
            }
            // XCTest's default swipe began at y=578 in the fixed status strip,
            // below the library's visible bottom edge. Start inside the actual
            // viewport so UIKit delivers the drag to the library scroll view.
            guard !visible.isNull, visible.width >= 44, visible.height >= 88 else {
                XCTFail("The library must expose a usable scrolling viewport"); return false
            }
            let receipt = XCTAttachment(string: "result=\(target); visibleLibrary=\(visible)")
            receipt.name = "ExternalIntake-ScrollViewport"; receipt.lifetime = .keepAlways; add(receipt)
            let origin = app.windows.firstMatch.coordinate(withNormalizedOffset: .zero)
            let start = origin.withOffset(CGVector(dx: visible.midX - window.minX, dy: visible.maxY - window.minY - 24))
            let end = origin.withOffset(CGVector(dx: visible.midX - window.minX, dy: visible.minY - window.minY + 24))
            start.press(forDuration: 0.1, thenDragTo: end)
        }
        let failure = XCTAttachment(screenshot: app.screenshot())
        failure.name = "ExternalIntake-ContentResultNotVisible"; failure.lifetime = .keepAlways; add(failure)
        XCTFail("The complete content result must be visible above the dock and keyboard before tapping"); return false
    }

    private func waitForNativeInkColorService(name: String) -> Bool {
        // The host sheet can exist before its OS-owned service starts. Recorded
        // RBS bootstrap delays were 43.360s and 20.665s on cold CI simulators.
        // Observe process readiness without launching or prewarming the service;
        // the original 5s checks for actual picker content still follow this.
        let service = XCUIApplication(bundleIdentifier: "com.apple.UIKit.ColorPickerUIService")
        let started = ProcessInfo.processInfo.systemUptime
        let initial = service.state
        var observed = [initial.rawValue]
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let state = service.state
            if observed.last != state.rawValue { observed.append(state.rawValue) }
            // A reused service can still be in the background after the prior
            // sheet closes. Its process existing does not mean this sheet's
            // remote content is ready (observed state3 with no picker controls).
            return state == .runningForeground
        }, object: service)
        let result = XCTWaiter.wait(for: [ready], timeout: 60)
        let elapsed = ProcessInfo.processInfo.systemUptime - started
        let state = "bundle=com.apple.UIKit.ColorPickerUIService; initial=\(initial.rawValue); final=\(service.state.rawValue); observed=\(observed); elapsed=\(elapsed); result=\(result.rawValue)"
        let evidence = XCTAttachment(string: state)
        evidence.name = name + "-NativeSystemColorServiceStartup"
        evidence.lifetime = .keepAlways; add(evidence)
        print("NativeSystemColorServiceStartup \(name): \(state)")
        guard result == .completed else {
            XCTFail("The OS color service did not start within its bounded startup allowance: " + state)
            return false
        }
        return true
    }

    private func nativeInkPresenterState(in app: XCUIApplication) -> String {
        let anchors = app.otherElements.matching(identifier: "nativeInkPresenterState").allElementsBoundByIndex
        return "anchors=\(anchors.count); " + anchors.prefix(4).enumerated().map { index, anchor in
            "anchor\(index)=" + (anchor.value as? String ?? "missing")
        }.joined(separator: "\n")
    }

    private func tapInkTarget(_ identifier: String, in app: XCUIApplication, writingSurface: XCUIElement) -> Bool {
        let toolbar = app.scrollViews["inkToolbar"].firstMatch
        let control = toolbar.descendants(matching: .any)[identifier].firstMatch
        guard toolbar.waitForExistence(timeout: 5), control.waitForExistence(timeout: 5) else {
            XCTFail("Missing individual ink control: " + identifier); return false
        }
        // The full-width native rail can extend outside the Notes pane.
        // Its real window intersection, not Notes width, defines safe touches.
        func visibleViewport() -> CGRect {
            // The shared rail spans both native panes, while their union still
            // excludes landscape safe areas. Never use only the narrow Notes pane.
            var paper = writingSurface.frame
            let pdf = app.otherElements["pdfCanvas"]
            if pdf.exists { paper = paper.union(pdf.frame) }
            let frame = toolbar.frame
            return frame.intersection(CGRect(x: paper.minX, y: frame.minY,
                width: paper.width, height: frame.height))
                .intersection(app.windows.firstMatch.frame).intersection(app.frame)
        }
        func containsTarget(_ target: CGRect, in viewport: CGRect) -> Bool {
            !viewport.isNull && !viewport.isEmpty
                && viewport.insetBy(dx: -targetFrameTolerance, dy: -targetFrameTolerance).contains(target)
        }
        // Reuse measured geometry until an input can move it. Repeated AX
        // queries without an intervening gesture add automation overhead;
        // refresh the target and viewport after every real drag below.
        var viewport = visibleViewport(), target = control.frame
        for _ in 0..<8 {
            guard !viewport.isNull, viewport.width >= 44 else {
                XCTFail("Ink toolbar must expose a native viewport: " + identifier); return false
            }
            if containsTarget(target, in: viewport) { break }
            let distance = target.minX < viewport.minX
                ? viewport.minX - target.minX + 12 : viewport.maxX - target.maxX - 12
            // Small, measured drags avoid oscillating past a partially visible
            // target when the compact toolbar is narrower than its contents.
            let delta = max(-viewport.width * 0.4, min(viewport.width * 0.4, distance))
            let applicationFrame = app.frame
            let start = app.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: viewport.midX - applicationFrame.minX,
                    dy: viewport.midY - applicationFrame.minY))
            let nativeBefore = nativeInkPresenterState(in: app)
            start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: delta, dy: 0)))
            let previousTarget = target
            target = control.frame
            viewport = visibleViewport()
            let moved = target.minX - previousTarget.minX
            let native = XCTAttachment(string: "before=" + nativeBefore + "\nafter=" + nativeInkPresenterState(in: app))
            native.name = "InkTarget-" + identifier + "-NativeScrollState"; native.lifetime = .keepAlways; add(native)
            guard abs(moved) > 1, moved * delta > 0 else {
                XCTFail("Ink toolbar drag must actually scroll " + identifier
                    + "; before=\(previousTarget), after=\(target), viewport=\(viewport)"); return false
            }
        }
        guard containsTarget(target, in: viewport), control.isHittable else {
            XCTFail("Cannot scroll the complete ink target into view: " + identifier); return false
        }
        XCTAssertGreaterThanOrEqual(target.width + targetFrameTolerance, 44, identifier)
        XCTAssertGreaterThanOrEqual(target.height + targetFrameTolerance, 44, identifier)
        let geometry = XCTAttachment(string: "target=\(target); native viewport=\(viewport)")
        geometry.name = "InkTarget-" + identifier + "-TapGeometry"; geometry.lifetime = .keepAlways; add(geometry)
        // Tap the lower edge of the 44pt target, outside the small icon/swatch.
        control.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 1))
            .withOffset(CGVector(dx: 0, dy: -2)).tap()
        return true
    }

    private func nativeInkRGBA(_ value: String) -> [Double]? {
        guard value.hasPrefix("rgba:") else { return nil }
        let components = value.dropFirst(5).split(separator: ",").compactMap { Double($0) }
        return components.count == 4 ? components : nil
    }

    private func redInkPixels(in screenshot: UIImage, frame canvasFrame: CGRect) -> Int {
        // Apply UIImage orientation before mapping XCTest's screen-space frame.
        let format = UIGraphicsImageRendererFormat(); format.scale = screenshot.scale
        let upright = UIGraphicsImageRenderer(size: screenshot.size, format: format).image { _ in
            screenshot.draw(in: CGRect(origin: .zero, size: screenshot.size))
        }
        guard let image = upright.cgImage else { return 0 }
        let screen = CGRect(origin: .zero, size: upright.size)
        let frame = canvasFrame.insetBy(dx: 2, dy: 2).intersection(screen)
        guard !frame.isNull, !frame.isEmpty else { return 0 }
        let scale = CGFloat(image.width) / upright.size.width
        let crop = CGRect(x: frame.minX * scale, y: frame.minY * scale,
            width: frame.width * scale, height: frame.height * scale)
            .intersection(CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard let ink = image.cropping(to: crop), ink.width > 0, ink.height > 0 else { return 0 }
        var pixels = [UInt8](repeating: 0, count: ink.width * ink.height * 4)
        return pixels.withUnsafeMutableBytes { bytes in
            guard let context = CGContext(data: bytes.baseAddress, width: ink.width, height: ink.height,
                bitsPerComponent: 8, bytesPerRow: ink.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else { return 0 }
            context.draw(ink, in: CGRect(x: 0, y: 0, width: ink.width, height: ink.height))
            var count = 0
            for index in stride(from: 0, to: bytes.count, by: 4) {
                let red = Int(bytes[index]), green = Int(bytes[index + 1]), blue = Int(bytes[index + 2])
                if red > green + 25 && red > blue + 25 && red > 80 { count += 1 }
            }
            return count
        }
    }

    private func exerciseIndividualInkTargets(in app: XCUIApplication, canvas: XCUIElement,
                                             count: XCUIElement, allowsWidthFit: Bool, name: String,
                                             paletteTransitions: Int = 1) -> Bool {
        func tapTarget(_ identifier: String) -> Bool {
            tapInkTarget(identifier, in: app, writingSurface: canvas)
        }
        func recordState(_ stage: String, expected: String? = nil) {
            let state = "expected=\(expected ?? "unset"); actual=\(count.value as? String ?? "missing"); frame=\(canvas.frame); label=\(canvas.label)"
            let trace = XCTAttachment(string: state)
            trace.name = name + "-" + stage + "-NativeInkState"; trace.lifetime = .keepAlways; add(trace)
            print("NativeInkEvidence stage=\(name)-\(stage); \(state)")
        }
        guard tapTarget("inkBrush") else { return false }
        let pencil = app.buttons["رصاص"].firstMatch
        guard pencil.waitForExistence(timeout: 5) else { XCTFail("Brush target must open its menu"); return false }
        pencil.tap()
        XCTAssertTrue(app.buttons["inkBrush"].label.contains("رصاص"))
        guard tapTarget("inkWidth") else { return false }
        let width = app.buttons["سماكة 8"].firstMatch
        guard width.waitForExistence(timeout: 5) else { XCTFail("Width target must open its menu"); return false }
        width.tap()
        XCTAssertEqual(app.buttons["inkWidth"].value as? String, "8")
        let colorControl = app.buttons["inkColor"].firstMatch
        guard let initialColor = colorControl.value as? String, nativeInkRGBA(initialColor) != nil else {
            XCTFail("Ink color target must expose its actual current RGBA before selection"); return false
        }
        guard tapTarget("inkColor") else { return false }
        let picker = app.otherElements["nativeInkColorPicker"].firstMatch
        guard picker.waitForExistence(timeout: 5) else {
            XCTFail("Color target must present the native color picker: " + app.debugDescription); return false
        }
        guard waitForNativeInkColorService(name: name) else { return false }
        guard picker.segmentedControls.firstMatch.waitForExistence(timeout: 5) else {
            let native = XCTAttachment(string: nativeInkPresenterState(in: app))
            native.name = name + "-NativePalettePresentation"; native.lifetime = .keepAlways; add(native)
            XCTFail("Color target must present the native color picker: " + app.debugDescription); return false
        }
        let close = app.buttons["closeInkColorPicker"].firstMatch
        guard close.waitForExistence(timeout: 5), close.isHittable else {
            XCTFail("Native color picker must expose its close action: " + app.debugDescription); return false
        }
        XCTAssertGreaterThanOrEqual(close.frame.width + targetFrameTolerance, 44)
        XCTAssertGreaterThanOrEqual(close.frame.height + targetFrameTolerance, 44)
        // UIColorPickerViewController keeps its full Grid AX contents when
        // landscape reduces the native sheet to ~420pt. On that compact
        // presentation, "red 77" can exist at y>600 while the picker cannot
        // scroll far enough for a user to tap it. Exercise an actually visible
        // native red swatch in compact layouts; still assert the resulting
        // RGBA change, red ink pixels, real stroke save, undo and redo below.
        // Portrait retains the saturated "red 77" regression path.
        let compactPalette = picker.frame.height < 600
        let nativeRedLabel = compactPalette ? "dark red 16" : "red 77"
        let swatch = picker.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", nativeRedLabel)).firstMatch
        guard swatch.waitForExistence(timeout: 5) else {
            XCTFail("Actual native Grid must expose " + nativeRedLabel + ": " + app.debugDescription); return false
        }
        let paletteScroll = picker.scrollViews.firstMatch
        var paletteNavigation: [String] = ["picker=\(picker.frame); swatch=\(nativeRedLabel); initial=\(swatch.frame)"]
        // A taller native presentation can expose red 77 after a real scroll;
        // compact layouts deliberately start from a visible native red instead.
        if !compactPalette {
            for attempt in 0..<4 {
                if swatch.isHittable { break }
                guard paletteScroll.exists, paletteScroll.isHittable else { break }
                let before = swatch.frame
                paletteScroll.swipeUp()
                paletteNavigation.append("swipe=\(attempt + 1); before=\(before); after=\(swatch.frame); hittable=\(swatch.isHittable)")
            }
        }
        let navigation = XCTAttachment(string: paletteNavigation.joined(separator: "\n"))
        navigation.name = name + "-NativePaletteNavigation"; navigation.lifetime = .keepAlways; add(navigation)
        guard swatch.isHittable else {
            XCTFail("Actual native Grid must expose a hittable " + nativeRedLabel + ": " + app.debugDescription); return false
        }
        swatch.tap()
        capturePaperStudio(name + "-NativeColorPicker", in: app)
        close.tap()
        // One fresh snapshot checks both original dismissal conditions.
        let pickerElements = app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier IN %@", ["nativeInkColorPicker", "closeInkColorPicker"]))
        let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            pickerElements.count == 0
        }, object: app)
        guard XCTWaiter.wait(for: [dismissed], timeout: 5) == .completed else {
            XCTFail("Native color picker must dismiss before testing ink actions"); return false
        }
        let changedColor = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard let value = colorControl.value as? String, value != initialColor,
                  let components = self.nativeInkRGBA(value), components.count == 4 else { return false }
            return components[0] > components[1] + 0.1 && components[0] > components[2] + 0.1
                && components[3] > 0.99
        }, object: colorControl)
        guard XCTWaiter.wait(for: [changedColor], timeout: 5) == .completed else {
            XCTFail("Native swatch must change the actual bound ink color; before=\(initialColor), after=\(colorControl.value as? String ?? "missing")"); return false
        }
        if paletteTransitions > 1 {
            let selectedColor = colorControl.value as? String
            for transition in 1..<paletteTransitions {
                guard tapTarget("inkColor"), picker.waitForExistence(timeout: 5),
                      waitForNativeInkColorService(name: name + "-Transition\(transition)"),
                      picker.segmentedControls.firstMatch.waitForExistence(timeout: 5), close.isHittable else {
                    XCTFail("A subsequent native palette must remain usable"); return false
                }
                close.tap()
                let closed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                    pickerElements.count == 0
                }, object: app)
                guard XCTWaiter.wait(for: [closed], timeout: 5) == .completed else {
                    XCTFail("Each palette must actually dismiss before the next real interaction"); return false
                }
                XCTAssertEqual(colorControl.value as? String, selectedColor,
                               "Opening and closing the palette must retain the selected ink")
                recordState("PaletteTransition\(transition)")
            }
        }
        let strokeFrame = canvas.frame
        let applicationFrame = app.frame
        let pixelFrame = strokeFrame.intersection(applicationFrame)
        let beforeStroke = XCUIScreen.main.screenshot()
        let beforeRed = redInkPixels(in: beforeStroke.image, frame: pixelFrame)
        let baseline = XCTAttachment(screenshot: beforeStroke)
        baseline.name = name + "-RedPixelBaseline"; baseline.lifetime = .keepAlways; add(baseline)
        let before = Int(count.value as? String ?? "") ?? 0
        recordState("BeforeStroke", expected: String(before))
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.35)).press(forDuration: 0.1,
            thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.65, dy: 0.5)))
        // Observe presentation before querying the native drawing hierarchy.
        // XCTest describes XCUIElement expectation objects through AX on every
        // poll, even if the predicate itself only reads the screen. Keep this
        // exact >40-pixel/5s contract independent of those diagnostic getters.
        let pollingStarted = ProcessInfo.processInfo.systemUptime
        print("NativeInkVisibility stage=\(name); observer=screen-only; begin")
        var pixelSamples: [(started: Double, captured: Double, measured: Double, pixels: Int)] = []
        let visibleRed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let started = ProcessInfo.processInfo.systemUptime
            let screenshot = XCUIScreen.main.screenshot()
            let captured = ProcessInfo.processInfo.systemUptime
            let pixels = self.redInkPixels(in: screenshot.image, frame: pixelFrame)
            pixelSamples.append((started - pollingStarted, captured - pollingStarted,
                ProcessInfo.processInfo.systemUptime - pollingStarted, pixels))
            return pixels - beforeRed > 40
        }, object: NSObject())
        let visibleResult = XCTWaiter.wait(for: [visibleRed], timeout: 5)
        print("NativeInkVisibility stage=\(name); observer=screen-only; result=\(visibleResult.rawValue)")
        let saved = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            (Int(count.value as? String ?? "") ?? 0) > before
        }, object: count)
        XCTAssertEqual(XCTWaiter.wait(for: [saved], timeout: 10), .completed, "Targets must leave a usable native writing surface")
        XCTAssertEqual(canvas.frame, strokeFrame, "Color stroke must preserve the measured writing surface")
        XCTAssertEqual(app.frame, applicationFrame, "Color stroke must preserve the measured application frame")
        let polling = XCTAttachment(string: "result=\(visibleResult.rawValue); baseline=\(beforeRed); crop=\(pixelFrame)\n"
            + pixelSamples.map { "start=\($0.started); captured=\($0.captured); measured=\($0.measured); red=\($0.pixels); delta=\($0.pixels - beforeRed)" }.joined(separator: "\n"))
        polling.name = name + "-RedPixelPolling"; polling.lifetime = .keepAlways; add(polling)
        guard visibleResult == .completed else {
            let afterStroke = XCUIScreen.main.screenshot()
            let evidence = XCTAttachment(screenshot: afterStroke)
            evidence.name = name + "-RedPixelFailure"; evidence.lifetime = .keepAlways; add(evidence)
            let measured = redInkPixels(in: afterStroke.image, frame: pixelFrame)
            let geometry = XCTAttachment(string: "beforeRed=\(beforeRed); afterRed=\(measured); delta=\(measured - beforeRed); beforeCount=\(before); afterCount=\(count.value as? String ?? "missing"); rgba=\(colorControl.value as? String ?? "missing"); beforeFrame=\(strokeFrame); afterFrame=\(canvas.frame); appFrame=\(app.frame); screenshotSize=\(afterStroke.image.size); screenshotScale=\(afterStroke.image.scale); screenshotOrientation=\(afterStroke.image.imageOrientation.rawValue); canvasLabel=\(canvas.label)")
            geometry.name = name + "-RedPixelFailureMeasurement"; geometry.lifetime = .keepAlways; add(geometry)
            recordState("StrokeNotVisible", expected: String(before))
            let elementEvidence = XCTAttachment(screenshot: canvas.screenshot())
            elementEvidence.name = name + "-RedPixelFailureElement"; elementEvidence.lifetime = .keepAlways; add(elementEvidence)
            if canvas.identifier == "marginInkCanvas" {
                // Read the existing bounded lifecycle transport only AFTER the
                // original pixel failure; never mutate or warm the live canvas.
                let lifecycle = XCTAttachment(string: app.segmentedControls["marginMode"].label)
                lifecycle.name = name + "-FailedRenderLifecycle"; lifecycle.lifetime = .keepAlways; add(lifecycle)
            }
            XCTFail("Actual native writing surface must gain >40 red-dominant pixels after the stroke")
            if app.launchArguments.contains("--test-margin-details"), canvas.identifier == "marginInkCanvas" {
                // Preserve the original failure. Subsequent real user actions
                // distinguish a stale first-stroke render from lost ink data.
                let native = XCTAttachment(string: app.segmentedControls["marginMode"].label)
                native.name = name + "-FailedRenderNativeHierarchy"; native.lifetime = .keepAlways; add(native)
                let late = XCUIScreen.main.screenshot()
                let lateImage = XCTAttachment(screenshot: late)
                lateImage.name = name + "-FailedRender-BeforeRecovery"; lateImage.lifetime = .keepAlways; add(lateImage)
                print("NativeInkRenderProbe beforeRecovery red=\(redInkPixels(in: late.image, frame: pixelFrame)); count=\(count.value as? String ?? "missing")")
                for action in ["inkUndo", "inkRedo"] {
                    guard tapTarget(action) else { return false }
                    let screenshot = XCUIScreen.main.screenshot()
                    let image = XCTAttachment(screenshot: screenshot)
                    image.name = name + "-FailedRender-" + action; image.lifetime = .keepAlways; add(image)
                    let state = XCTAttachment(string: "action=\(action); red=\(redInkPixels(in: screenshot.image, frame: pixelFrame)); count=\(count.value as? String ?? "missing"); label=\(canvas.label)")
                    state.name = name + "-FailedRender-" + action + "-NativeState"; state.lifetime = .keepAlways; add(state)
                    print("NativeInkRenderProbe action=\(action); red=\(redInkPixels(in: screenshot.image, frame: pixelFrame)); count=\(count.value as? String ?? "missing"); native=\(canvas.label.prefix(1800))")
                }
            }
            return false
        }
        let savedCount = count.value as? String
        recordState("StrokeSaved", expected: savedCount)
        guard tapTarget("inkUndo") else { return false }
        let undone = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            (Int(count.value as? String ?? "") ?? -1) == before
        }, object: count)
        XCTAssertEqual(XCTWaiter.wait(for: [undone], timeout: 5), .completed, "Undo edge tap must remove the actual stroke")
        recordState("Undo", expected: String(before))
        guard tapTarget("inkRedo") else { return false }
        let redone = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            count.value as? String == savedCount
        }, object: count)
        XCTAssertEqual(XCTWaiter.wait(for: [redone], timeout: 5), .completed, "Redo edge tap must restore the actual stroke")
        recordState("Redo", expected: savedCount)
        let frame = canvas.frame, page = app.textFields["pageNumber"].value as? String
        guard tapTarget("fitMargin") else { return false }
        XCTAssertEqual(canvas.frame, frame, "Fit must not move the native viewport")
        XCTAssertEqual(count.value as? String, savedCount)
        capturePaperStudio(name + "-FitSheet", in: app)
        recordState("FitSheet", expected: savedCount)
        if allowsWidthFit {
            let sheetViewport = canvas.label
            guard tapTarget("fitMarginWidth") else { return false }
            let refitted = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                canvas.label != sheetViewport
            }, object: canvas)
            XCTAssertEqual(XCTWaiter.wait(for: [refitted], timeout: 5), .completed,
                "Width-fit edge tap must change the native margin viewport diagnostics")
            XCTAssertEqual(canvas.frame, frame)
            XCTAssertEqual(count.value as? String, savedCount)
            recordState("FitWidth", expected: savedCount)
        }
        XCTAssertEqual(app.textFields["pageNumber"].value as? String, page)
        XCTAssertGreaterThan(canvas.frame.height, 44, "Ink targets must retain usable writing space")
        capturePaperStudio(name + "-IndividualInkTargets", in: app)
        return true
    }

    private func marginMountExpectation(in app: XCUIApplication,
                                        sample: @escaping (String) -> Void) -> XCTNSPredicateExpectation {
        let pollingStarted = ProcessInfo.processInfo.systemUptime
        return XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let started = ProcessInfo.processInfo.systemUptime
            do {
                // All three conditions come from one fresh native AX hierarchy.
                // Serial element queries can exhaust the deadline between reads.
                let root = try app.snapshot()
                let captured = ProcessInfo.processInfo.systemUptime
                var pending: [any XCUIElementSnapshot] = [root]
                var modeCount = 0, canvasCount = 0, textCount = 0, nodes = 0
                var handwriting = false
                while let node = pending.popLast() {
                    nodes += 1
                    if node.elementType == .segmentedControl && node.identifier == "marginMode" {
                        modeCount += 1
                        handwriting = node.value as? String == "handwriting"
                    }
                    if node.elementType == .scrollView && node.identifier == "marginInkCanvas" { canvasCount += 1 }
                    if node.elementType == .textView && node.identifier == "splitNotes" { textCount += 1 }
                    // Do not cap or exit early: a remaining text editor can
                    // occur after the mode and canvas in the same hierarchy.
                    pending.append(contentsOf: node.children)
                }
                sample("start=\(started - pollingStarted); captured=\(captured - pollingStarted); end=\(ProcessInfo.processInfo.systemUptime - pollingStarted); nodes=\(nodes); modes=\(modeCount); handwriting=\(handwriting); canvases=\(canvasCount); texts=\(textCount)")
                return modeCount == 1 && handwriting && canvasCount > 0 && textCount == 0
            } catch {
                sample("start=\(started - pollingStarted); end=\(ProcessInfo.processInfo.systemUptime - pollingStarted); snapshotError=\(error.localizedDescription)")
                return false
            }
        }, object: app)
    }

    func testMarginHandwritingMountsWithoutTextInteraction() {
        verifyMarginHandwritingMount(name: "Untouched", focusesText: false, typesText: false)
    }

    func testMarginHandwritingMountsAfterTextFocus() {
        verifyMarginHandwritingMount(name: "Focused", focusesText: true, typesText: false)
    }

    func testMarginHandwritingMountsAfterTextEditing() {
        verifyMarginHandwritingMount(name: "Edited", focusesText: true, typesText: true)
    }

    func testMarginHandwritingMountsAfterDocumentInkMode() {
        verifyMarginHandwritingMount(name: "DocumentInkMode", focusesText: false, typesText: false,
                                     usesDocumentInk: true)
    }

    func testMarginHandwritingMountsAfterDocumentFit() {
        verifyMarginHandwritingMount(name: "DocumentFit", focusesText: false, typesText: false,
                                     usesDocumentInk: true, fitsDocument: true)
    }

    private func verifyMarginHandwritingMount(name: String, focusesText: Bool, typesText: Bool,
                                              usesDocumentInk: Bool = false, fitsDocument: Bool = false) {
        XCUIDevice.shared.orientation = .portrait
        XCTContext.runActivity(named: name) { activity in
            let app = XCUIApplication()
            defer { app.terminate() }
            app.launchArguments = ["--test-review-entry", "--test-reset-entrance", "--test-reduce-motion", "--test-margin-viewport"]
            app.launch()
            let demo = app.buttons["welcomeDemonstration"]
            guard demo.waitForExistence(timeout: 15) else { XCTFail("Welcome must offer the real demonstration"); return }
            if !demo.isHittable { app.swipeUp() }
            demo.tap()
            if usesDocumentInk {
                let pen = app.buttons["inkTool"]
                guard pen.waitForExistence(timeout: 15), pen.isHittable else {
                    XCTFail("The real document pen must be available before splitting"); return
                }
                pen.tap()
                XCTAssertTrue(pen.isSelected, "The probe must really activate document ink before splitting")
                let pdf = app.otherElements["pdfCanvas"]
                let before = "frame=\(pdf.frame); label=\(pdf.label)"
                if fitsDocument {
                    let fit = app.buttons["fitMargin"]
                    guard fit.waitForExistence(timeout: 5), fit.isHittable else {
                        XCTFail("The actual document fit action must be available"); return
                    }
                    fit.tap()
                }
                // Both ink-mode probes take the same viewport observations;
                // the second probe adds only the real document fit action.
                let viewport = XCTAttachment(string: "fitRequested=\(fitsDocument)\nbefore=\(before)\nafter=frame=\(pdf.frame); label=\(pdf.label)")
                viewport.name = "MarginMount-" + name + "-DocumentViewport"
                viewport.lifetime = .keepAlways; activity.add(viewport)
            }
            revealWorkspaceTools(in: app)
            app.buttons["workspaceActions"].tap()
            let split = app.buttons["splitDocumentNotes"]
            guard split.waitForExistence(timeout: 15) else { XCTFail("Native document must expose split"); return }
            split.tap()
            let text = app.textViews["splitNotes"]
            guard text.waitForExistence(timeout: 5) else { XCTFail("Split must initially mount the text editor"); return }
            if focusesText { text.tap() }
            if typesText { text.typeText("Margin mounting probe") }
            let mode = app.segmentedControls["marginMode"]
            let handwriting = mode.buttons["خط اليد"]
            guard handwriting.waitForExistence(timeout: 5), handwriting.isHittable else {
                XCTFail("The handwriting segment must be usable before switching"); return
            }
            handwriting.tap()
            let canvas = app.scrollViews["marginInkCanvas"]
            var mountSamples: [String] = []
            let mounted = marginMountExpectation(in: app) { mountSamples.append($0) }
            let result = XCTWaiter.wait(for: [mounted], timeout: 5)
            // Capture the transition outcome before collecting expensive evidence.
            let selectedMode = mode.value as? String
            let canvasMounted = canvas.exists
            let textMounted = text.exists
            XCTAssertEqual(result, .completed, "Handwriting must mount without requiring earlier text editing")
            XCTAssertEqual(selectedMode, "handwriting", "The retained mode must be handwriting")
            XCTAssertTrue(canvasMounted, "The actual PencilKit canvas must be mounted")
            XCTAssertFalse(textMounted, "The text editor must be removed after switching")
            let evidence = XCTAttachment(string: "interaction=\(name); result=\(result.rawValue); mode=\(selectedMode ?? "missing"); canvas=\(canvasMounted); text=\(textMounted); trace=\(mode.label)\npolls=\(mountSamples.joined(separator: "\n"))")
            evidence.name = "MarginMount-" + name
            evidence.lifetime = .keepAlways
            activity.add(evidence)
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = evidence.name; screenshot.lifetime = .keepAlways; activity.add(screenshot)
        }
    }

    private func verifyIndividualInkTargets(accessibilityType: Bool, paletteTransitions: Int = 1,
                                            detailedDiagnostics: Bool = false) {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        defer {
            // Wait for restoration while the app is still running, including
            // early failures, so the next original case starts in portrait.
            XCUIDevice.shared.orientation = .portrait
            let portrait = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                app.frame.width < app.frame.height
            }, object: app)
            XCTAssertEqual(XCTWaiter.wait(for: [portrait], timeout: 5), .completed)
            app.terminate()
        }
        app.launchArguments = ["--test-review-entry", "--test-reset-entrance", "--test-reduce-motion", "--test-margin-viewport"]
            + (accessibilityType ? ["--test-accessibility-type"] : [])
            + (detailedDiagnostics ? ["--test-margin-details"] : [])
        app.launch()
        let demo = app.buttons["welcomeDemonstration"]
        guard demo.waitForExistence(timeout: 15) else { XCTFail("Welcome must offer the real demonstration"); return }
        if !demo.isHittable { app.swipeUp() }
        demo.tap()
        let pdf = app.otherElements["pdfCanvas"]
        guard pdf.waitForExistence(timeout: 15) else { XCTFail("Demonstration must open its native PDF"); return }
        let variant = accessibilityType ? "AccessibilityType" : "StandardType"
        app.buttons["inkTool"].tap()
        guard exerciseIndividualInkTargets(in: app, canvas: pdf, count: app.buttons["inkTool"],
            allowsWidthFit: false, name: variant + "-DocumentInk") else { return }
        openWorkspaceAction("splitDocumentNotes", in: app)
        let mode = app.segmentedControls["marginMode"]
        let handwriting = mode.buttons["خط اليد"]
        guard mode.waitForExistence(timeout: 5), handwriting.isHittable else {
            XCTFail("Margin must expose the real native handwriting segment"); return
        }
        XCTAssertGreaterThanOrEqual(handwriting.frame.width + targetFrameTolerance, 44)
        XCTAssertGreaterThanOrEqual(handwriting.frame.height + targetFrameTolerance, 44)
        let modeGeometry = XCTAttachment(string: "mode=\(mode.frame); handwriting=\(handwriting.frame); title=\(handwriting.label); value=\(mode.value as? String ?? "missing")")
        modeGeometry.name = variant + "-NativeMarginModeGeometry"; modeGeometry.lifetime = .keepAlways; add(modeGeometry)
        handwriting.tap()
        let margin = app.scrollViews["marginInkCanvas"]
        var mountSamples: [String] = []
        let switched = marginMountExpectation(in: app) { mountSamples.append($0) }
        let switchedResult = XCTWaiter.wait(for: [switched], timeout: 5)
        let polling = XCTAttachment(string: mountSamples.joined(separator: "\n"))
        polling.name = variant + "-NativeMarginPolling"; polling.lifetime = .keepAlways; add(polling)
        let state = "modeValue=\(mode.value as? String ?? "missing"); canvasExists=\(margin.exists); textExists=\(app.textViews["splitNotes"].exists); label=\(mode.label)"
        let renderTrace = XCTAttachment(string: state)
        renderTrace.name = variant + "-MarginRenderBoundaryTrace"; renderTrace.lifetime = .keepAlways; add(renderTrace)
        print("NativeMarginEvidence variant=\(variant); \(state)")
        guard switchedResult == .completed else {
            XCTFail("Selecting handwriting must update the retained model and replace the native text editor before rotation: " + app.debugDescription); return
        }
        XCTAssertFalse(app.textViews["splitNotes"].exists)
        XCUIDevice.shared.orientation = .landscapeLeft
        let landscape = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in app.frame.width > app.frame.height }, object: app)
        XCTAssertEqual(XCTWaiter.wait(for: [landscape], timeout: 5), .completed)
        guard margin.waitForExistence(timeout: 5) else { XCTFail("Split must retain its native margin canvas"); return }
        revealWorkspaceTools(in: app)
        XCTAssertTrue(pdf.exists, "Compact split must retain the PDF beside handwriting")
        let pdfFrame = pdf.frame
        XCTAssertEqual(mode.value as? String, "handwriting", "Rotation must retain the real model mode")
        XCTAssertFalse(app.textViews["splitNotes"].exists)
        guard exerciseIndividualInkTargets(in: app, canvas: margin, count: margin,
            allowsWidthFit: true, name: variant + "-CompactSplitInk", paletteTransitions: paletteTransitions) else { return }
        XCTAssertTrue(pdf.exists)
        XCTAssertEqual(pdf.frame, pdfFrame, "Ink toolbar taps must preserve the split PDF viewport")
        XCTAssertGreaterThan(margin.frame.height, 44)
        // All original ink/pixel/Undo/Redo/Fit assertions have already finished.
        // Retain the same scalar receipt on success; failures retain it above.
        let commits = XCTAttachment(string: mode.label)
        commits.name = variant + "-CompletedNativeCommitPhases"; commits.lifetime = .keepAlways; add(commits)
    }

    func testIndividualInkTargetsInDocumentAndCompactSplit() {
        executionTimeAllowance = 360
        verifyIndividualInkTargets(accessibilityType: false)
    }

    func testIndividualInkTargetsAtAccessibilityTextSize() {
        executionTimeAllowance = 360
        verifyIndividualInkTargets(accessibilityType: true)
    }

    func testNotesPencilRemainsVisibleAfterRepeatedNativePaletteDismissals() {
        executionTimeAllowance = 360
        verifyIndividualInkTargets(accessibilityType: true, paletteTransitions: 3, detailedDiagnostics: true)
    }

    func testWorkspaceNavigationKeepsBackEdgeAndRepeatedOpening() {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        addTeardownBlock { app.terminate(); XCUIDevice.shared.orientation = .portrait }
        app.launchArguments = ["--test-review-entry", "--test-reset-entrance", "--test-reduce-motion", "--test-margin-viewport"]
        app.launch()
        let demo = app.buttons["welcomeDemonstration"]
        guard demo.waitForExistence(timeout: 15), demo.isHittable else {
            XCTFail("The real demonstration must be reachable"); return
        }
        demo.tap()
        let pdf = app.otherElements["pdfCanvas"]
        guard pdf.waitForExistence(timeout: 15) else { XCTFail("Demo must open its native PDF"); return }
        let back = app.navigationBars.buttons.element(boundBy: 0)
        guard back.waitForExistence(timeout: 5), back.isHittable else {
            XCTFail("Native Back must remain available in the document workspace"); return
        }
        back.tap()
        XCTAssertTrue(app.buttons["createNotebook"].waitForExistence(timeout: 10), "Back must return to the real library")
        visibleLibraryDocument("ابدأ هنا — دليل طَيّة", in: app).tap()
        guard pdf.waitForExistence(timeout: 15) else { XCTFail("The same document must reopen"); return }
        let pen = app.buttons["inkTool"]
        guard pen.waitForExistence(timeout: 5), pen.isHittable else {
            XCTFail("Reopened document must expose its native ink action"); return
        }
        pen.tap()
        XCTAssertTrue(pen.isSelected, "Check edge navigation while document handwriting is active")
        let frame = app.frame
        XCTAssertLessThan(frame.width, frame.height, "Use the real portrait RTL leading edge")
        let leadingEdge = app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: frame.width - 1, dy: frame.height * 0.5))
        leadingEdge.press(forDuration: 0.05,
            thenDragTo: leadingEdge.withOffset(CGVector(dx: -frame.width * 0.85, dy: 0)))
        XCTAssertTrue(app.buttons["createNotebook"].waitForExistence(timeout: 10), "Native leading-edge Back must remain usable")
        visibleLibraryDocument("ابدأ هنا — دليل طَيّة", in: app).tap()
        XCTAssertTrue(pdf.waitForExistence(timeout: 15), "The workspace must reopen after edge navigation")
        XCTAssertTrue(app.buttons["inkTool"].isHittable, "Reopening must retain usable document tools")
    }

}
