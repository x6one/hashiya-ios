import XCTest
import Vision
@testable import Hashiya

final class OCRCapabilityTests: XCTestCase {
    func testChoicesMatchActualAccurateRecognitionSupport() throws {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        XCTAssertEqual(Set(try LibrarySearch.supportedRecognitionLanguages()), Set(try request.supportedRecognitionLanguages()))
    }

    func testUnsupportedLanguageIsRejectedBeforeOpeningDocument() {
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        XCTAssertThrowsError(try LibrarySearch.recognize(file: missing, cache: missing, language: "unsupported-language")) { error in
            XCTAssertEqual((error as NSError).domain, "TayyaOCR")
            XCTAssertEqual((error as NSError).code, 1)
        }
    }
}
