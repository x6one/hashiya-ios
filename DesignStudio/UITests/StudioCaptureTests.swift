import XCTest
import UIKit

final class StudioCaptureTests: XCTestCase {
    func testApprovalExtremeTypeCoreToolsFitWithoutOverlappingLabels() {
        for extra in [["--extra-large-type"], ["--extra-large-type", "--english", "--dark"]] {
            let app = launch("document", extra: extra)
            var previous: CGRect?
            for id in ["pen", "text", "select", "margin", "pages"] {
                let button = app.buttons["tool-\(id)"]
                assertUsable(button)
                XCTAssertFalse(button.label.isEmpty, "Every core tool retains its full VoiceOver name")
                if let caption = button.staticTexts.allElementsBoundByIndex.first {
                    XCTAssertTrue(button.frame.insetBy(dx: -1, dy: -1).contains(caption.frame), "Visible tool words must fit inside their own touch target")
                }
                if let previous { XCTAssertFalse(previous.intersects(button.frame.insetBy(dx: 1, dy: 1)), "Core touch targets must not overlap") }
                previous = button.frame
            }
            snapshot("Approval-ExtremeType-\(extra.contains("--english") ? "English-Dark" : "Arabic-Light")-Portrait")
            app.terminate()
        }
    }

    override func setUpWithError() throws { continueAfterFailure = false }

    func testCapturePrimaryScenesLight() { captureScenes(dark: false) }
    func testCapturePrimaryScenesDark() { captureScenes(dark: true) }

    func testEnglishAndAccessibilityLayouts() {
        for scene in ["library", "document", "margin", "audio"] {
            let english = launch(scene, extra: ["--english"])
            snapshot("English-\(scene)")
            english.terminate()
            let large = launch(scene, extra: ["--large-type"])
            if scene == "document" {
                assertUsable(large.buttons["nextPage"])
                assertUsable(large.buttons["tool-margin"])
                XCTAssertFalse(large.buttons["nextPage"].frame.intersects(large.buttons["pageThumbnails"].frame))
            }
            snapshot("Accessibility-\(scene)")
            large.terminate()
        }
    }

    func testRecordingNavigationMarkersAndFocusStayIndependent() {
        let app = launch("document")
        let marginWasVisible = app.textViews["marginText"].exists
        app.buttons["recordAction"].tap()
        XCTAssertEqual(app.buttons["recordAction"].value as? String, "recording")
        XCTAssertEqual(app.textViews["marginText"].exists, marginWasVisible)
        app.buttons["nextPage"].tap()
        XCTAssertEqual(app.buttons["pageCount"].value as? String, "8")
        XCTAssertEqual(app.buttons["recordAction"].value as? String, "recording")
        let tablet = UIDevice.current.userInterfaceIdiom == .pad
        if tablet {
            app.buttons["inkTarget"].tap()
            XCTAssertEqual(app.buttons["inkTarget"].value as? String, "margin")
        }
        let canvas = app.descendants(matching: .any).matching(identifier: tablet ? "marginCanvas" : "documentCanvas").firstMatch
        XCTAssertTrue(canvas.waitForExistence(timeout: 5))
        let originalStrokes = Int(canvas.value as? String ?? "") ?? -1
        XCTAssertGreaterThanOrEqual(originalStrokes, 0)
        let start = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.42))
        let end = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.65, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: end)
        let committed = XCTNSPredicateExpectation(predicate: NSPredicate { element, _ in
            guard let canvas = element as? XCUIElement, let count = Int(canvas.value as? String ?? "") else { return false }
            return count > originalStrokes
        }, object: canvas)
        XCTAssertEqual(XCTWaiter.wait(for: [committed], timeout: 5), .completed, "The user drag must commit an actual PencilKit stroke before inspecting audio marks")
        if tablet { XCTAssertEqual(app.buttons["inkTarget"].value as? String, "margin") }
        app.buttons["openPageAudio"].tap()
        XCTAssertTrue(app.buttons["manualMarker"].waitForExistence(timeout: 8))
        app.buttons["manualMarker"].tap()
        app.buttons["audioStop"].tap()
        snapshot("Audio-SavedPlaybackAndMarkers")
        let writing = app.buttons.matching(identifier: "marker-writing-8-0").firstMatch
        if !writing.isHittable { app.swipeUp() }
        XCTAssertTrue(writing.waitForExistence(timeout: 5), "A real PencilKit stroke must create a recording mark")
        let marker = app.buttons.matching(identifier: "marker-manual-8-0").firstMatch
        if !marker.isHittable { app.swipeUp() }
        XCTAssertTrue(marker.waitForExistence(timeout: 5))
        marker.tap()
        XCTAssertEqual(app.buttons["pageCount"].value as? String, "8")
        app.buttons["focusToggle"].tap()
        XCTAssertEqual(app.buttons["focusToggle"].value as? String, "focused")
        XCTAssertFalse(app.buttons["nextPage"].exists)
        snapshot("Document-Focus")
        app.buttons["focusToggle"].tap()
        XCTAssertTrue(app.buttons["nextPage"].waitForExistence(timeout: 5))
        app.terminate()
    }

    func testPagePickerAndFlashcardReveal() {
        let app = launch("document")
        app.buttons["pageThumbnails"].tap()
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 5))
        snapshot("Document-PageThumbnails")
        app.terminate()
        let cards = launch("cards")
        cards.buttons["revealAnswer"].tap()
        XCTAssertTrue(cards.staticTexts["الأصول = الالتزامات + حقوق الملكية"].waitForExistence(timeout: 5))
        snapshot("Review-AnswerRevealed")
        cards.terminate()
    }

    func testNonzeroMarkerSeeksAndReturnsToItsPage() {
        let app = launch("audio")
        app.buttons["audioStop"].tap()
        let marker = app.buttons["marker-manual-8-138"]
        if !marker.isHittable { app.swipeUp() }
        XCTAssertTrue(marker.waitForExistence(timeout: 5))
        marker.tap()
        XCTAssertTrue(app.buttons["pageCount"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["pageCount"].value as? String, "8")
        app.buttons["openPageAudio"].tap()
        XCTAssertTrue(app.staticTexts["audioTime"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["audioTime"].label, "02:18")
        snapshot("Audio-MarkerSeek-02m18s-Page8")
        app.terminate()
    }

    func testUpdatedDocumentTextRendering() {
        // Only the sample PDF font changed. Re-capture that surface, retaining
        // prior successful library/margin/audio/card evidence without reruns.
        for extra in [[], ["--dark"], ["--english"], ["--large-type"]] as [[String]] {
            let app = launch("document", extra: extra)
            snapshot("UpdatedPDF-\(extra.first ?? "Light")-Portrait")
            if UIDevice.current.userInterfaceIdiom == .pad && extra.count < 1 {
                XCUIDevice.shared.orientation = .landscapeLeft
                snapshot("UpdatedPDF-Light-Landscape")
            }
            app.terminate()
        }
    }

    func testAccessibleEditorLabelsStayWhole() {
        let traits = UITraitCollection(preferredContentSizeCategory: .accessibilityLarge)
        for scene in ["document", "margin"] {
            let app = launch(scene, extra: ["--large-type"])
            let pages = app.buttons["tool-pages"]
            assertUsable(pages)
            let caption = pages.staticTexts.firstMatch
            XCTAssertTrue(caption.exists)
            XCTAssertLessThanOrEqual(caption.frame.height, UIFont.preferredFont(forTextStyle: .caption2, compatibleWith: traits).lineHeight + 3, "Tool words must remain on one line")
            let heading = app.descendants(matching: .any).matching(identifier: "marginHeading").firstMatch
            if scene == "margin" || UIDevice.current.userInterfaceIdiom == .pad {
                XCTAssertTrue(heading.exists)
                XCTAssertLessThanOrEqual(heading.frame.height, UIFont.preferredFont(forTextStyle: .headline, compatibleWith: traits).lineHeight + 3, "Margin title must remain on one line")
            }
            snapshot("Accessible-WholeLabels-\(scene)")
            app.terminate()
        }
    }

    func testPolishNotesDisplayCopy() {
        let app = launch("margin")
        let heading = app.descendants(matching: .any).matching(identifier: "marginHeading").firstMatch
        XCTAssertTrue(heading.label.contains("الملاحظات"), "Section display name must be Notes without changing its identifier")
        XCTAssertTrue(app.buttons["tool-margin"].label.contains("الملاحظات"))
        snapshot("Polish-Notes-Copy")
        app.terminate()
    }

    func testPolishContextToolsAndCompactAudio() {
        let app = launch("document")
        XCTAssertLessThanOrEqual(app.buttons["recordAction"].frame.height, 48)
        XCTAssertLessThanOrEqual(app.buttons["openPageAudio"].frame.height, 48, "Idle audio must reserve one compact row")
        app.buttons["tool-text"].tap()
        XCTAssertTrue(app.buttons["editText"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["inkColor"].exists)
        snapshot("Polish-Text-Context")
        app.buttons["tool-select"].tap()
        XCTAssertTrue(app.buttons["selectText"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["editText"].exists)
        app.buttons["tool-pen"].tap()
        XCTAssertTrue(app.buttons["inkColor"].waitForExistence(timeout: 5))
        snapshot("Polish-Pen-Context")
        app.terminate()
    }

    func testPolishAccessibleNotesHaveReadableWidth() {
        let app = launch("document", extra: ["--large-type"])
        if UIDevice.current.userInterfaceIdiom == .pad {
            let notes = app.textViews["marginText"]
            XCTAssertTrue(notes.waitForExistence(timeout: 5))
            XCTAssertGreaterThan(notes.frame.width, app.windows.firstMatch.frame.width * 0.6, "Accessibility Notes must expand beyond a narrow split")
            assertUsable(app.buttons["showDocument"])
            snapshot("Polish-Accessibility-ExpandedNotes")
            app.buttons["showDocument"].tap()
            XCTAssertEqual(app.buttons["pageCount"].value as? String, "7")
            XCTAssertFalse(app.textViews["marginText"].exists)
            assertUsable(app.buttons["showNotes"])
        } else {
            assertUsable(app.buttons["tool-margin"])
        }
        XCUIDevice.shared.orientation = .landscapeLeft
        snapshot("Polish-Accessibility-Landscape")
        app.terminate()
    }

    func testPolishPickerUsesRealPageThumbnails() {
        let app = launch("document")
        app.buttons["pageThumbnails"].tap()
        let preview = app.images["pagePreview-1"]
        XCTAssertTrue(preview.waitForExistence(timeout: 10), "A PDFKit-rendered page image must replace the placeholder symbol")
        XCTAssertEqual(preview.value as? String, "rendered")
        assertUsable(app.buttons["pickPage-1"])
        snapshot("Polish-Real-PageThumbnails")
        app.buttons["pickPage-1"].tap()
        XCTAssertEqual(app.buttons["pageCount"].value as? String, "1")
        app.terminate()
    }

    func testPolishLargeLibraryFiltersStayWhole() {
        let app = launch("library", extra: ["--large-type"])
        let filter = app.buttons["libraryFilter-0"]
        XCTAssertTrue(filter.waitForExistence(timeout: 5))
        assertUsable(filter)
        let label = filter.staticTexts.firstMatch
        let traits = UITraitCollection(preferredContentSizeCategory: .accessibilityLarge)
        XCTAssertLessThanOrEqual(label.frame.height, UIFont.preferredFont(forTextStyle: .caption1, compatibleWith: traits).lineHeight + 3)
        if UIDevice.current.userInterfaceIdiom == .phone {
            let tabs = (0..<4).map { app.buttons["studioTab-\($0)"] }
            for tab in tabs {
                assertUsable(tab)
                XCTAssertTrue(tab.frame.insetBy(dx: -1, dy: -1).contains(tab.staticTexts.firstMatch.frame), "Tab labels must stay inside their touch targets")
            }
            for index in 0..<tabs.count {
                for other in (index + 1)..<tabs.count {
                    XCTAssertFalse(tabs[index].frame.intersects(tabs[other].frame), "Large tab labels must not overlap adjacent targets")
                }
            }
        }
        snapshot("Polish-Accessibility-Library")
        app.terminate()
    }

    func testPolishDraftAndThreePenPresetsSurviveRelaunch() {
        let args = ["--draft-id", "polish-reopen", "--reset-draft"]
        let app = launch("margin", extra: args)
        let note = app.textViews["marginText"]
        note.tap()
        note.typeText(" محفوظ")
        app.buttons["dismissKeyboard"].tap()
        assertSaved(app)
        app.buttons["سماكة القلم"].tap()
        app.buttons["6 pt"].tap()
        app.buttons["favoritePens"].tap()
        XCTAssertTrue(app.buttons["savePen-1"].waitForExistence(timeout: 5))
        for index in 1...3 { assertUsable(app.buttons["savePen-\(index)"]) }
        app.buttons["savePen-1"].tap()
        assertSaved(app, inSheet: true)
        snapshot("Polish-Favorite-Pens")
        app.terminate()
        let reopened = launch("margin", extra: ["--draft-id", "polish-reopen"])
        XCTAssertTrue((reopened.textViews["marginText"].value as? String ?? "").contains("محفوظ"))
        reopened.buttons["favoritePens"].tap()
        XCTAssertEqual(reopened.buttons["usePen-1"].value as? String, "pen:#244C43:6")
        reopened.terminate()
    }

    func testPolishDirectPageJumpAndLastVisitedPage() {
        let app = launch("document")
        openPagePicker(app)
        let input = app.textFields["pageNumberInput"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        if UIDevice.current.userInterfaceIdiom == .pad {
            XCTAssertLessThan(app.navigationBars["الصفحات"].frame.minY, app.windows.firstMatch.frame.height * 0.1, "Tablet page picker uses a stable full-screen presentation")
        }
        input.tap()
        input.typeText("12")
        tapPageJump(app)
        let closed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: input)
        XCTAssertEqual(XCTWaiter.wait(for: [closed], timeout: 5), .completed, "Wait for the page sheet to dismiss before reading document accessibility values")
        XCTAssertEqual(app.buttons["pageCount"].value as? String, "12")
        openPagePicker(app)
        app.buttons["lastVisitedPage"].tap()
        XCTAssertEqual(app.buttons["pageCount"].value as? String, "7")
        app.terminate()
    }

    func testPolishMarkerKeepsClosedNotesClosed() {
        let app = launch("audio")
        app.buttons["audioStop"].tap()
        app.buttons["العودة للمستند"].tap()
        if UIDevice.current.userInterfaceIdiom == .pad { app.buttons["tool-margin"].tap() }
        XCTAssertFalse(app.textViews["marginText"].exists)
        app.buttons["openPageAudio"].tap()
        let marker = app.buttons["marker-manual-8-138"]
        if !marker.isHittable { app.swipeUp() }
        marker.tap()
        XCTAssertEqual(app.buttons["pageCount"].value as? String, "8")
        XCTAssertFalse(app.textViews["marginText"].exists, "Playback must preserve the user's closed Notes layout")
        app.buttons["openPageAudio"].tap()
        let active = app.buttons["marker-manual-8-138"]
        if !active.isHittable { app.swipeUp() }
        XCTAssertEqual(active.value as? String, "playing")
        snapshot("Polish-Audio-ActiveMarker")
        app.terminate()
    }

    func testCompactAccessibleDocumentUsesReversibleFocus() {
        for extra in [["--extra-large-type"], ["--extra-large-type", "--english", "--dark"]] {
            let app = launch("document", extra: extra)
            app.buttons["nextPage"].tap()
            XCTAssertEqual(app.buttons["pageCount"].value as? String, "8")
            XCUIDevice.shared.orientation = .landscapeLeft
            if UIDevice.current.userInterfaceIdiom == .phone {
                let pdf = app.descendants(matching: .any).matching(identifier: "nativeStudyPDF").firstMatch
                let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                    app.buttons["focusToggle"].value as? String == "focused"
                        && pdf.frame.height >= app.windows.firstMatch.frame.height * 0.5
                }, object: nil)
                XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed,
                               "Largest-type landscape needs readable PDF space; pdf=\(pdf.frame) window=\(app.windows.firstMatch.frame) focus=\(String(describing: app.buttons["focusToggle"].value))")
                assertUsable(app.buttons["focusToggle"])
                XCTAssertFalse(app.buttons["nextPage"].exists)
                snapshot("Polish-CompactAccessible-DocumentFocus-\(extra.contains("--english") ? "English-Dark" : "Arabic-Light")")
                app.buttons["focusToggle"].tap()
                XCTAssertTrue(app.buttons["nextPage"].waitForExistence(timeout: 5))
                XCTAssertEqual(app.buttons["pageCount"].value as? String, "8")
                XCUIDevice.shared.orientation = .portrait
                XCTAssertEqual(app.buttons["focusToggle"].value as? String, "standard")
                app.buttons["focusToggle"].tap()
                XCUIDevice.shared.orientation = .landscapeLeft
                XCTAssertEqual(app.buttons["focusToggle"].value as? String, "focused")
                XCUIDevice.shared.orientation = .portrait
                XCTAssertEqual(app.buttons["focusToggle"].value as? String, "focused", "An explicit focus choice survives rotation")
                app.buttons["focusToggle"].tap()
            } else {
                XCTAssertEqual(app.buttons["focusToggle"].value as? String, "standard", "The tablet keeps its regular-height workspace")
            }
            XCTAssertEqual(app.buttons["pageCount"].value as? String, "8")
            app.terminate()
        }
    }

    func testPolishExtremeTypeAndLandscapeCaptures() {
        for scene in ["document", "margin", "library"] {
            let app = launch(scene, extra: ["--extra-large-type"])
            snapshot("ExtremeType-\(scene)-Portrait")
            XCUIDevice.shared.orientation = .landscapeLeft
            snapshot("ExtremeType-\(scene)-Landscape")
            app.terminate()
        }
    }

    func testReviewTextTargetFollowsVisibleSurface() {
        let app = launch("document")
        if UIDevice.current.userInterfaceIdiom == .pad {
            app.buttons["inkTarget"].tap()
            app.buttons["tool-margin"].tap()
            XCTAssertFalse(app.textViews["marginText"].exists)
        }
        app.buttons["tool-text"].tap()
        app.buttons["editText"].tap()
        XCTAssertTrue(app.navigationBars["ملاحظة نصية"].waitForExistence(timeout: 5), "A closed Notes panel must never receive document text commands")
        app.terminate()
    }

    func testReviewExpandedNotesLayoutSurvivesMarkerReturn() {
        let app = launch("audio")
        app.buttons["audioStop"].tap()
        app.buttons["العودة للمستند"].tap()
        if UIDevice.current.userInterfaceIdiom == .pad {
            app.buttons["notesLayout"].tap()
            XCTAssertTrue(app.buttons["showDocument"].waitForExistence(timeout: 5))
            app.buttons["openPageAudio"].tap()
            let marker = app.buttons["marker-manual-8-138"]
            if !marker.isHittable { app.swipeUp() }
            marker.tap()
            XCTAssertTrue(app.buttons["showDocument"].waitForExistence(timeout: 5), "Audio navigation must retain expanded Notes presentation")
            XCTAssertTrue(app.textViews["marginText"].exists)
        }
        snapshot("Polish-Notes-ExpandedAfterMarker")
        app.terminate()
    }

    func testReviewAccessibleDocumentChoiceSurvivesMarkerReturn() {
        if UIDevice.current.userInterfaceIdiom == .pad {
            let app = launch("audio", extra: ["--large-type"])
            if !app.buttons["audioStop"].isHittable { app.swipeUp() }
            app.buttons["audioStop"].tap()
            app.buttons["العودة للمستند"].tap()
            app.buttons["showDocument"].tap()
            XCTAssertFalse(app.textViews["marginText"].exists)
            app.buttons["openPageAudio"].tap()
            let marker = app.buttons["marker-manual-8-138"]
            if !marker.isHittable { app.swipeUp() }
            marker.tap()
            XCTAssertTrue(app.buttons["showNotes"].waitForExistence(timeout: 5))
            XCTAssertFalse(app.textViews["marginText"].exists)
            XCTAssertEqual(app.buttons["pageCount"].value as? String, "8")
            snapshot("Polish-Accessibility-DocumentAfterMarker")
            app.terminate()
        } else {
            let app = launch("document", extra: ["--large-type"])
            XCTAssertFalse(app.textViews["marginText"].exists)
            assertUsable(app.buttons["tool-margin"])
            app.terminate()
        }
    }

    func testFinalPolishExpandedNotesAndFocusCaptures() {
        for extra in [[], ["--dark"]] as [[String]] {
            let app = launch("document", extra: extra)
            let theme = extra.isEmpty ? "Light" : "Dark"
            openPagePicker(app)
            let input = app.textFields["pageNumberInput"]
            XCTAssertTrue(input.waitForExistence(timeout: 5))
            input.tap(); input.typeText("12")
            tapPageJump(app)
            let closed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: input)
            XCTAssertEqual(XCTWaiter.wait(for: [closed], timeout: 5), .completed)
            app.buttons["focusToggle"].tap()
            XCTAssertFalse(app.buttons["nextPage"].exists)
            snapshot("Final-\(theme)-Focus-Portrait")
            XCUIDevice.shared.orientation = .landscapeLeft
            snapshot("Final-\(theme)-Focus-Landscape")
            app.buttons["focusToggle"].tap()
            XCTAssertEqual(app.buttons["pageCount"].value as? String, "12")
            if UIDevice.current.userInterfaceIdiom == .pad {
                app.buttons["notesLayout"].tap()
                XCTAssertTrue(app.buttons["showDocument"].waitForExistence(timeout: 5))
                snapshot("Final-\(theme)-ExpandedNotes-Landscape")
                app.buttons["showDocument"].tap()
                XCTAssertFalse(app.textViews["marginText"].exists)
                app.buttons["notesLayout"].tap()
                XCTAssertTrue(app.textViews["marginText"].exists)
                XCTAssertEqual(app.buttons["pageCount"].value as? String, "12")
                snapshot("Final-\(theme)-RestoredSplit-Landscape")
            } else {
                app.buttons["tool-margin"].tap()
                XCTAssertTrue(app.textViews["marginText"].waitForExistence(timeout: 5))
                snapshot("Final-\(theme)-StandaloneNotes-Landscape")
                app.buttons["tool-margin"].tap()
                XCTAssertEqual(app.buttons["pageCount"].value as? String, "12")
            }
            app.terminate()
        }
    }

    private func captureScenes(dark: Bool) {
        for scene in ["library", "document", "margin", "audio", "cards"] {
            let app = launch(scene, extra: dark ? ["--dark"] : [])
            if scene == "library" { assertUsable(app.buttons["libraryAdd"]) }
            if scene == "document" {
                assertUsable(app.buttons["nextPage"])
                assertUsable(app.buttons["focusToggle"])
            }
            snapshot("\(dark ? "Dark" : "Light")-\(scene)-Portrait")
            if ["document", "margin", "library", "audio"].contains(scene) {
                XCUIDevice.shared.orientation = .landscapeLeft
                snapshot("\(dark ? "Dark" : "Light")-\(scene)-Landscape")
            }
            app.terminate()
        }
    }

    private func launch(_ scene: String, extra: [String] = []) -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--scene", scene, "--capture"] + (extra.contains("--dark") ? [] : ["--light"]) + extra
        app.launch()
        let ready = ["library": "libraryAdd", "document": "focusToggle", "margin": "focusToggle", "audio": "audioStop", "cards": "revealAnswer"][scene] ?? "focusToggle"
        XCTAssertTrue(app.buttons[ready].waitForExistence(timeout: 12), "Ready control for \(scene)")
        return app
    }

    private func openPagePicker(_ app: XCUIApplication) {
        let button = app.buttons["pageCount"]
        assertUsable(button)
        print("StudioPageHit counter=\(button.frame)")
        button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    private func tapPageJump(_ app: XCUIApplication) {
        let button = app.buttons["jumpToPage"]
        assertUsable(button)
        let field = app.textFields["pageNumberInput"]
        XCTAssertEqual(field.value as? String, "12")
        let frame = button.frame
        XCTAssertEqual(frame.midY, field.frame.midY, accuracy: 2, "Go must align with the currently displayed input row")
        print("StudioPageHit button=\(frame) field=\(field.frame)")
        // iPad's cached AX activation point can precede the sheet's keyboard relayout.
        // Tap the actual current button center, preserving a real touch and all navigation assertions.
        button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    private func assertSaved(_ app: XCUIApplication, inSheet: Bool = false) {
        let saved = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "saved"), object: app.staticTexts[inSheet ? "sheetSaveStatus" : "saveStatus"])
        XCTAssertEqual(XCTWaiter.wait(for: [saved], timeout: 5), .completed, "Wait for actual atomic preview save completion")
    }

    private func assertUsable(_ button: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(button.isHittable, file: file, line: line)
        XCTAssertGreaterThanOrEqual(button.frame.width, 44, file: file, line: line)
        XCTAssertGreaterThanOrEqual(button.frame.height, 44, file: file, line: line)
        let window = XCUIApplication().windows.firstMatch.frame.insetBy(dx: -1, dy: -1)
        XCTAssertTrue(window.contains(button.frame), "Control must remain within the viewport", file: file, line: line)
    }

    private func snapshot(_ name: String) {
        let app = XCUIApplication()
        let landscape = XCUIDevice.shared.orientation.isLandscape
        let oriented = NSPredicate { _, _ in
            let frame = app.windows.firstMatch.frame
            return landscape ? frame.width > frame.height : frame.height > frame.width
        }
        if !oriented.evaluate(with: nil) {
            let ready = XCTNSPredicateExpectation(predicate: oriented, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed, "Capture waits for actual window orientation")
        }
        // Capture the full display: app.screenshot() can apply landscape crop coordinates
        // before the display's EXIF orientation, leaving clipped content and black pixels.
        let screenshot = XCUIScreen.main.screenshot()
        let image = screenshot.image
        guard let pixels = image.cgImage else { XCTFail("Native screenshot must contain pixels"); return }
        let swapped = [UIImage.Orientation.left, .right, .leftMirrored, .rightMirrored].contains(image.imageOrientation)
        let width = CGFloat(swapped ? pixels.height : pixels.width)
        let height = CGFloat(swapped ? pixels.width : pixels.height)
        let window = app.windows.firstMatch.frame
        print("StudioCapture \(name) raw=\(pixels.width)x\(pixels.height) orientation=\(image.imageOrientation.rawValue) window=\(window)")
        XCTAssertEqual(width / height, window.width / window.height, accuracy: 0.02, "Native screenshot orientation and extent must match the ready window")
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Studio-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
