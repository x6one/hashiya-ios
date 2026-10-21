import XCTest
import PDFKit
import PencilKit
@testable import Hashiya

final class StudioInkSafetyTests: XCTestCase {
    @MainActor func testUnreadableOldDrawingCannotBeReplacedByNewCanvasStrokeOrExportedAsBlank() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let library = LibraryStore(root: root, seedDemo: false); library.create("Old drawing")
        let note = try XCTUnwrap(library.notebooks.first)
        let folder = root.appendingPathComponent(note.id.uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let broken = Data("interrupted PencilKit drawing".utf8), url = folder.appendingPathComponent("0.drawing")
        try broken.write(to: url)
        let workspace = PDFWorkspace(note: note, root: root)
        XCTAssertNotNil(workspace.error, "Unreadable old ink must not be interpreted as an empty page")
        let coordinator = NativePDF.Coordinator(workspace: workspace)
        let canvas = try XCTUnwrap(coordinator.pdfView(PDFView(), overlayViewFor: try XCTUnwrap(workspace.document.page(at: 0))) as? LassoCanvas)
        XCTAssertFalse(canvas.isUserInteractionEnabled)
        coordinator.canvasViewDrawingDidChange(canvas)
        XCTAssertEqual(try Data(contentsOf: url), broken)
        workspace.export()
        XCTAssertNil(workspace.exported, "A clean-looking PDF with missing old ink is not a successful export")
        XCTAssertEqual(try Data(contentsOf: url), broken)
    }
}
