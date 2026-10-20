import PDFKit
import PencilKit
import XCTest
@testable import TayyaStudio

final class StudioPolishTests: XCTestCase {
    func testPreviewDraftRoundTripsNotesDrawingAndThreeEditablePens() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("preview.json")
        let draft = StudioDraft(url: url)
        draft.state.notes = "ملاحظات محفوظة — Notes"
        let points = (0...3).map { index in
            PKStrokePoint(location: CGPoint(x: 12 + Double(index) * 10, y: 16 + Double(index) * 4), timeOffset: Double(index) / 10,
                          size: CGSize(width: 3, height: 3), opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
        }
        let drawing = PKDrawing(strokes: [PKStroke(ink: PKInk(.pen, color: .blue), path: PKStrokePath(controlPoints: points, creationDate: Date(timeIntervalSince1970: 0)))])
        draft.state.documentInk = drawing.dataRepresentation()
        draft.state.page = 12
        draft.savePen(at: 0, pen: StudioPenPreset(brush: "pencil", color: 0x68458A, width: 6))
        let saved = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in draft.status == "saved" }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [saved], timeout: 5), .completed, "status=\(draft.status) error=\(draft.lastSaveError ?? "none") fileExists=\(FileManager.default.fileExists(atPath: url.path)) main=\(Thread.isMainThread)")
        let restored = StudioDraft(url: url)
        XCTAssertEqual(restored.state.notes, "ملاحظات محفوظة — Notes")
        XCTAssertEqual(restored.state.page, 12)
        XCTAssertEqual(restored.state.documentInk, draft.state.documentInk)
        let restoredDrawing = try PKDrawing(data: restored.state.documentInk)
        XCTAssertEqual(restoredDrawing.strokes.count, 1, "Reopen must retain a nonempty native drawing")
        XCTAssertEqual(restoredDrawing.bounds, drawing.bounds)
        XCTAssertEqual(restored.state.pens.count, 3)
        XCTAssertEqual(restored.state.pens[0], StudioPenPreset(brush: "pencil", color: 0x68458A, width: 6))
        XCTAssertEqual(restored.state.pens[1], StudioDraftState().pens[1])
    }

    func testUnreadableDraftIsNeverSilentlyOverwritten() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("preview.json")
        let damaged = Data("preserve this unreadable draft".utf8)
        try damaged.write(to: url)
        let draft = StudioDraft(url: url)
        draft.state.notes = "new"
        XCTAssertEqual(draft.status, "failed")
        XCTAssertEqual(try Data(contentsOf: url), damaged)
    }

    func testDirectJumpValidatesArabicAndEnglishDigitsAndKeepsLastPage() {
        let session = StudioSession()
        XCTAssertFalse(session.jump(to: "25"))
        XCTAssertFalse(session.jump(to: "1.2"))
        XCTAssertFalse(session.jump(to: "-2"))
        XCTAssertEqual(session.page, 7)
        XCTAssertTrue(session.jump(to: "١٢"))
        XCTAssertEqual(session.page, 12)
        XCTAssertEqual(session.lastVisitedPage, 7)
        XCTAssertTrue(session.jump(to: "12"))
        XCTAssertEqual(session.lastVisitedPage, 7, "Staying on the same page must not destroy history")
    }

    @MainActor func testThumbnailsRenderActualContentCacheAndInvalidate() async throws {
        let first = samplePDF([.red, .blue])
        let store = StudioThumbnailStore(document: first)
        let firstImage = await store.image(page: 1)
        let one = try XCTUnwrap(firstImage)
        let secondImage = await store.image(page: 2)
        let two = try XCTUnwrap(secondImage)
        XCTAssertNotEqual(one.pngData(), two.pngData(), "Each image must contain that page's pixels")
        let cached = await store.image(page: 1)
        XCTAssertTrue(one === cached)
        let revision = store.revision
        store.replaceDocument(samplePDF([.green]))
        XCTAssertGreaterThan(store.revision, revision)
        let refreshedImage = await store.image(page: 1)
        let replacement = try XCTUnwrap(refreshedImage)
        XCTAssertNotEqual(one.pngData(), replacement.pngData())
        let removed = await store.image(page: 2)
        XCTAssertNil(removed, "Deleted page thumbnails cannot survive invalidation")
    }

    @MainActor func testPDFViewportSurvivesChromeAndNotesSizeChanges() throws {
        let controller = StudioPDFController()
        let view = controller.view
        let root = UIViewController()
        let (window, previous) = try studioTestWindow(root)
        defer { window.isHidden = true; previous?.makeKeyAndVisible() }
        root.view.addSubview(view)
        view.frame = CGRect(x: 0, y: 0, width: 700, height: 850)
        view.layoutIfNeeded()
        let page = try XCTUnwrap(view.document?.page(at: 6))
        view.go(to: PDFDestination(page: page, at: CGPoint(x: 120, y: 600)))
        view.scaleFactor = 1.75
        let scale = view.scaleFactor
        let point = view.convert(CGPoint(x: view.bounds.midX, y: 1), to: page)
        view.frame = CGRect(x: 0, y: 0, width: 480, height: 620)
        view.setNeedsLayout()
        view.layoutIfNeeded()
        XCTAssertTrue(view.currentPage === page)
        XCTAssertEqual(view.scaleFactor, scale, accuracy: 0.01)
        XCTAssertEqual(view.convert(CGPoint(x: view.bounds.midX, y: 1), to: page).y, point.y, accuracy: 3, "Preserve the visible reading line, not PDFKit currentDestination (the lower viewport edge)")
    }

    private func samplePDF(_ colors: [UIColor]) -> PDFDocument {
        let data = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 120, height: 180)).pdfData { context in
            for color in colors {
                context.beginPage()
                color.setFill()
                context.cgContext.fill(CGRect(x: 10, y: 10, width: 100, height: 160))
            }
        }
        return PDFDocument(data: data) ?? PDFDocument()
    }
}
