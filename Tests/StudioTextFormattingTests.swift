import XCTest
import PDFKit
@testable import Hashiya

final class StudioTextFormattingTests: XCTestCase {
    @MainActor func testNativeTextAlignmentSizeAndColorPersistAndExportWithoutChangingLegacyText() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let library = LibraryStore(root: root, seedDemo: false); library.create("Formatted study")
        let note = try XCTUnwrap(library.notebooks.first), workspace = PDFWorkspace(note: note, root: root)
        let old = Data("[{\"id\":\"\(UUID())\",\"page\":0,\"text\":\"Old text\",\"x\":10,\"y\":20,\"width\":220,\"height\":80,\"size\":16,\"font\":\"Arial\",\"red\":0.1,\"green\":0.2,\"blue\":0.3}]".utf8)
        try old.write(to: workspace.textURL)
        let legacy = PDFWorkspace(note: note, root: root)
        XCTAssertNil(legacy.texts.first?.alignment)
        XCTAssertEqual(try Data(contentsOf: workspace.textURL), old, "Opening must not migrate or rewrite old text bytes")
        var text = PageText(page: 0, text: "ملاحظات الدراسة", x: 30, y: 140)
        text.size = 28; text.red = 0.7; text.green = 0.1; text.blue = 0.2
        text.alignment = NSTextAlignment.right.rawValue
        legacy.saveText(text)
        let reopened = PDFWorkspace(note: note, root: root)
        XCTAssertEqual(reopened.texts.count, 2)
        XCTAssertEqual(reopened.texts.first?.text, "Old text")
        let annotation = try XCTUnwrap(reopened.document.page(at: 0)?.annotations.first { $0.userName == text.id.uuidString })
        XCTAssertEqual(annotation.alignment, .right)
        XCTAssertEqual(annotation.font?.pointSize, 28)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        XCTAssertTrue(try XCTUnwrap(annotation.fontColor).getRed(&red, green: &green, blue: &blue, alpha: &alpha))
        XCTAssertEqual(red, 0.7, accuracy: 0.001)
        reopened.export()
        let exported = try XCTUnwrap(reopened.exported)
        defer { try? FileManager.default.removeItem(at: exported) }
        let pdf = try XCTUnwrap(PDFDocument(url: exported))
        XCTAssertEqual(pdf.pageCount, 1)
        let image = try XCTUnwrap(pdf.page(at: 0)?.thumbnail(of: CGSize(width: 600, height: 850), for: .mediaBox).cgImage)
        var rgba = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let redPixels = try rgba.withUnsafeMutableBytes { buffer -> Int in
            let context = try XCTUnwrap(CGContext(data: buffer.baseAddress, width: image.width, height: image.height,
                bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
            context.draw(image, in: CGRect(x: 0, y: 0, width: CGFloat(image.width), height: CGFloat(image.height)))
            let bytes = buffer.bindMemory(to: UInt8.self)
            var count = 0
            for index in stride(from: 0, to: bytes.count, by: 4) {
                let pixelRed = Int(bytes[index])
                let pixelGreen = Int(bytes[index + 1])
                let pixelBlue = Int(bytes[index + 2])
                if pixelRed > 60 && pixelRed > pixelGreen * 2 && pixelRed > pixelBlue * 2 {
                    count += 1
                }
            }
            return count
        }
        XCTAssertGreaterThan(redPixels, 25, "Real exported PDF must visibly contain the newly formatted red text")
        XCTAssertEqual(reopened.texts.last?.alignment, NSTextAlignment.right.rawValue)
    }
}
