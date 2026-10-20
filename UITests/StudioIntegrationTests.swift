import XCTest
import UIKit

/// These tests launch the production executable and its existing real demo data.
/// They do not link DesignStudio or use its simulated recording/session models.
final class StudioIntegrationTests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func openRealDocument(arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--test-review-entry"] + arguments
        app.launch()
        let demonstration = app.buttons["welcomeDemonstration"]
        XCTAssertTrue(demonstration.waitForExistence(timeout: 15))
        demonstration.tap()
        XCTAssertTrue(app.buttons["inkTool"].waitForExistence(timeout: 15))
        return app
    }

    func testApprovedCoreDockAndFocusKeepRealDocumentPage() {
        let app = openRealDocument()
        for identifier in ["inkTool", "textTool", "selectTool", "openMargin", "documentPages", "focusToggle"] {
            let button = app.buttons[identifier]
            XCTAssertTrue(button.exists, "Approved production control: " + identifier)
            XCTAssertTrue(button.isHittable, "Core controls must be directly reachable: " + identifier)
            XCTAssertGreaterThanOrEqual(button.frame.height, 44)
            XCTAssertGreaterThanOrEqual(button.frame.width, 44)
        }
        app.buttons["nextDocumentPage"].tap()
        XCTAssertEqual(app.textFields["pageNumber"].value as? String, "2")
        app.buttons["focusToggle"].tap()
        XCTAssertEqual(app.buttons["focusToggle"].value as? String, "focused")
        XCTAssertTrue(app.otherElements["pdfCanvas"].exists)
        XCTAssertFalse(app.buttons["textTool"].exists)
        app.buttons["focusToggle"].tap()
        XCTAssertEqual(app.textFields["pageNumber"].value as? String, "2", "Focus must preserve the reading page")
        XCTAssertTrue(app.buttons["textTool"].isHittable)
        keepScreenshot("Integrated-Editor-Arabic")
    }

    func testNotesNameAndExistingContentSurviveExpandedPresentation() {
        let app = openRealDocument()
        XCTAssertEqual(app.buttons["openMargin"].label, "الملاحظات")
        app.buttons["openMargin"].tap()
        let text = app.textViews["splitNotes"]
        XCTAssertTrue(text.waitForExistence(timeout: 10))
        XCTAssertTrue((text.value as? String)?.contains("ملاحظة تجريبية") == true)
        XCTAssertTrue(app.buttons["expandMargin"].isHittable)
        app.buttons["expandMargin"].tap()
        XCTAssertTrue(text.waitForExistence(timeout: 10))
        XCTAssertTrue((text.value as? String)?.contains("ملاحظة تجريبية") == true)
        keepScreenshot("Integrated-Notes-Existing-Data")
    }

    func testLargeTextCoreControlsRemainReachableAfterRotation() {
        let app = openRealDocument(arguments: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        defer { XCUIDevice.shared.orientation = .portrait }
        for orientation in [UIDeviceOrientation.portrait, .landscapeLeft] {
            XCUIDevice.shared.orientation = orientation
            let oriented = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                let frame = app.windows.firstMatch.frame
                return frame.width > 0 && (orientation == .portrait ? frame.height > frame.width : frame.width > frame.height)
            }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [oriented], timeout: 10), .completed)
            let focus = app.buttons["focusToggle"]
            XCTAssertTrue(focus.waitForExistence(timeout: 10))
            if focus.value as? String == "focused" { focus.tap() }
            let dock = app.scrollViews["studioToolDock"]
            XCTAssertTrue(dock.waitForExistence(timeout: 10))
            XCTAssertTrue(app.buttons["inkTool"].exists)
            XCTAssertTrue(app.buttons["openMargin"].exists)
            XCTAssertEqual(app.buttons["openMargin"].label, "الملاحظات")
            XCTAssertGreaterThanOrEqual(app.buttons["inkTool"].frame.height, 44)
            XCTAssertGreaterThan(app.otherElements["pdfCanvas"].frame.height, 60)
            keepScreenshot("Integrated-Large-Text-\(orientation.rawValue)")
        }
    }

    private func keepScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
