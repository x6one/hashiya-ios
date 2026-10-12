import XCTest
import PencilKit
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

