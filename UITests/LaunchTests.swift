import XCTest

final class LaunchTests: XCTestCase {
    func testLibraryLaunchAndDocumentOpen() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.navigationBars["حاشية"].waitForExistence(timeout: 15))
        let demo = app.staticTexts["ملف التجربة"].firstMatch
        XCTAssertTrue(demo.waitForExistence(timeout: 10))
        let library = XCTAttachment(screenshot: app.screenshot())
        library.name = "Library"
        library.lifetime = .keepAlways
        add(library)
        demo.tap()
        XCTAssertTrue(app.navigationBars["ملف التجربة"].waitForExistence(timeout: 10))
        let document = XCTAttachment(screenshot: app.screenshot())
        document.name = "Document"
        document.lifetime = .keepAlways
        add(document)
    }
}
