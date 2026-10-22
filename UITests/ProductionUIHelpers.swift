import XCTest

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

func tapCompletedNativeMenuItem(_ item: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
    let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in item.exists && item.isHittable }, object: nil)
    guard XCTWaiter.wait(for: [ready], timeout: 5) == .completed else {
        // A visible native menu can report no AX hit point. Preserve its real
        // geometry and original pixels before deciding whether a touch is valid.
        let app = XCUIApplication()
        let exists = item.exists
        let identity = exists ? item.identifier : "unresolved"
        let geometry = exists ? "frame=\(item.frame); hittable=\(item.isHittable); label=\(item.label)" : "absent"
        let details = XCTAttachment(string: "target=\(identity); exists=\(exists); \(geometry); window=\(app.windows.firstMatch.frame)\n"
            + String(item.debugDescription.prefix(30000)))
        details.name = "FailedNativeMenu-" + identity; details.lifetime = .keepAlways; XCTContext.runActivity(named: "Preserve failed native menu") { activity in
            activity.add(details)
            let pixels = XCTAttachment(data: XCUIScreen.main.screenshot().pngRepresentation, uniformTypeIdentifier: "public.png")
            pixels.name = "FailedNativeMenu-OriginalDisplay"; pixels.lifetime = .keepAlways; activity.add(pixels)
        }
        XCTFail("The real native menu item must be visible and hittable before tapping", file: file, line: line); return
    }
    item.tap()
    // UIKit can report app idle while its context menu is still dismissing.
    // A following tap would hit that menu's backdrop instead of the next tool.
    waitForNativeDismissal(of: item, file: file, line: line)
}
