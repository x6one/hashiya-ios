import XCTest
import UIKit
import ImageIO

/// Raw screenshots of the production executable, with real isolated documents.
/// Recording scenes use AVFoundation; no Studio mock models are linked.
final class StudioProductionCaptureTests: XCTestCase {
    private var arguments: [String] = []
    override func setUp() { super.setUp(); continueAfterFailure = false }
    override func tearDown() { XCUIDevice.shared.orientation = .portrait; super.tearDown() }

    private func library(english: Bool = false, dark: Bool = false, large: Bool = false) -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        arguments = ["--test-review-entry", "--test-production-content", "--test-reduce-motion",
                     dark ? "--test-appearance-dark" : "--test-appearance-light"]
        if english { arguments.append("--test-english") }
        if large { arguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        let app = XCUIApplication(); app.launchArguments = arguments; app.launch()
        XCTAssertTrue(app.buttons["openNotebook-Tayya Study"].waitForExistence(timeout: 15))
        if large {
            for name in ["libraryHome", "librarySections", "libraryReview", "librarySettings"] {
                let control = app.buttons[name]
                XCTAssertTrue(control.exists && control.isHittable, "Largest text must retain direct access to every real library destination")
                XCTAssertGreaterThanOrEqual(control.frame.width, 44)
                XCTAssertGreaterThanOrEqual(control.frame.height, 44)
            }
        }
        return app
    }
    private func openDocument(_ app: XCUIApplication) {
        app.buttons["openNotebook-Tayya Study"].tap()
        XCTAssertTrue(app.buttons["inkTool"].waitForExistence(timeout: 10))
    }
    private func assertAccessibleNavigation(_ app: XCUIApplication) {
        let window = app.windows.firstMatch.frame
        let pdfFrame = app.otherElements["pdfCanvas"].frame
        var targets = [app.textFields["pageNumber"]]
        targets += ["previousDocumentPage", "nextDocumentPage", "goToPage", "fitDocumentPage", "recordLinkedAudio", "recordingDetails"].map { app.buttons[$0] }
        for target in targets {
            XCTAssertTrue(target.exists)
            let frame = target.frame
            print("NativeNavigation target=\(target.identifier) frame=\(frame) window=\(window)")
            XCTAssertGreaterThanOrEqual(frame.width + 1e-6, 44)
            XCTAssertGreaterThanOrEqual(frame.height + 1e-6, 44)
            XCTAssertGreaterThanOrEqual(frame.minX, window.minX - 0.5, "Core navigation must not begin outside the display")
            XCTAssertLessThanOrEqual(frame.maxX, window.maxX + 0.5, "Core navigation must not end outside the display")
            XCTAssertGreaterThanOrEqual(frame.minY, window.minY)
            XCTAssertLessThanOrEqual(frame.maxY, pdfFrame.minY + 0.5,
                                     "Navigation must occupy its own area above the PDF")
            if target.isEnabled { XCTAssertTrue(target.isHittable) }
        }
        let total = app.staticTexts["documentPageCount"]
        XCTAssertTrue(total.exists)
        let totalFrame = total.frame
        XCTAssertGreaterThanOrEqual(totalFrame.minX, window.minX)
        XCTAssertLessThanOrEqual(totalFrame.maxX, window.maxX)
        let readout = app.staticTexts["recordingElapsed"]
        XCTAssertTrue(readout.exists)
        let readoutFrame = readout.frame
        XCTAssertGreaterThanOrEqual(readoutFrame.minX, window.minX)
        XCTAssertLessThanOrEqual(readoutFrame.maxX, window.maxX)
        XCTAssertGreaterThan(pdfFrame.height, window.height > window.width ? window.height / 3 : 60)
    }
    private func exerciseAccessiblePageNavigation(_ app: XCUIApplication) {
        assertAccessibleNavigation(app)
        let number = app.textFields["pageNumber"]
        number.tap(); number.typeText("3"); app.buttons["goToPage"].tap()
        XCTAssertEqual(number.value as? String, "3", "The fully visible field must perform actual direct navigation")
        app.buttons["previousDocumentPage"].tap()
        XCTAssertEqual(number.value as? String, "2")
        app.buttons["nextDocumentPage"].tap()
        XCTAssertEqual(number.value as? String, "3")
        number.tap(); number.typeText("1"); app.buttons["goToPage"].tap()
        XCTAssertEqual(number.value as? String, "1", "Return to the same reading page for the actual comparison capture")
    }
    private func action(_ name: String, in app: XCUIApplication) {
        app.buttons["workspaceActions"].tap()
        tapCompletedNativeMenuItem(app.buttons[name])
    }
    private func revealTools(_ app: XCUIApplication) {
        if app.buttons["focusToggle"].value as? String == "focused" { app.buttons["focusToggle"].tap() }
    }
    private func focus(_ app: XCUIApplication) {
        if app.buttons["focusToggle"].value as? String != "focused" { app.buttons["focusToggle"].tap() }
        XCTAssertEqual(app.buttons["focusToggle"].value as? String, "focused")
    }
    private func draw(_ app: XCUIApplication, page: Int) {
        // PDFKit deliberately omits overlay canvases from its AX tree. Use the
        // same real viewport gesture as the original ink persistence regression.
        let canvas = app.otherElements["pdfCanvas"]
        XCTAssertTrue(canvas.waitForExistence(timeout: 10))
        XCTAssertEqual(app.textFields["pageNumber"].value as? String, String(page))
        XCTAssertGreaterThan(canvas.frame.width, 80); XCTAssertGreaterThan(canvas.frame.height, 80)
        let start = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.35))
        let end = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.45))
        let before = Int(app.buttons["inkTool"].value as? String ?? "") ?? 0
        start.press(forDuration: 0.1, thenDragTo: end)
        let saved = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            (Int(app.buttons["inkTool"].value as? String ?? "") ?? 0) > before
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [saved], timeout: 5), .completed, "Capture uses an actual committed PencilKit stroke")
    }
    private func rotate(_ orientation: UIDeviceOrientation, in app: XCUIApplication) {
        XCUIDevice.shared.orientation = orientation
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let frame = app.windows.firstMatch.frame
            return orientation.isLandscape ? frame.width > frame.height : frame.height > frame.width
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 10), .completed)
    }
    private func notes(_ app: XCUIApplication, split: Bool) {
        if split { action("splitDocumentNotes", in: app) }
        else {
            app.buttons["openMargin"].tap()
            if app.descendants(matching: .any)["splitDivider"].firstMatch.exists { app.buttons["expandMargin"].tap() }
        }
        XCTAssertTrue(app.textViews["splitNotes"].waitForExistence(timeout: 10))
    }
    private func handwriting(_ app: XCUIApplication) {
        let control = app.segmentedControls["marginMode"]
        XCTAssertTrue(control.waitForExistence(timeout: 5))
        control.buttons[arguments.contains("--test-english") ? "Handwriting" : "خط اليد"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["marginInkCanvas"].firstMatch.waitForExistence(timeout: 10))
    }
    private func closeNotes(_ app: XCUIApplication) { action("closeNotes", in: app) }
    private func thumbnails(_ app: XCUIApplication) {
        app.buttons["documentPages"].tap()
        let pageList = app.scrollViews["documentPageList"]
        XCTAssertTrue(pageList.waitForExistence(timeout: 5))
        for number in 1...5 {
            XCTAssertTrue(pageList.images["pagePreview-\(number)"].waitForExistence(timeout: 10))
        }
        snapshot("Thumbnails")
        app.buttons[arguments.contains("--test-english") ? "Done" : "تم"].firstMatch.tap()
        waitForNativeDismissal(of: pageList)
    }

    func testArabicLightProductionStudyScreens() {
        let app = library()
        snapshot("Library"); openDocument(app); snapshot("Editor")
        app.buttons["inkTool"].tap(); draw(app, page: 1); snapshot("Pen-Tools")
        app.buttons["favoritePens"].tap(); snapshot("Favorite-Pens")
        tapCompletedNativeMenuItem(app.buttons["usePenPreset-0"])
        app.buttons["textTool"].tap()
        app.otherElements["pdfCanvas"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35)).tap()
        XCTAssertTrue(app.textViews["annotationText"].waitForExistence(timeout: 5))
        app.textViews["annotationText"].tap(); app.textViews["annotationText"].typeText("Integrated study note")
        snapshot("Text-Editor", movingContent: true)
        app.buttons["saveAnnotation"].tap()
        waitForNativeDismissal(of: app.textViews["annotationText"])
        notes(app, split: false); snapshot("Notes-Expanded")
        handwriting(app); snapshot("Notes-Ink")
        closeNotes(app)
        focus(app); snapshot("Focus")
        revealTools(app); thumbnails(app)
    }
    func testArabicLandscapeProductionSplitAndInk() {
        let app = library(); openDocument(app)
        rotate(.landscapeLeft, in: app)
        snapshot("Editor")
        notes(app, split: true); snapshot("Notes-Split")
        handwriting(app); snapshot("Notes-Split-Ink")
        closeNotes(app)
        app.buttons["inkTool"].tap(); snapshot("Pen-Tools")
    }
    func testArabicDarkProductionScreens() {
        let app = library(dark: true)
        snapshot("Library"); openDocument(app); snapshot("Editor")
        notes(app, split: true); snapshot("Notes-Split")
        closeNotes(app); thumbnails(app)
        focus(app); snapshot("Focus")
    }
    func testLargestArabicProductionTextInBothOrientations() {
        let app = library(large: true)
        snapshot("Library"); openDocument(app); exerciseAccessiblePageNavigation(app); snapshot("Editor")
        app.buttons["workspaceToolHelp"].tap(); snapshot("Tool-Help")
        app.buttons["تم"].firstMatch.tap()
        notes(app, split: false); snapshot("Notes-Expanded")
        closeNotes(app)
        rotate(.landscapeLeft, in: app)
        focus(app)
        snapshot("Focus")
        revealTools(app); snapshot("Editor")
    }
    func testLargestEnglishDarkProductionTextInBothOrientations() {
        let app = library(english: true, dark: true, large: true)
        snapshot("Library"); openDocument(app); exerciseAccessiblePageNavigation(app); snapshot("Editor")
        notes(app, split: false); snapshot("Notes-Expanded")
        closeNotes(app)
        rotate(.landscapeLeft, in: app)
        focus(app)
        snapshot("Focus")
        revealTools(app); snapshot("Editor")
    }
    func testRealRecordingAndPageMarkers() {
        let app = library(); openDocument(app)
        app.buttons["recordLinkedAudio"].tap()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let started = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            for title in ["Allow", "OK", "السماح", "موافق"] {
                let button = springboard.alerts.buttons[title]
                if button.exists { button.tap() }
            }
            return app.buttons["recordLinkedAudio"].value as? String == "جارٍ التسجيل"
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [started], timeout: 15), .completed)
        app.buttons["nextDocumentPage"].tap()
        XCTAssertEqual(app.textFields["pageNumber"].value as? String, "2")
        app.buttons["inkTool"].tap(); draw(app, page: 2)
        snapshot("Recording-Active", movingContent: true)
        app.buttons["recordingDetails"].tap()
        app.buttons["addAudioMarker"].tap()
        app.buttons["stopLinkedRecording"].tap()
        XCTAssertTrue(app.buttons["playLinkedRecording"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "كتابة بخط اليد")).firstMatch.exists,
                      "The actual committed stroke must have a real recording timestamp")
        snapshot("Recording-Markers")
        app.buttons["playLinkedRecording"].firstMatch.tap()
        XCTAssertTrue(app.buttons["pauseLinkedRecording"].waitForExistence(timeout: 5))
        snapshot("Recording-Playback", movingContent: true)
    }

    private func snapshot(_ name: String, movingContent: Bool = false) {
        let app = XCUIApplication()
        if name == "Editor" && arguments.contains("UICTContentSizeCategoryAccessibilityXXXL") { assertAccessibleNavigation(app) }
        let landscape = XCUIDevice.shared.orientation.isLandscape
        let oriented = NSPredicate { _, _ in
            let frame = app.windows.firstMatch.frame
            return landscape ? frame.width > frame.height : frame.height > frame.width
        }
        var previousPixels: Data?
        var previousWindow: CGRect?
        var settled: XCUIScreenshot?
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard oriented.evaluate(with: nil) else { previousPixels = nil; previousWindow = nil; return false }
            let window = app.windows.firstMatch.frame
            let candidate = XCUIScreen.main.screenshot()
            guard let pixels = candidate.image.cgImage?.dataProvider?.data else { return false }
            let bytes = pixels as Data
            // Live microphones, playback clocks and editing carets deliberately
            // change pixels. Require settled window geometry for those scenes.
            let stable = movingContent ? previousWindow == window : previousPixels == bytes
            previousWindow = window; previousPixels = bytes
            if stable { settled = candidate }
            return stable
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed,
                       "Capture waits for native orientation and compositor readiness")
        guard let screenshot = settled,
              let source = CGImageSourceCreateWithData(screenshot.pngRepresentation as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any],
              let pixelWidth = properties[kCGImagePropertyPixelWidth as String] as? Int,
              let pixelHeight = properties[kCGImagePropertyPixelHeight as String] as? Int else {
            XCTFail("No original native PNG dimensions"); return
        }
        let orientation = screenshot.image.imageOrientation
        let window = app.windows.firstMatch.frame
        let pngOrientation = properties[kCGImagePropertyOrientation as String] as? Int ?? 1
        let swaps = [5, 6, 7, 8].contains(pngOrientation)
        let displayWidth = swaps ? pixelHeight : pixelWidth, displayHeight = swaps ? pixelWidth : pixelHeight
        XCTAssertEqual(CGFloat(displayWidth) / CGFloat(displayHeight), window.width / window.height, accuracy: 0.02,
                       "Original PNG with its native EXIF must match the window; do not rotate or crop it afterward")
        let metadata: [String: Any] = ["screen": name, "orientation": landscape ? "landscape" : "portrait",
            "font_size": arguments.contains("UICTContentSizeCategoryAccessibilityXXXL") ? "AX5" : "default",
            "language": arguments.contains("--test-english") ? "en" : "ar",
            "color_mode": arguments.contains("--test-appearance-dark") ? "dark" : "light",
            "capture_state": movingContent ? "live content, settled native window" : "consecutive identical full-display pixels",
            "metadata_origin": "actual UI test launch arguments and native display",
            "window_width": Double(window.width), "window_height": Double(window.height),
            "pixel_width": pixelWidth, "pixel_height": pixelHeight, "uiimage_orientation": orientation.rawValue,
            "png_orientation": pngOrientation]
        let suffix = "\(name)-\(landscape ? "landscape" : "portrait")"
        let image = XCTAttachment(data: screenshot.pngRepresentation, uniformTypeIdentifier: "public.png"); image.name = "ProductionScene-" + suffix
        image.lifetime = .keepAlways; add(image)
        do {
            let details = XCTAttachment(data: try JSONSerialization.data(withJSONObject: metadata, options: [.sortedKeys]), uniformTypeIdentifier: "public.json")
            details.name = "ProductionMetadata-" + suffix; details.lifetime = .keepAlways; add(details)
        } catch { XCTFail("Native screenshot metadata failed: \(error)") }
    }
}
