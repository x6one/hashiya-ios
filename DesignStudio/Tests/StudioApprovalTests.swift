import PDFKit
import XCTest
@testable import TayyaStudio

final class StudioApprovalTests: XCTestCase {
    @MainActor func testReinsertedEditedPageNeverReusesAnEarlierRenderKey() throws {
        let document = StudioPDF.make()
        let page = try XCTUnwrap(document.page(at: 0))
        let store = StudioThumbnailStore(document: document)
        let original = store.imageKey(page: 1)
        let annotation = PDFAnnotation(bounds: CGRect(x: 20, y: 20, width: 100, height: 50), forType: .freeText, withProperties: nil)
        annotation.contents = "Edited before reinsertion"
        page.addAnnotation(annotation)
        store.replaceDocument(document, changedPages: [1])
        let edited = store.imageKey(page: 1)
        XCTAssertNotEqual(original, edited)
        document.removePage(at: 0)
        store.replaceDocument(document)
        document.insert(page, at: 0)
        store.replaceDocument(document)
        let reinserted = store.imageKey(page: 1)
        XCTAssertNotEqual(reinserted, original, "A still-pending pre-edit render must never match a reinserted page")
        XCTAssertNotEqual(reinserted, edited, "Reinsertion starts a new cache incarnation")
    }

    @MainActor func testReviewPDFContainsDistinctTextTableImageInkAndBlankPages() async throws {
        let document = StudioPDF.make()
        XCTAssertEqual(document.pageCount, 24)
        for index in 0..<5 {
            print("StudioReviewPDFPage\(index + 1)=\((document.page(at: index)?.string ?? "").debugDescription)")
        }
        XCTAssertTrue(document.page(at: 0)?.string?.contains("مبادئ المحاسبة") == true)
        XCTAssertTrue(document.page(at: 1)?.string?.contains("ميزان المراجعة") == true)
        XCTAssertTrue(document.page(at: 2)?.string?.contains("صورة توضيحية") == true)
        XCTAssertTrue(document.page(at: 3)?.annotations.contains(where: { $0.type == "Ink" }) == true)
        XCTAssertLessThan(document.page(at: 4)?.string?.trimmingCharacters(in: .whitespacesAndNewlines).count ?? 100, 10)
        let store = StudioThumbnailStore(document: document)
        var pixels = Set<Data>()
        for page in 1...5 {
            let image = await store.image(page: page)
            pixels.insert(try XCTUnwrap(image?.pngData()))
        }
        XCTAssertEqual(pixels.count, 5)
        let attachment = XCTAttachment(data: try XCTUnwrap(document.dataRepresentation()), uniformTypeIdentifier: "com.adobe.pdf")
        attachment.name = "Studio-Diverse-Native-PDF"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor func testEditingOnePageKeepsOtherThumbnailImage() async throws {
        let controller = StudioPDFController()
        let store = controller.thumbnails
        let unchanged = await store.image(page: 2)
        let edited = await store.image(page: 1)
        controller.updateText("Edited page one", size: 24, color: 0x244C43, alignment: 2, page: 1)
        let afterUnchanged = await store.image(page: 2)
        let afterEdited = await store.image(page: 1)
        XCTAssertNotNil(unchanged)
        XCTAssertTrue(unchanged === afterUnchanged, "Editing page1 must retain page2's cached native image")
        XCTAssertNotEqual(edited?.pngData(), afterEdited?.pngData(), "Edited page must refresh")
    }

    @MainActor func testPageInsertionAndDeletionKeepUnaffectedThumbnailIdentity() async throws {
        let document = StudioPDF.make()
        let store = StudioThumbnailStore(document: document)
        let original = await store.image(page: 2)
        let blank = try XCTUnwrap(PDFPage(image: UIGraphicsImageRenderer(size: CGSize(width: 120, height: 180)).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 120, height: 180))
        }))
        document.insert(blank, at: 0)
        store.replaceDocument(document)
        let shifted = await store.image(page: 3)
        XCTAssertNotNil(original)
        XCTAssertTrue(original === shifted, "Insertion must preserve cached content by page identity, not index")
        document.removePage(at: 0)
        store.replaceDocument(document)
        let restored = await store.image(page: 2)
        XCTAssertTrue(original === restored)
        XCTAssertEqual(store.pageCount, 24)
    }

    @MainActor func testConcurrentLargeDocumentThumbnailRequestsShareOneImage() async throws {
        let data = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 120, height: 180)).pdfData { context in
            for page in 1...240 {
                context.beginPage()
                ("Page \(page)" as NSString).draw(at: CGPoint(x: 8, y: 12), withAttributes: [.font: UIFont.systemFont(ofSize: 14)])
            }
        }
        let store = StudioThumbnailStore(document: try XCTUnwrap(PDFDocument(data: data)))
        async let first = store.image(page: 120)
        async let second = store.image(page: 120)
        let (one, two) = await (first, second)
        XCTAssertNotNil(one)
        XCTAssertTrue(one === two, "Concurrent requests must coalesce, not render the same page twice")
        let last = await store.image(page: 240)
        XCTAssertNotNil(last)
        let beyond = await store.image(page: 241)
        XCTAssertNil(beyond)
    }
}
