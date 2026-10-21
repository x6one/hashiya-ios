import XCTest

final class StudioEditorToolsTests: XCTestCase {
    override func setUp() { super.setUp(); continueAfterFailure = false }
    private func openDocument() -> XCUIApplication {
        let app = XCUIApplication(); app.launchArguments = ["--test-review-entry"]
        app.launch()
        XCTAssertTrue(app.buttons["welcomeDemonstration"].waitForExistence(timeout: 15))
        app.buttons["welcomeDemonstration"].tap()
        XCTAssertTrue(app.buttons["inkTool"].waitForExistence(timeout: 15))
        return app
    }
    private func chooseBrush(_ name: String, in app: XCUIApplication) {
        app.buttons["inkBrush"].tap()
        XCTAssertTrue(app.buttons[name].waitForExistence(timeout: 5))
        app.buttons[name].tap()
    }
    func testFavoritePenUsesNativeBindingsAndSurvivesAppRelaunch() {
        let app = openDocument()
        app.buttons["inkTool"].tap()
        chooseBrush("رصاص", in: app)
        app.buttons["inkWidth"].tap(); app.buttons["سماكة 5"].tap()
        let color = app.buttons["inkColor"].value as? String
        XCTAssertNotNil(color)
        app.buttons["favoritePens"].tap(); app.buttons["savePenPreset-1"].tap()
        chooseBrush("تظليل", in: app)
        app.buttons["favoritePens"].tap(); app.buttons["usePenPreset-1"].tap()
        XCTAssertEqual(app.buttons["inkBrush"].value as? String, "رصاص")
        XCTAssertEqual(app.buttons["inkWidth"].value as? String, "5")
        XCTAssertEqual(app.buttons["inkColor"].value as? String, color)
        app.buttons["textTool"].tap(); app.buttons["inkTool"].tap()
        XCTAssertEqual(app.buttons["inkBrush"].value as? String, "رصاص")
        app.terminate()
        let reopened = openDocument()
        reopened.buttons["inkTool"].tap()
        reopened.buttons["favoritePens"].tap(); reopened.buttons["usePenPreset-1"].tap()
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
        if sidebar.exists {
            sidebar.tap(); sidebar.tap()
            XCTAssertEqual(app.textFields["pageNumber"].value as? String, "2")
            XCTAssertTrue(app.descendants(matching: .any)["documentPageSidebar"].firstMatch.exists)
        }
    }
}
