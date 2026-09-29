import XCTest
import PDFKit
@testable import Hashiya

final class DocumentTests: XCTestCase {
    @MainActor func testBundledPDFIsReadable() throws {
        let bundle = Bundle(for: LibraryStore.self)
        let url = try XCTUnwrap(bundle.url(forResource: "english", withExtension: "pdf"))
        let document = try XCTUnwrap(PDFDocument(url: url))
        XCTAssertGreaterThan(document.pageCount, 0)
        let page = try XCTUnwrap(document.page(at: 0))
        XCTAssertGreaterThan(page.bounds(for: .mediaBox).width, 0)
    }
}
