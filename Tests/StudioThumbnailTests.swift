import XCTest
import PDFKit
import PencilKit
@testable import Hashiya

final class StudioThumbnailTests: XCTestCase {
    @MainActor func testDistinctRealPagesAndSeparatePencilKitInkRenderCorrectly() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let document = try XCTUnwrap(PDFDocument(data: fixture()))
        let store = DocumentThumbnailStore(document: document, inkFolder: root)
        var images: [Data] = []
        for number in 1...5 {
            let image = await store.image(page: number)
            images.append(try XCTUnwrap(image?.pngData()))
        }
        XCTAssertNotEqual(images[0], images[1], "Text and table must show distinct real PDF content")
        XCTAssertNotEqual(images[1], images[2], "The image page must not reuse a table thumbnail")
        XCTAssertEqual(images[3], images[4], "The last two fixture pages start identically blank")
        let otherKey = store.imageKey(page: 5)
        try drawing().dataRepresentation().write(to: root.appendingPathComponent("3.drawing"))
        store.invalidate(page: 4)
        let annotated = await store.image(page: 4)
        XCTAssertNotEqual(try XCTUnwrap(annotated?.pngData()), images[3], "PencilKit sidecar ink must appear, not merely PDFKit annotations")
        XCTAssertEqual(store.imageKey(page: 5), otherKey, "Editing one page must leave unrelated cache entries valid")
        XCTAssertEqual(store.renderCount, 6)
        XCTAssertNil(store.error)
    }
    @MainActor func testLargeDocumentRendersLazilyCoalescesRequestsAndKeepsUnaffectedCache() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let document = try XCTUnwrap(PDFDocument(data: fixture(count: 250)))
        let store = DocumentThumbnailStore(document: document, inkFolder: root)
        XCTAssertEqual(store.renderCount, 0, "Constructing a store must not rasterize a whole document")
        let first = Task { await store.image(page: 200) }
        let concurrent = Task { await store.image(page: 200) }
        let a = await first.value, b = await concurrent.value
        XCTAssertEqual(try XCTUnwrap(a?.pngData()), try XCTUnwrap(b?.pngData()))
        XCTAssertEqual(store.renderCount, 1, "Visible requests for the same real page share one render")
        let key = store.imageKey(page: 200)
        store.invalidate(page: 2)
        let cached = await store.image(page: 200)
        XCTAssertEqual(cached?.pngData(), a?.pngData())
        XCTAssertEqual(store.renderCount, 1)
        XCTAssertEqual(store.imageKey(page: 200), key)
        XCTAssertEqual(store.cacheCountLimit, 80); XCTAssertEqual(store.cacheByteLimit, 24 * 1024 * 1024)
    }
    @MainActor func testInsertionRemovalAndDamagedInkNeverReturnWrongPageOrBlankSuccess() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let document = try XCTUnwrap(PDFDocument(data: fixture()))
        let store = DocumentThumbnailStore(document: document, inkFolder: root)
        let tableKey = store.imageKey(page: 2), table = await store.image(page: 2)
        let textKey = store.imageKey(page: 1)
        document.removePage(at: 0)
        store.synchronize(document, changedPages: [])
        XCTAssertEqual(store.imageKey(page: 1), tableKey, "The page object retains its own content after renumbering")
        XCTAssertNotEqual(store.imageKey(page: 1), textKey)
        let renumbered = await store.image(page: 1)
        XCTAssertEqual(renumbered?.pngData(), table?.pngData())
        let newPage = try XCTUnwrap(PDFDocument(data: PaperTemplate.dots.render(color: .cream))?.page(at: 0))
        document.insert(newPage, at: document.pageCount)
        store.synchronize(document, changedPages: [])
        XCTAssertEqual(store.pageCount, 5)
        let added = await store.image(page: 5)
        XCTAssertNotNil(added)
        let broken = Data("damaged user ink".utf8)
        try broken.write(to: root.appendingPathComponent("4.drawing"))
        for data in [broken, Data("interrupted PencilKit drawing".utf8), PKDrawing().dataRepresentation()] {
            do {
                let decoded = try PKDrawing(data: data)
                print("NativeInkDecode bytes=\(data.count) strokes=\(decoded.strokes.count) serialized=\(decoded.dataRepresentation().count)")
            } catch { print("NativeInkDecode bytes=\(data.count) throws=\(error)") }
        }
        let beforeKey = store.imageKey(page: 5)
        store.invalidate(page: 5)
        print("NativeThumbnailInvalidation keyChanged=\(beforeKey != store.imageKey(page: 5)) inkExists=\(FileManager.default.fileExists(atPath: root.appendingPathComponent("4.drawing").path))")
        let failed = await store.image(page: 5)
        XCTAssertNil(failed, "Unreadable ink must show a retry/error, not a falsely clean page")
        XCTAssertNotNil(store.error)
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("4.drawing")), broken)
    }
    private func fixture(count: Int = 5) -> Data {
        let bounds = CGRect(x: 0, y: 0, width: 300, height: 420)
        return UIGraphicsPDFRenderer(bounds: bounds).pdfData { context in
            for number in 1...count {
                context.beginPage()
                UIColor.white.setFill(); context.cgContext.fill(bounds)
                if number == 1 {
                    ("Real PDF text\nA study page with readable content." as NSString)
                        .draw(in: bounds.insetBy(dx: 20, dy: 25), withAttributes: [.font: UIFont.systemFont(ofSize: 20), .foregroundColor: UIColor.black])
                } else if number == 2 {
                    UIColor.systemGreen.setStroke()
                    let path = UIBezierPath()
                    for row in 0...5 { path.move(to: CGPoint(x: 20, y: 30 + row * 40)); path.addLine(to: CGPoint(x: 280, y: 30 + row * 40)) }
                    for column in 0...3 { path.move(to: CGPoint(x: 20 + column * 86, y: 30)); path.addLine(to: CGPoint(x: 20 + column * 86, y: 230)) }
                    path.lineWidth = 3; path.stroke()
                } else if number == 3 {
                    let picture = UIGraphicsImageRenderer(size: CGSize(width: 180, height: 160)).image { _ in
                        UIColor.systemOrange.setFill(); UIBezierPath(ovalIn: CGRect(x: 10, y: 10, width: 140, height: 140)).fill()
                        UIColor.systemBlue.setFill(); UIBezierPath(rect: CGRect(x: 70, y: 50, width: 100, height: 90)).fill()
                    }
                    picture.draw(in: CGRect(x: 40, y: 60, width: 220, height: 200))
                } else if number > 5 {
                    let text = "Study page \(number)\n" + String(repeating: "Real multi-page PDF content.\n", count: 10)
                    (text as NSString).draw(in: bounds.insetBy(dx: 20, dy: 25), withAttributes: [.font: UIFont.systemFont(ofSize: 16), .foregroundColor: UIColor.black])
                }
            }
        }
    }
    private func drawing() -> PKDrawing {
        let points = [CGPoint(x: 20, y: 35), CGPoint(x: 260, y: 140)].enumerated().map { index, point in
            PKStrokePoint(location: point, timeOffset: Double(index) / 4, size: CGSize(width: 10, height: 10), opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
        }
        return PKDrawing(strokes: [PKStroke(ink: PKInk(.pen, color: .blue), path: PKStrokePath(controlPoints: points, creationDate: Date()))])
    }
}
