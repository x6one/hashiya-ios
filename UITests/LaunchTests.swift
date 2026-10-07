import XCTest

final class LaunchTests: XCTestCase {
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
        guard XCTWaiter.wait(for: [saved], timeout: 25) == .completed else {
            XCTFail("Files export did not complete: " + app.debugDescription); return false
        }
        app.terminate()
        return true
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
        let document = app.staticTexts[title].firstMatch
        // Imports add real cards. LazyVGrid instantiates visible rows only;
        // reach the document through the same scrolling a user performs.
        for _ in 0..<6 {
            if document.exists && document.isHittable { return document }
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
        let pickerShot = XCTAttachment(screenshot: app.screenshot())
        pickerShot.name = "NativeFilePicker"
        pickerShot.lifetime = .keepAlways
        add(pickerShot)
        XCTAssertTrue(file.isEnabled, "Files must permit this document type")
        // The provider is a remote UI process. Use its observed thumbnail frame
        // in screen coordinates instead of its synthesized accessibility hit
        // point. The tap still goes through the real Files picker and callback.
        let thumbnail = file.images.firstMatch
        let frame = thumbnail.exists ? thumbnail.frame : file.frame
        let target = XCTAttachment(string: "File frame: \(file.frame); tap frame: \(frame)")
        target.name = "FilesTapGeometry"; target.lifetime = .keepAlways; add(target)
        app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: frame.midX, dy: frame.midY)).tap()
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
        let card = app.staticTexts[name].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        card.tap()
        XCTAssertTrue(app.buttons[editor].waitForExistence(timeout: 10))
    }

    func testCreateNotebookFromLibrary() {
        let app = XCUIApplication()
        app.launch()
        let create = app.buttons["createNotebook"]
        XCTAssertTrue(create.waitForExistence(timeout: 15))
        create.tap()
        app.buttons["إنشاء"].tap()
        XCTAssertTrue(app.staticTexts["دفتر جديد"].firstMatch.waitForExistence(timeout: 10))
    }

    func testLibraryLaunchAndDocumentOpen() {
        let app = XCUIApplication()
        app.launch()
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isHittable == true"), object: app.buttons["librarySections"])
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 15), .completed)
        let opening = app.otherElements["openingAnimation"]
        _ = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: opening)], timeout: 5)
        XCTAssertTrue(app.navigationBars["طَيّة"].waitForExistence(timeout: 15))
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
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4)).tap()
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
        app.buttons["documentTools"].tap()
        app.buttons["المستند والحاشية معًا"].tap()
        XCTAssertTrue(app.textViews["splitNotes"].waitForExistence(timeout: 5))
        let split = XCTAttachment(screenshot: app.screenshot()); split.name = "AdaptiveSplitNotes"; split.lifetime = .keepAlways; add(split)
    }
    func testPagedMarginsKeepInkTextAndNavigationAfterResizeRotationAndRelaunch() {
        let app = XCUIApplication(); app.launch()
        XCTAssertTrue(app.buttons["createNotebook"].waitForExistence(timeout: 15)); app.buttons["createNotebook"].tap()
        let name = "دفتر جديد"
        app.buttons["إنشاء"].tap()
        let note = visibleLibraryDocument(name, in: app); XCTAssertTrue(note.waitForExistence(timeout: 10)); note.tap()
        app.buttons["documentTools"].tap(); app.buttons["المستند والحاشية معًا"].tap()
        let text = app.textViews["splitNotes"]; XCTAssertTrue(text.waitForExistence(timeout: 5)); text.tap()
        let firstText = "First margin page - keep this text."
        text.typeText(firstText)
        app.segmentedControls["marginMode"].buttons["خط اليد"].tap()
        let canvas = app.otherElements["marginInkCanvas"]
        XCTAssertTrue(canvas.waitForExistence(timeout: 5))
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.2)).press(forDuration: 0.1,
            thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: 0.85)))
        let saved = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in (Int(canvas.value as? String ?? "") ?? 0) > 0 }, object: canvas)
        XCTAssertEqual(XCTWaiter.wait(for: [saved], timeout: 10), .completed)
        let count = canvas.value as? String
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
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.buttons["addMarginPage"].waitForExistence(timeout: 5)); XCTAssertTrue(app.buttons["addMarginPage"].isHittable)
        XCTAssertEqual(canvas.value as? String, count)
        XCUIDevice.shared.orientation = .portrait
        app.buttons["expandMargin"].tap()
        XCTAssertTrue(app.buttons["addMarginPage"].isHittable); XCTAssertEqual(canvas.value as? String, count)
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "PagedHandwritingFullScreen"; shot.lifetime = .keepAlways; add(shot)
        app.buttons["expandMargin"].tap()
        app.buttons["documentTools"].tap(); app.buttons["إضافة ورقة للكتابة"].tap(); app.buttons["نقاط"].tap()
        XCTAssertEqual(app.textFields["pageNumber"].value as? String, "2")
        XCTAssertEqual(app.buttons["marginPages"].value as? String, "1/2", "Document navigation must not turn the notes page")
        app.buttons["previousDocumentPage"].tap(); XCTAssertEqual(app.textFields["pageNumber"].value as? String, "1")
        let split = XCTAttachment(screenshot: app.screenshot()); split.name = "PagedMarginsSplit"; split.lifetime = .keepAlways; add(split)
        app.terminate(); app.launch()
        let reopened = visibleLibraryDocument(name, in: app); XCTAssertTrue(reopened.waitForExistence(timeout: 10)); reopened.tap()
        app.buttons["documentTools"].tap(); app.buttons["المستند والحاشية معًا"].tap()
        XCTAssertEqual(app.buttons["marginPages"].value as? String, "1/2")
        XCTAssertEqual(app.textViews["splitNotes"].value as? String, firstText)
        app.segmentedControls["marginMode"].buttons["خط اليد"].tap(); XCTAssertEqual(app.otherElements["marginInkCanvas"].value as? String, count)
        app.buttons["nextMarginPage"].tap(); app.segmentedControls["marginMode"].buttons["نص"].tap()
        XCTAssertEqual(app.textViews["splitNotes"].value as? String, "Second margin page")
    }

}
