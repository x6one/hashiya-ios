import XCTest
import UIKit

final class StudioEditorToolsTests: XCTestCase {
    override func setUp() { super.setUp(); continueAfterFailure = false }
    private func openDocument(arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication(); app.launchArguments = ["--test-review-entry"] + arguments
        app.launch()
        XCTAssertTrue(app.buttons["welcomeDemonstration"].waitForExistence(timeout: 15))
        app.buttons["welcomeDemonstration"].tap()
        XCTAssertTrue(app.buttons["inkTool"].waitForExistence(timeout: 15))
        return app
    }
    private func chooseBrush(_ name: String, in app: XCUIApplication) {
        app.buttons["inkBrush"].tap()
        tapReadyMenuItem(app.buttons[name])
    }
    private func tapReadyMenuItem(_ item: XCUIElement) {
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND hittable == true"), object: item)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed, "Wait for the native menu to finish presenting before a real tap")
        item.tap()
    }
    func testFavoritePenUsesNativeBindingsAndSurvivesAppRelaunch() {
        let app = openDocument()
        app.buttons["inkTool"].tap()
        chooseBrush("رصاص", in: app)
        app.buttons["inkWidth"].tap(); tapReadyMenuItem(app.buttons["سماكة 5"])
        let color = app.buttons["inkColor"].value as? String
        XCTAssertNotNil(color)
        app.buttons["favoritePens"].tap(); tapReadyMenuItem(app.buttons["savePenPreset-1"])
        chooseBrush("تظليل", in: app)
        app.buttons["favoritePens"].tap(); tapReadyMenuItem(app.buttons["usePenPreset-1"])
        XCTAssertEqual(app.buttons["inkBrush"].value as? String, "رصاص")
        XCTAssertEqual(app.buttons["inkWidth"].value as? String, "5")
        XCTAssertEqual(app.buttons["inkColor"].value as? String, color)
        app.buttons["textTool"].tap(); app.buttons["inkTool"].tap()
        XCTAssertEqual(app.buttons["inkBrush"].value as? String, "رصاص")
        app.terminate()
        let reopened = openDocument()
        reopened.buttons["inkTool"].tap()
        reopened.buttons["favoritePens"].tap(); tapReadyMenuItem(reopened.buttons["usePenPreset-1"])
        XCTAssertEqual(reopened.buttons["inkBrush"].value as? String, "رصاص")
        XCTAssertEqual(reopened.buttons["inkWidth"].value as? String, "5")
        XCTAssertEqual(reopened.buttons["inkColor"].value as? String, color)
    }
    func testActualPagePreviewsNavigateAndSidebarTogglePreservesCurrentPage() {
        let app = openDocument()
        app.buttons["documentPages"].tap()
        for number in [1, 2, 3] {
            let image = app.images["pagePreview-\(number)"]
            XCTAssertTrue(image.waitForExistence(timeout: 10))
            XCTAssertEqual(image.value as? String, "rendered")
        }
        app.buttons["openDocumentPage-2"].tap()
        XCTAssertTrue(app.textFields["pageNumber"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["pageNumber"].value as? String, "2")
        let sidebar = app.buttons["togglePageSidebar"]
        if UIDevice.current.userInterfaceIdiom == .pad {
            XCTAssertTrue(sidebar.exists, "iPad must expose its real page sidebar")
            sidebar.tap(); sidebar.tap()
            XCTAssertEqual(app.textFields["pageNumber"].value as? String, "2")
            XCTAssertTrue(app.descendants(matching: .any)["documentPageSidebar"].firstMatch.exists)
        } else { XCTAssertFalse(sidebar.exists, "iPhone page navigation uses the adaptive page panel") }
    }
    func testLargestInkToolsKeepFullTouchTargetsInsideTheirReservedRow() {
        let app = openDocument(arguments: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        app.buttons["inkTool"].tap()
        for name in ["inkBrush", "inkColor", "inkWidth", "inkUndo", "inkRedo"] {
            let button = app.buttons[name]
            XCTAssertTrue(button.waitForExistence(timeout: 5))
            XCTAssertTrue(button.isHittable)
            XCTAssertGreaterThanOrEqual(button.frame.width, 44)
            XCTAssertGreaterThanOrEqual(button.frame.height, 44)
            XCTAssertLessThanOrEqual(button.frame.height, 45, "Glyphs must not overflow the actual reserved44-point contextual row")
            XCTAssertGreaterThanOrEqual(button.frame.minY, app.otherElements["pdfCanvas"].frame.maxY - 1)
        }
    }
}
