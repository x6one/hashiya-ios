import UIKit
import XCTest
@testable import TayyaStudio

final class StudioVisualContractTests: XCTestCase {
    func testSFSymbolsResolveInActualRuntime() {
        let more = ["book.closed.fill", "book.closed", "chart.bar.xaxis", "building.columns", "function", "sparkles", "link", "eye", "clock", "checkmark.circle", "record.circle.fill", "square.and.arrow.down"]
        for name in StudioTheme.symbols + more { XCTAssertNotNil(UIImage(systemName: name), name) }
    }

    func testPreviewPDFContainsRealSelectableContentAndAllPages() {
        let pdf = StudioPDF.make()
        XCTAssertEqual(pdf.pageCount, 24)
        XCTAssertTrue(pdf.page(at: 6)?.string?.contains("مبادئ المحاسبة") == true)
        XCTAssertGreaterThan(pdf.dataRepresentation()?.count ?? 0, 1000)
    }

    func testSemanticTextAndActionColorsMeetAAContrast() {
        let pairs = [(0x282C2B, 0xF8F7F3), (0x5E6963, 0xFFFFFF), (0xFFFFFF, 0x244C43),
                     (0xF1F3EE, 0x202C27), (0xB0BDB5, 0x202C27), (0x151E1B, 0xB9D8C9),
                     (0xFFFFFF, 0x416B5D), (0xFFFFFF, 0x886347), (0xFFFFFF, 0x486574), (0xFFFFFF, 0x646A49)]
        for (foreground, background) in pairs {
            let low = min(luminance(foreground), luminance(background))
            let high = max(luminance(foreground), luminance(background))
            XCTAssertGreaterThanOrEqual((high + 0.05) / (low + 0.05), 4.5)
        }
    }

    private func luminance(_ hex: Int) -> Double {
        let channels = [16, 8, 0].map { Double((hex >> $0) & 255) / 255 }
            .map { $0 <= 0.04045 ? $0 / 12.92 : pow(($0 + 0.055) / 1.055, 2.4) }
        return zip(channels, [0.2126, 0.7152, 0.0722]).reduce(0) { $0 + $1.0 * $1.1 }
    }
}
