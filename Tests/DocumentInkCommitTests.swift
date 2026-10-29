import XCTest
import PencilKit
import PDFKit
@testable import Hashiya

final class DocumentInkCommitTests: XCTestCase {
    private func ink(_ offset: CGFloat = 0) -> PKDrawing {
        let points = [CGPoint(x: 30 + offset, y: 40), CGPoint(x: 160 + offset, y: 100)].map {
            PKStrokePoint(location: $0, timeOffset: 0, size: CGSize(width: 4, height: 4),
                          opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
        }
        return PKDrawing(strokes: [PKStroke(ink: PKInk(.pen, color: .black),
            path: PKStrokePath(controlPoints: points, creationDate: Date()))])
    }

    @MainActor func testPinkPencilStrokeRetainsPointDataAfterDocumentDiskReload() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let library = LibraryStore(root: root, seedDemo: false); library.create("Pink pencil reload")
        let note = try XCTUnwrap(library.notebooks.first)
        let points = [
            PKStrokePoint(location: CGPoint(x: 30, y: 40), timeOffset: 0,
                size: CGSize(width: 8, height: 8), opacity: 1, force: 0.75, azimuth: 0, altitude: .pi / 2),
            PKStrokePoint(location: CGPoint(x: 160, y: 100), timeOffset: 0.25,
                size: CGSize(width: 8, height: 8), opacity: 1, force: 0.75, azimuth: 0, altitude: .pi / 2)
        ]
        let pink = UIColor(red: 1, green: 0.71, blue: 0.69, alpha: 1)
        let original = PKDrawing(strokes: [PKStroke(ink: PKInk(.pencil, color: pink),
            path: PKStrokePath(controlPoints: points, creationDate: Date(timeIntervalSince1970: 1_700_000_000)))])
        do {
            let workspace = PDFWorkspace(note: note, root: root)
            let coordinator = NativePDF.Coordinator(workspace: workspace)
            let canvas = LassoCanvas(frame: CGRect(x: 0, y: 0, width: 650, height: 900))
            canvas.tag = 0; coordinator.canvases[0] = canvas
            coordinator.canvasViewDidBeginUsingTool(canvas)
            canvas.drawing = original
            coordinator.canvasViewDrawingDidChange(canvas)
            coordinator.canvasViewDidEndUsingTool(canvas)
            XCTAssertNil(workspace.error)
        }
        let reopened = PDFWorkspace(note: note, root: root)
        let coordinator = NativePDF.Coordinator(workspace: reopened)
        let page = try XCTUnwrap(reopened.document.page(at: 0))
        let canvas = try XCTUnwrap(coordinator.pdfView(PDFView(), overlayViewFor: page) as? LassoCanvas)
        let restored = canvas.drawing
        XCTAssertEqual(restored.strokes.count, 1)
        let stroke = try XCTUnwrap(restored.strokes.first)
        XCTAssertEqual(stroke.ink.inkType, .pencil)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        XCTAssertTrue(stroke.ink.color.getRed(&red, green: &green, blue: &blue, alpha: &alpha))
        XCTAssertEqual(red, 1, accuracy: 0.001)
        XCTAssertEqual(green, 0.71, accuracy: 0.001)
        XCTAssertEqual(blue, 0.69, accuracy: 0.001)
        XCTAssertEqual(alpha, 1, accuracy: 0.001)
        XCTAssertEqual(stroke.transform, .identity)
        XCTAssertEqual(stroke.path.count, 2)
        guard stroke.path.count == 2 else { return }
        XCTAssertEqual(stroke.path[0].location, CGPoint(x: 30, y: 40))
        XCTAssertEqual(stroke.path[1].location, CGPoint(x: 160, y: 100))
        XCTAssertEqual(stroke.path[0].timeOffset, 0, accuracy: 0.001)
        XCTAssertEqual(stroke.path[1].timeOffset, 0.25, accuracy: 0.001)
        for point in stroke.path {
            XCTAssertEqual(point.size.width, 8, accuracy: 0.001)
            XCTAssertEqual(point.size.height, 8, accuracy: 0.001)
            XCTAssertEqual(point.opacity, 1, accuracy: 0.001)
            XCTAssertEqual(point.force, 0.75, accuracy: 0.001)
            XCTAssertEqual(point.azimuth, 0, accuracy: 0.001)
            XCTAssertEqual(point.altitude, .pi / 2, accuracy: 0.001)
        }
    }

    @MainActor func testDocumentStrokeCommitsLatestInkOnlyAfterToolEnds() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let library = LibraryStore(root: root, seedDemo: false); library.create("Ink commit")
        let note = try XCTUnwrap(library.notebooks.first)
        let workspace = PDFWorkspace(note: note, root: root)
        let coordinator = NativePDF.Coordinator(workspace: workspace)
        let canvas = LassoCanvas(frame: CGRect(x: 0, y: 0, width: 650, height: 900))
        canvas.tag = 0; coordinator.canvases[0] = canvas
        let path = workspace.storage.appendingPathComponent("0.drawing")
        let previous = ink().dataRepresentation(); try previous.write(to: path)
        var links = 0; workspace.onInkSaved = { _, _ in links += 1 }
        let delegate: PKCanvasViewDelegate = coordinator
        delegate.canvasViewDidBeginUsingTool?(canvas)
        for offset: CGFloat in [10, 20, 30] {
            canvas.drawing = ink(offset)
            coordinator.canvasViewDrawingDidChange(canvas)
            XCTAssertEqual(try Data(contentsOf: path), previous, "Never serialize/write live drawing frames")
            XCTAssertEqual(links, 0, "Audio links are created for completed strokes")
        }
        delegate.canvasViewDidEndUsingTool?(canvas)
        XCTAssertEqual(try Data(contentsOf: path), canvas.drawing.dataRepresentation())
        XCTAssertEqual(links, 1)
        XCTAssertEqual(workspace.inkStrokeCount, 1)
    }

    @MainActor func testDocumentUndoAndEraseOutsideStrokePersistImmediately() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let library = LibraryStore(root: root, seedDemo: false); library.create("Undo")
        let workspace = PDFWorkspace(note: try XCTUnwrap(library.notebooks.first), root: root)
        let coordinator = NativePDF.Coordinator(workspace: workspace)
        let canvas = LassoCanvas(frame: .zero); canvas.tag = 0
        canvas.drawing = ink(); coordinator.canvasViewDrawingDidChange(canvas)
        let path = workspace.storage.appendingPathComponent("0.drawing")
        XCTAssertEqual(try PKDrawing(data: Data(contentsOf: path)).strokes.count, 1)
        canvas.drawing = PKDrawing(); coordinator.canvasViewDrawingDidChange(canvas)
        XCTAssertTrue(try PKDrawing(data: Data(contentsOf: path)).strokes.isEmpty)
        XCTAssertEqual(workspace.inkStrokeCount, 0)
    }
}

