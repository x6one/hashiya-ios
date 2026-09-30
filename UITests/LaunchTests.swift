import XCTest

final class LaunchTests: XCTestCase {
    func testLibraryLaunchAndDocumentOpen() {
        let app = XCUIApplication()
        app.launch()
        let opening = app.otherElements["openingAnimation"]
        _ = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: opening)], timeout: 5)
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

    func testOfficePreviewAndEmbeddedMedia() {
        let app = XCUIApplication()
        app.launch()
        let opening = app.otherElements["openingAnimation"]
        _ = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: opening)], timeout: 5)
        app.buttons["libraryMenu"].tap()
        let importButton = app.buttons["importOfficeDemo"]
        XCTAssertTrue(importButton.waitForExistence(timeout: 15))
        importButton.tap()
        let card = app.staticTexts["تجربة Office"].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        card.tap()
        XCTAssertTrue(app.navigationBars["تجربة Office"].waitForExistence(timeout: 10))
        let media = app.buttons["officeMedia"]
        XCTAssertTrue(media.waitForExistence(timeout: 15))
        let loading = app.staticTexts["LOADING"]
        if loading.waitForExistence(timeout: 3) {
            let finished = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: loading)
            XCTAssertEqual(XCTWaiter.wait(for: [finished], timeout: 30), .completed)
        }
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = "OfficeAccessibility"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
        let preview = XCTAttachment(screenshot: app.screenshot())
        preview.name = "OfficePreview"
        preview.lifetime = .keepAlways
        add(preview)
        media.tap()
        let video = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", ".mp4")).firstMatch
        XCTAssertTrue(video.waitForExistence(timeout: 20))
        video.tap()
        let playback = XCTAttachment(screenshot: app.screenshot())
        playback.name = "EmbeddedVideo"
        playback.lifetime = .keepAlways
        add(playback)
    }
}
