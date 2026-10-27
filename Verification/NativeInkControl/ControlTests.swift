import XCTest
import UIKit

final class ControlTests: XCTestCase {
    @MainActor func testFirstCompactPencilStrokeAfterNativeColorPicker() {
        exerciseNativeInk(precedingDocument: false)
    }
    @MainActor func testDocumentInkThenRetainedNotesFirstPencilStroke() {
        exerciseNativeInk(precedingDocument: true)
    }
    @MainActor func testProductionNotesAfterDocumentInk() {
        exerciseNativeInk(precedingDocument: true, productionNotes: true)
    }
    @MainActor func testIPadProductionNotesAfterDocumentInk() {
        exerciseNativeInk(precedingDocument: true, productionNotes: true, padRecurrence: true)
    }
    @MainActor private func exerciseNativeInk(precedingDocument: Bool, productionNotes: Bool = false,
                                             padRecurrence: Bool = false) {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = XCUIApplication()
        if precedingDocument { app.launchArguments = ["--two-canvases"] }
        if productionNotes { app.launchArguments += ["--production-notes", "--test-accessibility-type", "--test-reduce-motion"] }
        if padRecurrence { app.launchArguments += ["--pad-recurrence"] }
        app.launch()
        if padRecurrence {
            XCTAssertEqual(app.frame.width, 1032, accuracy: 1)
            XCTAssertEqual(app.frame.height, 1376, accuracy: 1)
        }
        if precedingDocument { exerciseDocument(in: app) }
        let canvas = app.scrollViews[productionNotes ? "marginInkCanvas" : "controlCanvas"]
        XCTAssertTrue(canvas.waitForExistence(timeout: 5))
        XCTAssertEqual(canvas.value as? String, "1")
        let portrait = padRecurrence ? CGRect(x: 0, y: 251.5, width: 405, height: 891)
            : CGRect(x: 0, y: 670.6666666666666, width: 440, height: 147.33333333333331)
        XCTAssertEqual(canvas.frame.width, portrait.width, accuracy: 1)
        XCTAssertEqual(canvas.frame.height, portrait.height, accuracy: 1)
        if padRecurrence {
            XCTAssertEqual(canvas.frame.minX, portrait.minX, accuracy: 1)
            XCTAssertEqual(canvas.frame.minY, portrait.minY, accuracy: 1)
        }
        attach(XCUIScreen.main.screenshot(), "DIAGNOSTIC-NativeControl-PortraitSeed")
        XCUIDevice.shared.orientation = .landscapeLeft
        let expectedPaper = padRecurrence ? CGRect(x: 0, y: 251.5, width: 560, height: 547)
            : CGRect(x: 62, y: 235.33333333333334, width: 367.3333333333333, height: 88.66666666666666)
        let landscape = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let application = app.frame
            guard application.width > application.height else { return false }
            let paper = canvas.frame
            return abs(paper.width - expectedPaper.width) <= 1
                && abs(paper.height - expectedPaper.height) <= 1
        }, object: app)
        XCTAssertEqual(XCTWaiter.wait(for: [landscape], timeout: 5), .completed)
        XCTAssertEqual(canvas.frame.width, expectedPaper.width, accuracy: 1)
        XCTAssertEqual(canvas.frame.height, expectedPaper.height, accuracy: 1)
        if padRecurrence {
            XCTAssertEqual(app.frame.width, 1376, accuracy: 1)
            XCTAssertEqual(app.frame.height, 1032, accuracy: 1)
            XCTAssertEqual(canvas.frame.minX, expectedPaper.minX, accuracy: 1)
            XCTAssertEqual(canvas.frame.minY, expectedPaper.minY, accuracy: 1)
        }
        if productionNotes {
            app.buttons["inkBrush"].tap()
            app.buttons["inkBrushOption-pencil"].tap()
            XCTAssertEqual(app.buttons["inkBrush"].value as? String, "رصاص")
            app.buttons["inkWidth"].tap()
            app.buttons["inkWidthOption-8"].tap()
            XCTAssertEqual(app.buttons["inkWidth"].value as? String, "8")
            app.buttons["inkColor"].tap()
            selectProductionColor(in: app, padRecurrence: padRecurrence)
        } else {
            app.buttons["controlPencil"].tap(); app.buttons["controlColor"].tap()
            selectColor(in: app, swatchName: "dark red 16", rgba: "0.5137,0.0667,0.0000,1.0000")
        }
        let frame = canvas.frame
        let state = { app.staticTexts["controlStrokeCount"].label }
        let before = XCTAttachment(string: state()); before.name = "DIAGNOSTIC-Notes-BeforeNativeOwners"
        before.lifetime = .keepAlways; add(before)
        requireRedStroke(on: canvas, frame: frame, name: "Notes", nativeState: state)
        XCTAssertEqual(canvas.value as? String, "2")
        XCTAssertEqual(canvas.frame, frame)
    }
    @MainActor private func exerciseDocument(in app: XCUIApplication) {
        let pdf = app.otherElements["controlPDF"]
        XCTAssertTrue(pdf.waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["controlStrokeCount"].value as? String, "0")
        app.buttons["controlPencil"].tap(); app.buttons["controlColor"].tap()
        selectColor(in: app, swatchName: "red 77", rgba: "1.0000,0.7098,0.6863,1.0000")
        requireRedStroke(on: pdf, frame: pdf.frame, name: "PrecedingDocument",
                         nativeState: { app.staticTexts["controlStrokeCount"].label })
        for (action, expected) in [("controlUndo", "0"), ("controlRedo", "1")] {
            app.buttons[action].tap()
            let started = ProcessInfo.processInfo.systemUptime
            let actual = app.staticTexts["controlStrokeCount"].value as? String
            let elapsed = ProcessInfo.processInfo.systemUptime - started
            XCTAssertEqual(actual, expected)
            XCTAssertLessThanOrEqual(elapsed, 5, "Native Undo/Redo result must be observed within5s")
        }
        app.buttons["controlFit"].tap()
        XCTAssertEqual(app.staticTexts["controlStrokeCount"].value as? String, "1")
        attach(XCUIScreen.main.screenshot(), "DIAGNOSTIC-PrecedingDocument-AfterRedoFit")
        app.buttons["controlShowNotes"].tap()
    }
    @MainActor private func selectColor(in app: XCUIApplication, swatchName: String, rgba: String) {
        let picker = app.otherElements["controlPicker"].firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        let swatch = picker.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", swatchName)).firstMatch
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            swatch.exists && swatch.isHittable && picker.frame.contains(swatch.frame)
        }, object: NSObject())
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed)
        swatch.tap(); app.buttons["controlCloseColor"].tap()
        let committed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            (app.staticTexts["controlTool"].value as? String)?.contains("rgba:" + rgba) == true
                && !app.otherElements["controlPicker"].exists
        }, object: NSObject())
        XCTAssertEqual(XCTWaiter.wait(for: [committed], timeout: 5), .completed)
    }
    @MainActor private func selectProductionColor(in app: XCUIApplication, padRecurrence: Bool = false) {
        let picker = app.otherElements["nativeInkColorPicker"].firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        let swatch = picker.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", padRecurrence ? "red 77" : "dark red 16")).firstMatch
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            swatch.exists && swatch.isHittable && picker.frame.contains(swatch.frame)
        }, object: NSObject())
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed)
        swatch.tap(); app.buttons["closeInkColorPicker"].tap()
        let committed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            (app.buttons["inkColor"].value as? String) == (padRecurrence
                ? "rgba:1.0000,0.7098,0.6863,1.0000" : "rgba:0.5137,0.0667,0.0000,1.0000")
                && !app.otherElements["nativeInkColorPicker"].exists
        }, object: NSObject())
        XCTAssertEqual(XCTWaiter.wait(for: [committed], timeout: 5), .completed)
    }
    @MainActor private func requireRedStroke(on canvas: XCUIElement, frame: CGRect, name: String,
                                           nativeState: (() -> String)? = nil) {
        let baseline = XCUIScreen.main.screenshot()
        attach(baseline, "DIAGNOSTIC-" + name + "-Before")
        let before = redPixels(baseline, frame: frame)
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.35)).press(forDuration: 0.1,
            thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.65, dy: 0.5)))
        let start = ProcessInfo.processInfo.systemUptime
        var samples: [String] = []
        let visible = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let pixels = self.redPixels(XCUIScreen.main.screenshot(), frame: frame)
            samples.append("elapsed=\(ProcessInfo.processInfo.systemUptime - start); red=\(pixels); baseline=\(before)")
            return pixels > before + 40
        }, object: NSObject())
        let result = XCTWaiter.wait(for: [visible], timeout: 5)
        let timing = XCTAttachment(string: samples.joined(separator: "\n"))
        timing.name = "DIAGNOSTIC-" + name + "-ActualPixels"; timing.lifetime = .keepAlways; add(timing)
        attach(XCUIScreen.main.screenshot(), "DIAGNOSTIC-" + name + "-After")
        if let nativeState {
            let owners = XCTAttachment(string: nativeState())
            owners.name = "DIAGNOSTIC-" + name + "-AfterNativeOwners"; owners.lifetime = .keepAlways; add(owners)
        }
        print("NativePencilKitControl phase=\(name); result=\(result.rawValue); \(samples.joined(separator: "; "))")
        XCTAssertEqual(result, .completed, "The isolated native control must display its actual first red pencil stroke within5s")
    }
    private func attach(_ screenshot: XCUIScreenshot, _ name: String) {
        let file = XCTAttachment(screenshot: screenshot); file.name = name; file.lifetime = .keepAlways; add(file)
    }
    private func redPixels(_ screenshot: XCUIScreenshot, frame: CGRect) -> Int {
        let image = screenshot.image, format = UIGraphicsImageRendererFormat(); format.scale = image.scale
        let upright = UIGraphicsImageRenderer(size: image.size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: image.size)) }
        guard let raster = upright.cgImage else { return 0 }
        let scale = CGFloat(raster.width) / upright.size.width
        let crop = CGRect(x: frame.minX * scale, y: frame.minY * scale, width: frame.width * scale, height: frame.height * scale)
        guard let ink = raster.cropping(to: crop) else { return 0 }
        var bytes = [UInt8](repeating: 0, count: ink.width * ink.height * 4)
        return bytes.withUnsafeMutableBytes { data in
            guard let context = CGContext(data: data.baseAddress, width: ink.width, height: ink.height,
                bitsPerComponent: 8, bytesPerRow: ink.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else { return 0 }
            context.draw(ink, in: CGRect(x: 0, y: 0, width: ink.width, height: ink.height))
            var count = 0
            for i in stride(from: 0, to: data.count, by: 4) {
                let r = Int(data[i]), g = Int(data[i + 1]), b = Int(data[i + 2])
                if r > g + 25 && r > b + 25 && r > 80 { count += 1 }
            }
            return count
        }
    }
}
