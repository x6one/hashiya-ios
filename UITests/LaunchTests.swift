import XCTest
import UIKit

final class LaunchTests: XCTestCase {
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
        app.buttons["splitDocumentNotes"].tap()
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
        let groups = app.segmentedControls["workspaceToolGroups"]
        XCTAssertTrue(groups.waitForExistence(timeout: 10)); groups.buttons["صفحات"].tap()
        app.buttons["addWritingPaper"].tap(); app.buttons["نقاط"].tap()
        XCTAssertEqual(app.textFields["pageNumber"].value as? String, "2")
        app.buttons["deleteDocumentPage"].tap()
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
                && app.buttons["undoDocumentPageDeletion"].isEnabled
        }, object: app)
        XCTAssertEqual(XCTWaiter.wait(for: [removed], timeout: 5), .completed)
        XCTAssertEqual(app.textFields["pageNumber"].value as? String, "1")
        XCTAssertTrue(app.buttons["undoDocumentPageDeletion"].isEnabled)
        app.buttons["undoDocumentPageDeletion"].tap()
        XCTAssertTrue(app.buttons["nextDocumentPage"].isEnabled)
        groups.buttons["كتابة"].tap(); app.buttons["openMargin"].tap()
        app.buttons["addMarginPage"].tap()
        app.segmentedControls["marginMode"].buttons["نص"].tap()
        let text = app.textViews["splitNotes"]; text.tap(); text.typeText("Recover this page")
        // Dismiss the keyboard through a real mode change before using the footer.
        app.segmentedControls["marginMode"].buttons["خط اليد"].tap()
        app.buttons["deleteMarginPage"].tap(); app.sheets.buttons["حذف صفحة الحاشية"].tap()
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
        app.buttons["splitDocumentNotes"].tap()
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
            if stage == "split" { app.buttons["splitDocumentNotes"].tap() }
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
        app.buttons["إنشاء"].tap(); visibleLibraryDocument(name, in: app).tap()
        app.buttons["splitDocumentNotes"].tap()
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
        visibleLibraryDocument(name, in: app).tap(); app.buttons["splitDocumentNotes"].tap()
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
        app.segmentedControls["workspaceToolGroups"].buttons["دراسة"].tap()
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
        app.segmentedControls["workspaceToolGroups"].buttons["كتابة"].tap()
        app.buttons["splitDocumentNotes"].tap()
        let pages = app.buttons["marginPages"]
        XCTAssertTrue(pages.waitForExistence(timeout: 5))
        app.segmentedControls["workspaceToolGroups"].buttons["دراسة"].tap()
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
        app.buttons["splitDocumentNotes"].tap()
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
        app.buttons["splitDocumentNotes"].tap()
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
        let portrait = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in app.frame.height > app.frame.width }, object: app)
        XCTAssertEqual(XCTWaiter.wait(for: [portrait], timeout: 5), .completed)
        app.buttons["expandMargin"].tap()
        XCTAssertTrue(app.buttons["addMarginPage"].isHittable); XCTAssertEqual(canvas.value as? String, count)
        assertMarginInkVisible(canvas, in: app, stage: "full-screen")
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "PagedHandwritingFullScreen"; shot.lifetime = .keepAlways; add(shot)
        app.buttons["expandMargin"].tap()
        app.buttons["openMargin"].tap()
        XCTAssertEqual(canvas.value as? String, count, "The Notes menu must reuse the same drawing")
        app.buttons["expandMargin"].tap()
        app.segmentedControls["workspaceToolGroups"].buttons["صفحات"].tap(); app.buttons["addWritingPaper"].tap(); app.buttons["نقاط"].tap()
        XCTAssertEqual(app.textFields["pageNumber"].value as? String, "2")
        XCTAssertEqual(app.buttons["marginPages"].value as? String, "1/2", "Document navigation must not turn the notes page")
        app.buttons["previousDocumentPage"].tap(); XCTAssertEqual(app.textFields["pageNumber"].value as? String, "1")
        let split = XCTAttachment(screenshot: app.screenshot()); split.name = "PagedMarginsSplit"; split.lifetime = .keepAlways; add(split)
        app.terminate(); app.launch()
        let reopened = visibleLibraryDocument(name, in: app); XCTAssertTrue(reopened.waitForExistence(timeout: 10)); reopened.tap()
        app.buttons["splitDocumentNotes"].tap()
        XCTAssertEqual(app.buttons["marginPages"].value as? String, "1/2")
        XCTAssertEqual(app.textViews["splitNotes"].value as? String, firstText)
        app.segmentedControls["marginMode"].buttons["خط اليد"].tap(); XCTAssertEqual(canvas.value as? String, count)
        app.buttons["fitMargin"].tap()
        assertMarginInkVisible(canvas, in: app, stage: "relaunch")
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
            XCTAssertFalse(document.exists, "Only a deliberately expanded margin may hide the PDF")
        }
        let stripFrame = strip.frame, documentFrame = requiresDocument ? document.frame : nil
        let marginFrame = margin?.frame
        let marginPosition = app.buttons["marginPages"].value as? String
        let initialSeconds = recordingSeconds(elapsed) ?? 0
        record.tap()
        let permission = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch
        if permission.waitForExistence(timeout: 2) {
            let allow = permission.buttons["Allow"], ok = permission.buttons["OK"]
            if allow.exists { allow.tap() } else if ok.exists { ok.tap() }
        }
        let started = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "جارٍ التسجيل"), object: record)
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
        app.buttons["splitDocumentNotes"].tap()
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

    func testPaperStudioAccessibilityReduceMotionVisualCaptureJourney() {
        defer { XCUIDevice.shared.orientation = .portrait }
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        defer { app.terminate() }
        app.launchArguments = ["--test-review-entry", "--test-reset-entrance", "--test-appearance-light", "--test-accessibility-type", "--test-reduce-motion"]
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
        app.buttons["openMargin"].tap()
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
        let content = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", marker)).firstMatch
        XCTAssertTrue(content.waitForExistence(timeout: 10), "Imported PDF text must appear in a real search result")
        content.tap()
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

    private func tapInkTarget(_ identifier: String, in app: XCUIApplication, writingSurface: XCUIElement) -> Bool {
        let toolbar = app.scrollViews["inkToolbar"].firstMatch
        let control = toolbar.descendants(matching: .any)[identifier].firstMatch
        guard toolbar.waitForExistence(timeout: 5), control.waitForExistence(timeout: 5) else {
            XCTFail("Missing individual ink control: " + identifier); return false
        }
        // The SwiftUI scroll AX frame can extend into the landscape safe area
        // (x=0 while the native margin begins at x=62). Use the writing surface's
        // horizontal native bounds before asking XCTest for an activation point.
        func visibleViewport() -> CGRect {
            let frame = toolbar.frame, surface = writingSurface.frame
            return frame.intersection(CGRect(x: surface.minX, y: frame.minY,
                width: surface.width, height: frame.height)).intersection(app.frame)
        }
        func containsTarget(_ viewport: CGRect) -> Bool {
            !viewport.isNull && !viewport.isEmpty
                && viewport.insetBy(dx: -targetFrameTolerance, dy: -targetFrameTolerance).contains(control.frame)
        }
        for _ in 0..<8 {
            let viewport = visibleViewport(), target = control.frame
            guard !viewport.isNull, viewport.width >= 44 else {
                XCTFail("Ink toolbar must expose a native viewport: " + identifier); return false
            }
            if containsTarget(viewport) { break }
            let distance = target.minX < viewport.minX
                ? viewport.minX - target.minX + 12 : viewport.maxX - target.maxX - 12
            // Small, measured drags avoid oscillating past a partially visible
            // target when the compact toolbar is narrower than its contents.
            let delta = max(-viewport.width * 0.4, min(viewport.width * 0.4, distance))
            let applicationFrame = app.frame
            let start = app.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: viewport.midX - applicationFrame.minX,
                    dy: viewport.midY - applicationFrame.minY))
            start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: delta, dy: 0)))
            let moved = control.frame.minX - target.minX
            guard abs(moved) > 1, moved * delta > 0 else {
                XCTFail("Ink toolbar drag must actually scroll " + identifier
                    + "; before=\(target), after=\(control.frame), viewport=\(viewport)"); return false
            }
        }
        guard containsTarget(visibleViewport()), control.isHittable else {
            XCTFail("Cannot scroll the complete ink target into view: " + identifier); return false
        }
        XCTAssertGreaterThanOrEqual(control.frame.width + targetFrameTolerance, 44, identifier)
        XCTAssertGreaterThanOrEqual(control.frame.height + targetFrameTolerance, 44, identifier)
        let geometry = XCTAttachment(string: "target=\(control.frame); native viewport=\(visibleViewport())")
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
                                             count: XCUIElement, allowsWidthFit: Bool, name: String) -> Bool {
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
        guard picker.waitForExistence(timeout: 5), picker.segmentedControls.firstMatch.waitForExistence(timeout: 5) else {
            XCTFail("Color target must present the native color picker: " + app.debugDescription); return false
        }
        let close = app.buttons["closeInkColorPicker"].firstMatch
        guard close.waitForExistence(timeout: 5), close.isHittable else {
            XCTFail("Native color picker must expose its close action: " + app.debugDescription); return false
        }
        XCTAssertGreaterThanOrEqual(close.frame.width + targetFrameTolerance, 44)
        XCTAssertGreaterThanOrEqual(close.frame.height + targetFrameTolerance, 44)
        let swatch = picker.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "red 77")).firstMatch
        guard swatch.waitForExistence(timeout: 5), swatch.isHittable else {
            XCTFail("Actual native Grid must expose a hittable red swatch: " + app.debugDescription); return false
        }
        swatch.tap()
        capturePaperStudio(name + "-NativeColorPicker", in: app)
        close.tap()
        let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            !picker.exists && !close.exists
        }, object: picker)
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
        let strokeFrame = canvas.frame
        let beforeStroke = XCUIScreen.main.screenshot()
        let beforeRed = redInkPixels(in: beforeStroke.image,
            frame: strokeFrame.intersection(app.frame))
        let baseline = XCTAttachment(screenshot: beforeStroke)
        baseline.name = name + "-RedPixelBaseline"; baseline.lifetime = .keepAlways; add(baseline)
        let before = Int(count.value as? String ?? "") ?? 0
        recordState("BeforeStroke", expected: String(before))
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.35)).press(forDuration: 0.1,
            thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.65, dy: 0.5)))
        let saved = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            (Int(count.value as? String ?? "") ?? 0) > before
        }, object: count)
        XCTAssertEqual(XCTWaiter.wait(for: [saved], timeout: 10), .completed, "Targets must leave a usable native writing surface")
        let visibleRed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            self.redInkPixels(in: XCUIScreen.main.screenshot().image,
                frame: canvas.frame.intersection(app.frame)) - beforeRed > 40
        }, object: canvas)
        guard XCTWaiter.wait(for: [visibleRed], timeout: 5) == .completed else {
            let afterStroke = XCUIScreen.main.screenshot()
            let evidence = XCTAttachment(screenshot: afterStroke)
            evidence.name = name + "-RedPixelFailure"; evidence.lifetime = .keepAlways; add(evidence)
            let measured = redInkPixels(in: afterStroke.image, frame: canvas.frame.intersection(app.frame))
            let geometry = XCTAttachment(string: "beforeRed=\(beforeRed); afterRed=\(measured); delta=\(measured - beforeRed); beforeCount=\(before); afterCount=\(count.value as? String ?? "missing"); rgba=\(colorControl.value as? String ?? "missing"); beforeFrame=\(strokeFrame); afterFrame=\(canvas.frame); appFrame=\(app.frame); screenshotSize=\(afterStroke.image.size); screenshotScale=\(afterStroke.image.scale); screenshotOrientation=\(afterStroke.image.imageOrientation.rawValue); canvasLabel=\(canvas.label)")
            geometry.name = name + "-RedPixelFailureMeasurement"; geometry.lifetime = .keepAlways; add(geometry)
            recordState("StrokeNotVisible", expected: String(before))
            let elementEvidence = XCTAttachment(screenshot: canvas.screenshot())
            elementEvidence.name = name + "-RedPixelFailureElement"; elementEvidence.lifetime = .keepAlways; add(elementEvidence)
            XCTFail("Actual native writing surface must gain >40 red-dominant pixels after the stroke"); return false
        }
        XCTAssertEqual(canvas.frame, strokeFrame, "Color stroke must preserve the measured writing surface")
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

    private func verifyIndividualInkTargets(accessibilityType: Bool) {
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
        app.buttons["splitDocumentNotes"].tap()
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
        let switched = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            mode.value as? String == "handwriting" && margin.exists && !app.textViews["splitNotes"].exists
        }, object: mode)
        let switchedResult = XCTWaiter.wait(for: [switched], timeout: 5)
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
        XCTAssertTrue(pdf.exists, "Compact split must retain the PDF beside handwriting")
        let pdfFrame = pdf.frame
        XCTAssertEqual(mode.value as? String, "handwriting", "Rotation must retain the real model mode")
        XCTAssertFalse(app.textViews["splitNotes"].exists)
        guard exerciseIndividualInkTargets(in: app, canvas: margin, count: margin,
            allowsWidthFit: true, name: variant + "-CompactSplitInk") else { return }
        XCTAssertTrue(pdf.exists)
        XCTAssertEqual(pdf.frame, pdfFrame, "Ink toolbar taps must preserve the split PDF viewport")
        XCTAssertGreaterThan(margin.frame.height, 44)
    }

    func testIndividualInkTargetsInDocumentAndCompactSplit() {
        verifyIndividualInkTargets(accessibilityType: false)
    }

    func testIndividualInkTargetsAtAccessibilityTextSize() {
        verifyIndividualInkTargets(accessibilityType: true)
    }

}
