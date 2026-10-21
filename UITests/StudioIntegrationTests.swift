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

    func testEnglishCoreToolsUseEnglishNamesAndKeepRealNotesData() {
        let app = openRealDocument(arguments: ["--test-english"])
        for (identifier, label) in [("inkTool", "Pen"), ("textTool", "Text"), ("selectTool", "Select"), ("openMargin", "Notes"), ("documentPages", "Pages")] {
            XCTAssertEqual(app.buttons[identifier].label, label, "English must translate display copy without changing action identifiers")
        }
        app.buttons["openMargin"].tap()
        let notes = app.textViews["splitNotes"]
        XCTAssertTrue(notes.waitForExistence(timeout: 10))
        XCTAssertTrue((notes.value as? String)?.contains("ملاحظة تجريبية") == true,
                      "Changing interface language must never translate or replace stored user content")
        keepScreenshot("Integrated-Editor-English")
    }

    func testAccessibilitySecondaryChromeStaysInsideItsReservedArea() {
        let app = openRealDocument(arguments: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        let rail = app.otherElements["studioContextRail"]
        XCTAssertTrue(rail.waitForExistence(timeout: 5))
        XCTAssertEqual(rail.frame.height, 44, accuracy: 1)
        for label in rail.staticTexts.allElementsBoundByIndex where label.exists {
            XCTAssertGreaterThanOrEqual(label.frame.minY, rail.frame.minY - 1, "Secondary instructions must not overlap the PDF")
            XCTAssertLessThanOrEqual(label.frame.maxY, rail.frame.maxY + 1)
        }
        for name in ["nextDocumentPage", "previousDocumentPage", "fitDocumentPage"] {
            XCTAssertLessThanOrEqual(app.buttons[name].frame.height, 64, "SF glyphs keep their visual size; full VoiceOver labels remain")
        }
        let help = app.buttons["workspaceToolHelp"]
        XCTAssertTrue(help.isHittable, "Full instructions remain reachable in a clear panel at accessibility sizes")
        help.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "اختر أداة")).firstMatch.exists)
        keepScreenshot("Integrated-Accessibility-Tool-Help")
    }

    private func keepScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
