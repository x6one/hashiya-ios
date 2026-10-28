import XCTest

/// Production AVFoundation recordings on the simulator, never Studio mock audio.
/// These checks do not establish capture from a physical device microphone.
final class StudioAudioUITests: XCTestCase {
    override func setUp() { super.setUp(); continueAfterFailure = false }

    private func openDocument() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--test-review-entry"]
        app.launch()
        openProductionDemonstration(in: app)
        XCTAssertTrue(app.buttons["recordLinkedAudio"].waitForExistence(timeout: 15))
        return app
    }

    private func startRecording(_ app: XCUIApplication) {
        startProductionRecording(in: app)
    }

    private func seconds(_ app: XCUIApplication) -> Int {
        let value = app.staticTexts["recordingElapsed"].value as? String ?? ""
        return value.split(separator: ":").compactMap { Int($0) }.reduce(0) { $0 * 60 + $1 }
    }

    func testContinuousRecordingKeepsOneClipAndLinksBothVisitedPages() {
        let app = openDocument()
        startRecording(app)
        app.buttons["nextDocumentPage"].tap()
        XCTAssertEqual(app.textFields["pageNumber"].value as? String, "2")
        XCTAssertEqual(app.buttons["recordLinkedAudio"].value as? String, "جارٍ التسجيل")
        XCTAssertFalse(app.buttons["marginPages"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["splitDivider"].firstMatch.exists)
        let visitedAt = seconds(app)
        let usableClip = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in self.seconds(app) >= visitedAt + 5 }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [usableClip], timeout: 10), .completed,
                      "Use real recorder time so marker playback has audible-duration media remaining")
        app.buttons["recordLinkedAudio"].tap()
        app.buttons["recordingDetails"].tap()
        XCTAssertTrue(app.buttons["playLinkedRecording"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons.matching(identifier: "playLinkedRecording").count, 1,
                       "Changing page must keep one M4A recording")
        let first = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "audioMarker-", "صفحة 1")).firstMatch
        let second = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "audioMarker-", "صفحة 2")).firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 5), "Recording start must persist the original page")
        XCTAssertTrue(second.exists, "The same recording must gain a new-page timestamp")
        second.tap()
        XCTAssertTrue(app.textFields["pageNumber"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["pageNumber"].value as? String, "2")
        XCTAssertTrue(app.buttons["pauseLinkedRecording"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["marginPages"].exists)
    }

    func testRealRecordingExposesManualMarkersAndPlaybackManagement() {
        let app = openDocument()
        startRecording(app)
        app.buttons["recordingDetails"].tap()
        let manual = app.buttons["addAudioMarker"]
        XCTAssertTrue(manual.waitForExistence(timeout: 5), "Recording details must expose a working manual marker")
        manual.tap()
        XCTAssertTrue(app.buttons["stopLinkedRecording"].isHittable)
        app.buttons["stopLinkedRecording"].tap()
        let rename = app.buttons["renameLinkedRecording"].firstMatch
        XCTAssertTrue(rename.waitForExistence(timeout: 5))
        rename.tap()
        let title = app.textFields["recordingTitle"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap(); title.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 100) + "Study audio")
        app.buttons["saveRecordingTitle"].tap()
        XCTAssertTrue(app.staticTexts["Study audio"].waitForExistence(timeout: 5))
        app.buttons["playLinkedRecording"].firstMatch.tap()
        XCTAssertTrue(app.buttons["playbackRate"].exists)
        XCTAssertTrue(app.buttons["rewindLinkedRecording"].exists)
        XCTAssertTrue(app.buttons["forwardLinkedRecording"].exists)
        XCTAssertTrue(app.buttons["shareLinkedRecording"].firstMatch.exists)
    }

    func testBackgroundSavesRealRecordingAndReturningKeepsItPlayable() {
        let app = openDocument()
        startRecording(app)
        let recorded = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in self.seconds(app) >= 2 }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [recorded], timeout: 5), .completed)
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(app.buttons["recordLinkedAudio"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons["recordLinkedAudio"].value as? String, "متوقف")
        app.buttons["recordingDetails"].tap()
        let duration = app.staticTexts["linkedRecordingDuration"].firstMatch
        XCTAssertTrue(duration.waitForExistence(timeout: 5))
        let seconds = duration.label.split(separator: ":").compactMap { Int($0) }.reduce(0) { $0 * 60 + $1 }
        XCTAssertGreaterThanOrEqual(seconds, 2, "Background stop must retain the real encoded M4A duration")
        app.buttons["playLinkedRecording"].firstMatch.tap()
        XCTAssertTrue(app.buttons["pauseLinkedRecording"].waitForExistence(timeout: 5), "The saved real media must remain decodable after returning")
    }
}
