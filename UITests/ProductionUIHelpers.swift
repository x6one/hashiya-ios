import XCTest
import UIKit

/// On iPad the Welcome sheet has its own scroll viewport. An AX element may
/// exist below that viewport at large text sizes while its center cannot tap.
func openProductionDemonstration(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
    let button = app.buttons["welcomeDemonstration"]
    guard button.waitForExistence(timeout: 15) else {
        XCTFail("The real Welcome demonstration must exist", file: file, line: line); return
    }
    let scroll = app.scrollViews.containing(.button, identifier: "welcomeDemonstration").firstMatch
    guard scroll.waitForExistence(timeout: 5) else {
        XCTFail("Welcome must expose its real scroll viewport", file: file, line: line); return
    }
    func fullyVisible() -> Bool {
        let viewport = scroll.frame.intersection(app.windows.firstMatch.frame)
        let target = button.frame
        return !viewport.isEmpty && target.minY >= viewport.minY && target.maxY <= viewport.maxY && button.isHittable
    }
    for _ in 0..<6 {
        if fullyVisible() { break }
        scroll.swipeUp()
    }
    guard fullyVisible() else {
        XCTFail("Scroll the entire real Welcome button into its sheet before tapping", file: file, line: line); return
    }
    button.tap()
}

func waitForNativeDismissal(of element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
    let closed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in !element.exists }, object: nil)
    XCTAssertEqual(XCTWaiter.wait(for: [closed], timeout: 5), .completed,
                   "The native presentation must leave the hierarchy before interacting with controls behind it", file: file, line: line)
}

func observeNativeMenuAbsence(of item: XCUIElement) -> (absent: Bool, wallSeconds: TimeInterval, foreground: Bool) {
    let started = ProcessInfo.processInfo.systemUptime
    let absent = item.waitForNonExistence(timeout: 5)
    let elapsed = ProcessInfo.processInfo.systemUptime - started
    return (absent, elapsed, XCUIApplication().state == .runningForeground)
}

func tapCompletedNativeMenuItem(_ item: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
    let app = XCUIApplication()
    let window = app.windows.firstMatch.frame
    var visibleRow: (any XCUIElementSnapshot)?
    let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
        // One remote transaction: separate exists/frame calls can consume the
        // complete waiter budget before an already-visible row is evaluated.
        guard let row = try? item.snapshot() else { return false }
        let frame = row.frame
        guard row.isEnabled, !frame.isEmpty, !frame.isNull, window.contains(frame) else { return false }
        visibleRow = row
        return true
    }, object: nil)
    guard XCTWaiter.wait(for: [ready], timeout: 5) == .completed else {
        // A visible native menu can report no AX hit point. Preserve its real
        // geometry and original pixels before deciding whether a touch is valid.
        let exists = item.exists
        let identity = exists ? item.identifier : "unresolved"
        let geometry = exists ? "frame=\(item.frame); label=\(item.label)" : "absent"
        let details = XCTAttachment(string: "target=\(identity); exists=\(exists); \(geometry); window=\(app.windows.firstMatch.frame)\n"
            + String(item.debugDescription.prefix(30000)))
        details.name = "FailedNativeMenu-" + identity; details.lifetime = .keepAlways; XCTContext.runActivity(named: "Preserve failed native menu") { activity in
            activity.add(details)
            let pixels = XCTAttachment(data: XCUIScreen.main.screenshot().pngRepresentation, uniformTypeIdentifier: "public.png")
            pixels.name = "FailedNativeMenu-OriginalDisplay"; pixels.lifetime = .keepAlways; activity.add(pixels)
        }
        XCTFail("The real native menu row must be fully inside the window before touching it", file: file, line: line); return
    }
    // Keep the real identity before the tap. The public native non-existence
    // waiter owns missing-element lookup instead of enumerating the complete
    // underlying PDF/Notes hierarchy to count matches.
    let identity = visibleRow?.identifier ?? ""
    guard !identity.isEmpty else {
        XCTFail("The real menu row must have an identifier before selecting it", file: file, line: line); return
    }
    // A visible iPad native row can throw while resolving its AX activation
    // point. Touch its verified visible center; retain actual menu removal.
    item.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    let observation = observeNativeMenuAbsence(of: item)
    let details = "target=\(identity); frameworkTimeout=5; nativeAbsent=\(observation.absent); observerWallSeconds=\(observation.wallSeconds); foreground=\(observation.foreground)"
    let receipt = XCTAttachment(string: details)
    receipt.name = "NativeMenuDismissal-" + identity; receipt.lifetime = .keepAlways
    XCTContext.runActivity(named: "Verify actual native menu removal") { $0.add(receipt) }
    print("NativeMenuDismissal " + details)
    XCTAssertTrue(observation.absent,
                   "The native presentation must leave the hierarchy before interacting with controls behind it", file: file, line: line)
    // The original contract requires a five-second framework wait to succeed.
    // AX request/response overhead is measured above, not an additional UI SLO.
    // The open-menu negative control separately proves absence is mandatory.
    XCTAssertTrue(observation.foreground, "A background application is not proof of native menu removal", file: file, line: line)
}

/// Use the original recording regression's5s permission interaction before
/// its unchanged15s authorized-recorder assertion. Never simulate recording.
func startProductionRecording(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
    let record = app.buttons["recordLinkedAudio"]
    record.tap()
    let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    let allow = springboard.alerts.buttons.matching(NSPredicate(format: "label IN %@", ["Allow", "OK", "السماح", "موافق"])).firstMatch
    if allow.waitForExistence(timeout: 5) { allow.tap() }
    let started = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "جارٍ التسجيل"), object: record)
    XCTAssertEqual(XCTWaiter.wait(for: [started], timeout: 15), .completed,
                   "The actual recorder must start after microphone authorization", file: file, line: line)
}

// Shared native pixel check; the original orientation/control-exclusion test remains unchanged.
func nativeGreenInkPixels(in screenshot: UIImage, frame canvasFrame: CGRect) -> Int {
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
