import XCTest
import UIKit

final class StudioCaptureTests: XCTestCase {
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
        let start = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.42))
        let end = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.65, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: end)
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

    private func captureScenes(dark: Bool) {
        for scene in ["library", "document", "margin", "audio", "cards"] {
            let app = launch(scene, extra: dark ? ["--dark"] : [])
            if scene == "library" { assertUsable(app.buttons["libraryAdd"]) }
            if scene == "document" {
                assertUsable(app.buttons["nextPage"])
                assertUsable(app.buttons["focusToggle"])
            }
            snapshot("\(dark ? "Dark" : "Light")-\(scene)-Portrait")
            if UIDevice.current.userInterfaceIdiom == .pad && (scene == "document" || scene == "library") {
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

    private func assertUsable(_ button: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(button.isHittable, file: file, line: line)
        XCTAssertGreaterThanOrEqual(button.frame.width, 44, file: file, line: line)
        XCTAssertGreaterThanOrEqual(button.frame.height, 44, file: file, line: line)
        let window = XCUIApplication().windows.firstMatch.frame.insetBy(dx: -1, dy: -1)
        XCTAssertTrue(window.contains(button.frame), "Control must remain within the viewport", file: file, line: line)
    }

    private func snapshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "Studio-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
