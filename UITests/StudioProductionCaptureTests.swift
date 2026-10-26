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
        arguments = ["--test-review-entry", "--test-production-content", "--test-reduce-motion", "--test-native-menu", "--test-native-visibility",
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
            if target.isEnabled {
                if target.identifier == "nextDocumentPage" {
                    assertNextPageTouch(target, in: app)
                } else { XCTAssertTrue(target.isHittable) }
            }
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
    private func assertNextPageTouch(_ target: XCUIElement, in app: XCUIApplication) {
        let number = app.textFields["pageNumber"]
        guard let initial = Int(number.value as? String ?? "") else { XCTFail("Read the real page before checking native navigation"); return }
        func evidence(_ stage: String) {
            print("NativeNextTouch stage=\(stage) page=\(number.value as? String ?? "missing") hittable=\(target.isHittable) matches=\(app.buttons.matching(identifier: "nextDocumentPage").count) native=\(app.otherElements["pdfCanvas"].value as? String ?? "missing")")
            let shot = XCTAttachment(data: XCUIScreen.main.screenshot().pngRepresentation, uniformTypeIdentifier: "public.png")
            shot.name = "NativeNextTouch-" + stage; shot.lifetime = .keepAlways; add(shot)
        }
        let reportedBefore = target.isHittable
        if !reportedBefore { evidence("Before") }
        // A physical center touch inside the already-verified44pt rectangle is
        // a valid user interaction even when AX reports no preferred hit point.
        target.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            Int(number.value as? String ?? "") == initial + 1
        }, object: nil)
        let result = XCTWaiter.wait(for: [changed], timeout: 5)
        print("NativeNextTouch changed=\(result.rawValue) expected=\(initial + 1)")
        if !reportedBefore || result != .completed { evidence("After") }
        if result == .completed {
            app.buttons["previousDocumentPage"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            let restored = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                Int(number.value as? String ?? "") == initial
            }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [restored], timeout: 5), .completed)
        }
        XCTAssertEqual(result, .completed, "Prove the actual Next-page touch independently of the AX boolean")
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

    private func applyFirstFavoritePen(_ app: XCUIApplication) {
        let item = app.buttons["usePenPreset-0"]
        XCTAssertTrue(item.waitForExistence(timeout: 5))
        let frame = item.frame, window = app.windows.firstMatch.frame
        guard !frame.isEmpty, window.contains(frame) else {
            XCTFail("The actual favorite pen must be entirely inside the display before touching it"); return
        }
        let canvas = app.otherElements["pdfCanvas"]
        let before = (canvas.value as? String ?? "").components(separatedBy: "apply=0;").count
        let page = app.textFields["pageNumber"].value as? String
        let strokes = app.buttons["inkTool"].value as? String
        // The saved iPad failure has a visible native row and a hittable=true
        // AX receipt after the readiness waiter expired. A real center touch
        // avoids treating AX preferred-hit-point latency as pen functionality.
        item.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let applied = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            (canvas.value as? String ?? "").components(separatedBy: "apply=0;").count > before
                && app.buttons["inkBrush"].value as? String == "قلم"
                && app.buttons["inkWidth"].value as? String == "3"
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [applied], timeout: 5), .completed,
                       "The actual favorite-pen action must commit; dismissing a backdrop cannot pass")
        waitForNativeDismissal(of: item)
        XCTAssertEqual(app.textFields["pageNumber"].value as? String, page)
        XCTAssertEqual(app.buttons["inkTool"].value as? String, strokes)
    }

    func testArabicLightProductionStudyScreens() {
        let app = library()
        snapshot("Library"); openDocument(app); assertAccessibleNavigation(app); snapshot("Editor")
        app.buttons["inkTool"].tap(); draw(app, page: 1); snapshot("Pen-Tools")
        app.buttons["favoritePens"].tap(); snapshot("Favorite-Pens")
        applyFirstFavoritePen(app)
        app.buttons["textTool"].tap()
        app.otherElements["pdfCanvas"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35)).tap()
        XCTAssertTrue(app.textViews["annotationText"].waitForExistence(timeout: 5))
        app.textViews["annotationText"].tap(); app.textViews["annotationText"].typeText("Assets = Liabilities + Equity")
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
    func testNativeMenuAbsenceRejectsAnUnselectedVisibleAction() {
        let app = library(dark: true); openDocument(app)
        waitForRenderedSidebarPreviews(app)
        app.buttons["workspaceActions"].tap()
        let item = app.buttons["splitDocumentNotes"]
        XCTAssertTrue(item.waitForExistence(timeout: 5))
        // Do not select or dismiss anything. An actually open native menu
        // must fail the same absence oracle used by the original positive case.
        let observation = observeNativeMenuAbsence(of: item)
        let stillPresent = item.exists
        let details = "frameworkTimeout=5; nativeAbsent=\(observation.absent); rowStillPresent=\(stillPresent); observerWallSeconds=\(observation.wallSeconds); foreground=\(observation.foreground)"
        print("NativeMenuOpenNegativeControl " + details)
        let receipt = XCTAttachment(string: details)
        receipt.name = "NativeMenuOpenNegativeControl"; receipt.lifetime = .keepAlways; add(receipt)
        let screen = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screen.name = "NativeMenuStillOpenOriginalDisplay"; screen.lifetime = .keepAlways; add(screen)
        XCTAssertFalse(observation.absent, "An unselected visible menu must never pass native absence")
        XCTAssertTrue(stillPresent)
        XCTAssertTrue(item.frame.intersects(app.windows.firstMatch.frame))
        XCTAssertTrue(observation.foreground)
        XCTAssertFalse(app.textViews["splitNotes"].exists, "Waiting must not perform the Notes action")
        XCTAssertEqual(app.textFields["pageNumber"].value as? String, "1")
        app.terminate()
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

    private func waitForRenderedSidebarPreviews(_ app: XCUIApplication) {
        let sidebar = app.descendants(matching: .any)["documentPageSidebar"].firstMatch
        guard sidebar.exists else { return }
        let started = ProcessInfo.processInfo.systemUptime
        let viewport = sidebar.frame.intersection(app.windows.firstMatch.frame)
        guard !viewport.isNull, !viewport.isEmpty else { return }
        let cells = sidebar.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "sidebarPage-")).allElementsBoundByIndex
        var required: [String] = []
        for cell in cells {
            let visible = cell.frame.intersection(viewport)
            if !visible.isNull, !visible.isEmpty {
                required.append("pagePreview-" + String(cell.identifier.dropFirst("sidebarPage-".count)))
            }
        }
        guard !required.isEmpty else {
            XCTFail("The visible sidebar must expose its real page containers: " + sidebar.debugDescription); return
        }
        // The saved cold Simulator trace spent24.25s in the native ink preview
        // while Metal compiled shaders. Wait for real async content FIRST;
        // the separate five-second pixel/orientation check remains unchanged.
        // One deadline covers visible placeholders only, never the whole PDF.
        for identity in required {
            let remaining = 30 - (ProcessInfo.processInfo.systemUptime - started)
            let image = sidebar.images[identity]
            guard remaining > 0, image.waitForExistence(timeout: remaining) else {
                let evidence = XCTAttachment(string: "required=\(required)\n" + sidebar.debugDescription)
                evidence.name = "FailedVisiblePreviewReadiness"; evidence.lifetime = .keepAlways; add(evidence)
                XCTFail("Visible native preview did not finish within the shared30s content budget: " + identity); return
            }
            XCTAssertEqual(image.value as? String, "rendered", "A placeholder or failed image is not a ready preview")
        }
        let elapsed = ProcessInfo.processInfo.systemUptime - started
        print("NativePreviewReadiness required=\(required); elapsed=\(elapsed)")
        XCTAssertLessThanOrEqual(elapsed, 30, "All visible previews share one content-loading budget")
        XCTAssertEqual(app.state, .runningForeground)
    }

    private func settledScreenshot(_ app: XCUIApplication, landscape: Bool, movingContent: Bool) -> XCUIScreenshot? {
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
        return settled
    }
    private func snapshot(_ name: String, movingContent: Bool = false) {
        let app = XCUIApplication()
        let landscape = XCUIDevice.shared.orientation.isLandscape
        waitForRenderedSidebarPreviews(app)
        var settled = settledScreenshot(app, landscape: landscape, movingContent: movingContent)
        if name == "Editor" && arguments.contains("UICTContentSizeCategoryAccessibilityXXXL") {
            assertAccessibleNavigation(app)
            // The actual Next/Previous assertions return to the same page.
            // Capture its settled pixels after those real interactions too.
            settled = settledScreenshot(app, landscape: landscape, movingContent: movingContent)
        }
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
        if landscape && (name == "Editor" || name == "Focus") {
            assertClosedNotesDoNotPaintSafeAreas(screenshot.image, in: app)
        }
    }

    private func assertClosedNotesDoNotPaintSafeAreas(_ screenshot: UIImage, in app: XCUIApplication) {
        // A closed retained Notes pane must not draw controls outside the PDF
        // viewport. iPad's real page sidebar deliberately occupies this area.
        guard UIDevice.current.userInterfaceIdiom == .phone else { return }
        let window = app.windows.firstMatch.frame
        let element = app.otherElements["pdfCanvas"]
        // SwiftUI can merge a safe-area background into the identified AX
        // frame. Measure the existing read-only native PDFView window bounds,
        // so a wider accessibility wrapper cannot turn the gutter check empty.
        let state = element.value as? String ?? ""
        guard let end = state.range(of: "; pdfCenterReceives="), state.hasPrefix("screen=") else {
            XCTFail("Read the actual native PDF window bounds: " + state); return
        }
        let fields = state[state.index(state.startIndex, offsetBy: 7)..<end.lowerBound]
            .replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: "")
            .split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard fields.count == 4 else { XCTFail("Decode actual native PDF bounds: " + state); return }
        let pdf = CGRect(x: fields[0], y: fields[1], width: fields[2], height: fields[3])
        XCTAssertGreaterThan(pdf.height, 60)
        XCTAssertTrue(window.insetBy(dx: -0.5, dy: -0.5).contains(pdf), "Native PDF must remain inside the display")
        let format = UIGraphicsImageRendererFormat(); format.scale = screenshot.scale
        let upright = UIGraphicsImageRenderer(size: screenshot.size, format: format).image { _ in
            screenshot.draw(in: CGRect(origin: .zero, size: screenshot.size))
        }
        guard let image = upright.cgImage else { XCTFail("Read actual screenshot pixels"); return }
        let scale = CGFloat(image.width) / screenshot.size.width
        let gutters = [CGRect(x: window.minX, y: pdf.minY + 2, width: max(0, pdf.minX - window.minX - 2), height: pdf.height - 4),
                       CGRect(x: pdf.maxX + 2, y: pdf.minY + 2, width: max(0, window.maxX - pdf.maxX - 2), height: pdf.height - 4)]
        XCTAssertGreaterThan(gutters.reduce(CGFloat.zero) { $0 + $1.width }, 0,
                             "The landscape phone safe-area check must inspect actual pixels")
        let dark = arguments.contains("--test-appearance-dark")
        var painted = 0
        for gutter in gutters where gutter.width > 1 {
            let crop = CGRect(x: gutter.minX * scale, y: gutter.minY * scale,
                              width: gutter.width * scale, height: gutter.height * scale)
            guard let region = image.cropping(to: crop) else { XCTFail("Read the actual safe-area gutter"); return }
            var pixels = [UInt8](repeating: 0, count: region.width * region.height * 4)
            pixels.withUnsafeMutableBytes { bytes in
                guard let context = CGContext(data: bytes.baseAddress, width: region.width, height: region.height,
                    bitsPerComponent: 8, bytesPerRow: region.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else {
                    XCTFail("Decode the original gutter colors"); return
                }
                context.draw(region, in: CGRect(x: 0, y: 0, width: region.width, height: region.height))
                for index in stride(from: 0, to: bytes.count, by: 4) {
                    let red = Int(bytes[index]), green = Int(bytes[index + 1]), blue = Int(bytes[index + 2])
                    if green > red + 8 && green > blue + 4 && (dark ? green > 120 : green < 160) { painted += 1 }
                }
            }
        }
        print("ClosedNotesSafeArea inkPixels=\(painted) dark=\(dark) nativePDF=\(pdf) axPDF=\(element.frame) window=\(window)")
        XCTAssertEqual(painted, 0, "Closed Notes must not leak green controls into the display safe areas")
    }
}
