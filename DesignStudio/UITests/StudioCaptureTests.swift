import XCTest
import UIKit

final class StudioCaptureTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testCapturePrimaryScenesLight() { captureScenes(dark: false) }
    func testCapturePrimaryScenesDark() { captureScenes(dark: true) }

    func testEnglishAndAccessibilityLayouts() {
        for scene in ["library", "document"] {
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
        app.buttons["openPageAudio"].tap()
        XCTAssertTrue(app.buttons["manualMarker"].waitForExistence(timeout: 8))
        app.buttons["manualMarker"].tap()
        app.buttons["audioStop"].tap()
        snapshot("Audio-SavedPlaybackAndMarkers")
        let marker = app.buttons.matching(identifier: "marker-8-0").firstMatch
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
