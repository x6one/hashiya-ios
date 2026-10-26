import XCTest
import UIKit

final class ControlTests: XCTestCase {
    @MainActor func testFirstCompactPencilStrokeAfterNativeColorPicker() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = XCUIApplication(); app.launch()
        let canvas = app.scrollViews["controlCanvas"]
        XCTAssertTrue(canvas.waitForExistence(timeout: 5))
        XCTAssertEqual(canvas.value as? String, "1")
        XCTAssertEqual(canvas.frame.width, 367.3333333333333, accuracy: 1)
        XCTAssertEqual(canvas.frame.height, 88.66666666666666, accuracy: 1)
        app.buttons["controlPencil"].tap(); app.buttons["controlColor"].tap()
        let picker = app.otherElements["controlPicker"].firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        let swatch = picker.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "dark red 16")).firstMatch
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            swatch.exists && swatch.isHittable && picker.frame.contains(swatch.frame)
        }, object: NSObject())
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed)
        swatch.tap(); app.buttons["controlCloseColor"].tap()
        let committed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            (app.staticTexts["controlTool"].value as? String)?.contains("rgba:0.5137,0.0667,0.0000,1.0000") == true
                && !app.otherElements["controlPicker"].exists
        }, object: NSObject())
        XCTAssertEqual(XCTWaiter.wait(for: [committed], timeout: 5), .completed)
        let frame = canvas.frame
        let baseline = XCUIScreen.main.screenshot()
        attach(baseline, "DIAGNOSTIC-NativeControl-Before")
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
        timing.name = "DIAGNOSTIC-NativeControl-ActualPixels"; timing.lifetime = .keepAlways; add(timing)
        attach(XCUIScreen.main.screenshot(), "DIAGNOSTIC-NativeControl-After")
        print("NativePencilKitControl result=\(result.rawValue); \(samples.joined(separator: "; "))")
        XCTAssertEqual(result, .completed, "The isolated native control must display its actual first red pencil stroke within5s")
        XCTAssertEqual(canvas.value as? String, "2")
        XCTAssertEqual(canvas.frame, frame)
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
            for i in stride(from: 0, to: bytes.count, by: 4) {
                let r = Int(bytes[i]), g = Int(bytes[i + 1]), b = Int(bytes[i + 2])
                if r > g + 25 && r > b + 25 && r > 80 { count += 1 }
            }
            return count
        }
    }
}
