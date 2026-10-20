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
        let extracted = pdf.page(at: 6)?.string ?? ""
        let text = XCTAttachment(string: extracted)
        text.name = "Actual-PDFKit-Arabic-extraction"; text.lifetime = .keepAlways; add(text)
        let data = XCTAttachment(data: pdf.dataRepresentation() ?? Data(), uniformTypeIdentifier: "com.adobe.pdf")
        data.name = "Actual-Studio-study-PDF"; data.lifetime = .keepAlways; add(data)
        // PDFKit may expose RTL glyph order, compatibility forms or omit spaces.
        // Keep the full required title letters; do not accept arbitrary Arabic text.
        let actual = extracted.precomposedStringWithCompatibilityMapping.filter { $0.isLetter }
        let expected = "مبادئ المحاسبة".precomposedStringWithCompatibilityMapping.filter { $0.isLetter }
        print("StudioActualPDFKitText=\(extracted.debugDescription)")
        XCTAssertTrue(actual.contains(expected) || String(actual.reversed()).contains(expected), "Full title must remain extractable: \(extracted.debugDescription)")
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
        let shifts: [Int] = [16, 8, 0]
        let weights: [Double] = [0.2126, 0.7152, 0.0722]
        var result: Double = 0
        for index in 0..<3 {
            let channel = Double((hex >> shifts[index]) & 255) / 255.0
            let linear: Double = channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
            result += linear * weights[index]
        }
        return result
    }
}
