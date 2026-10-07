import XCTest
import PencilKit
import PDFKit
@testable import Hashiya

final class MarginPageTests: XCTestCase {
    func directory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true); return url
    }
    func ink() -> PKDrawing {
        let points = [CGPoint(x: 45, y: 65), CGPoint(x: 605, y: 850)].enumerated().map { index, point in
            PKStrokePoint(location: point, timeOffset: Double(index), size: CGSize(width: 4, height: 4), opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
        }
        return PKDrawing(strokes: [PKStroke(ink: PKInk(.pen, color: .black), path: PKStrokePath(controlPoints: points, creationDate: Date()))])
    }
    @MainActor func testLegacyMigrationKeepsOriginalBytesAndPageContentAcrossRelaunch() throws {
        let root = try directory(), id = UUID(); defer { try? FileManager.default.removeItem(at: root) }
        let originalText = "حاشية قديمة\nآخر سطر", drawing = ink().dataRepresentation()
        let textURL = root.appendingPathComponent(id.uuidString + "-margin.txt")
        let inkURL = root.appendingPathComponent(id.uuidString + "-margin.drawing")
        try originalText.write(to: textURL, atomically: true, encoding: .utf8); try drawing.write(to: inkURL)
        let store = MarginPages(root: root, notebook: id)
        XCTAssertNil(store.error); XCTAssertEqual(store.pages.count, 1)
        let first = try XCTUnwrap(store.currentID)
        XCTAssertEqual(store.current?.ink, drawing); XCTAssertEqual(store.current?.text, originalText)
        XCTAssertTrue(store.add(linkedTo: 5))
        let second = try XCTUnwrap(store.currentID)
        store.editText("الصفحة الثانية", page: second); store.saveInk(ink(), page: second)
        XCTAssertTrue(store.select(first)); XCTAssertEqual(store.current?.text, originalText)
        let reopened = MarginPages(root: root, notebook: id)
        XCTAssertEqual(reopened.pages.count, 2); XCTAssertEqual(reopened.currentID, first)
        XCTAssertTrue(reopened.select(second)); XCTAssertEqual(reopened.current?.sourcePage, 5)
        XCTAssertEqual(reopened.current?.text, "الصفحة الثانية")
        XCTAssertEqual(try PKDrawing(data: XCTUnwrap(reopened.current?.ink)).strokes.count, 1)
        XCTAssertEqual(try String(contentsOf: textURL), originalText); XCTAssertEqual(try Data(contentsOf: inkURL), drawing)
    }
    @MainActor func testFailedPageSaveBlocksNavigationAndCanBeRetriedWithoutLosingEdits() throws {
        let root = try directory(), id = UUID(); defer { try? FileManager.default.removeItem(at: root) }
        let store = MarginPages(root: root, notebook: id), first = try XCTUnwrap(store.currentID)
        XCTAssertTrue(store.add(linkedTo: 2)); let second = try XCTUnwrap(store.currentID)
        XCTAssertTrue(store.select(first))
        let path = store.folder.appendingPathComponent(first.uuidString + ".json")
        let original = try Data(contentsOf: path)
        try FileManager.default.removeItem(at: path); try FileManager.default.createDirectory(at: path, withIntermediateDirectories: false)
        store.editText("كتابة لم تُفقد", page: first)
        XCTAssertFalse(store.saved); XCTAssertFalse(store.select(second)); XCTAssertEqual(store.currentID, first)
        XCTAssertEqual(store.current?.text, "كتابة لم تُفقد")
        try FileManager.default.removeItem(at: path); try original.write(to: path)
        XCTAssertTrue(store.flush()); XCTAssertTrue(store.select(second))
        let reopened = MarginPages(root: root, notebook: id)
        XCTAssertTrue(reopened.select(first)); XCTAssertEqual(reopened.current?.text, "كتابة لم تُفقد")
    }
    @MainActor func testDamagedIndexIsNeverReplacedByAnEmptyNotebook() throws {
        let root = try directory(), id = UUID(); defer { try? FileManager.default.removeItem(at: root) }
        let folder = root.appendingPathComponent(id.uuidString + "-margins")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let index = folder.appendingPathComponent("index.json"), invalid = Data("damaged".utf8); try invalid.write(to: index)
        let store = MarginPages(root: root, notebook: id)
        XCTAssertNotNil(store.error); XCTAssertTrue(store.pages.isEmpty); XCTAssertFalse(store.add(linkedTo: 1))
        XCTAssertEqual(try Data(contentsOf: index), invalid)
    }
    @MainActor func testCanvasResizeAndFitNeverTransformOrClipStoredInk() {
        let canvas = MarginCanvas(frame: CGRect(x: 0, y: 0, width: 390, height: 300))
        canvas.sheetSize = CGSize(width: 650, height: 900); canvas.contentSize = canvas.sheetSize; canvas.drawing = ink()
        let original = canvas.drawing.dataRepresentation(), bounds = canvas.drawing.bounds
        for size in [CGSize(width: 250, height: 550), CGSize(width: 600, height: 180), CGSize(width: 390, height: 300)] {
            canvas.frame.size = size; canvas.layoutIfNeeded(); canvas.fitSheet()
            XCTAssertEqual(canvas.drawing.dataRepresentation(), original); XCTAssertEqual(canvas.drawing.bounds, bounds)
            XCTAssertEqual(canvas.sheetSize, CGSize(width: 650, height: 900))
            XCTAssertEqual(canvas.zoomScale, min(size.width / 650, size.height / 900), accuracy: 0.001)
            canvas.fitWidth()
            XCTAssertEqual(canvas.zoomScale, size.width / 650, accuracy: 0.001, "Split handwriting should stay legible even in a short pane")
            XCTAssertEqual(canvas.drawing.dataRepresentation(), original)
        }
    }
    @MainActor func testInkOutsideOriginalSheetRemainsReachableAfterSaveAndReopen() throws {
        let root = try directory(), id = UUID(); defer { try? FileManager.default.removeItem(at: root) }
        let store = MarginPages(root: root, notebook: id), page = try XCTUnwrap(store.currentID)
        let drawing = ink().transformed(using: CGAffineTransform(translationX: 600, y: 950))
        store.saveInk(drawing, page: page)
        let reopened = MarginPages(root: root, notebook: id), restored = try XCTUnwrap(reopened.current)
        XCTAssertGreaterThanOrEqual(restored.width, drawing.bounds.maxX)
        XCTAssertGreaterThanOrEqual(restored.height, drawing.bounds.maxY)
        XCTAssertEqual(try PKDrawing(data: restored.ink).bounds, drawing.bounds)
    }
    @MainActor func testBackupRestoresPagedInkTextAndCurrentSelectionWithNewNotebookID() async throws {
        let root = try directory(), targetRoot = try directory(); defer { try? FileManager.default.removeItem(at: root); try? FileManager.default.removeItem(at: targetRoot) }
        let library = LibraryStore(root: root, seedDemo: false); library.create("حاشية متعددة")
        let note = try XCTUnwrap(library.notebooks.first), pages = MarginPages(root: root, notebook: note.id)
        pages.editText("الأولى", page: try XCTUnwrap(pages.currentID)); XCTAssertTrue(pages.add(linkedTo: 1))
        pages.editText("الثانية", page: try XCTUnwrap(pages.currentID)); pages.saveInk(ink(), page: try XCTUnwrap(pages.currentID))
        let backup = try await library.exportBackup(); defer { try? FileManager.default.removeItem(at: backup) }
        let target = LibraryStore(root: targetRoot, seedDemo: false)
        _ = try await target.restoreBackup(backup, policy: .keepBoth); _ = try await target.restoreBackup(backup, policy: .keepBoth)
        let recovered = try XCTUnwrap(target.notebooks.last); XCTAssertNotEqual(recovered.id, note.id)
        let restored = MarginPages(root: targetRoot, notebook: recovered.id)
        XCTAssertNil(restored.error); XCTAssertEqual(restored.pages.map(\.text), ["الأولى", "الثانية"])
        XCTAssertEqual(restored.currentID, pages.currentID)
        XCTAssertEqual(try PKDrawing(data: XCTUnwrap(restored.current?.ink)).strokes.count, 1)
    }
    @MainActor func testExportIncludesLastLineOfLongTextAndAppendedPaperKeepsOriginalAndInk() throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let library = LibraryStore(root: root, seedDemo: false); library.create("الدراسة")
        let note = try XCTUnwrap(library.notebooks.first), pages = MarginPages(root: root, notebook: note.id)
        pages.editText(String(repeating: "A long study note continues across the sheet.\n", count: 150) + "FINAL-MARKER-839", page: try XCTUnwrap(pages.currentID))
        pages.saveInk(ink(), page: try XCTUnwrap(pages.currentID))
        let exported = try pages.export(); defer { try? FileManager.default.removeItem(at: exported) }
        let document = try XCTUnwrap(PDFDocument(url: exported))
        XCTAssertGreaterThan(document.pageCount, 2); XCTAssertTrue((document.string ?? "").contains("FINAL-MARKER-839"))
        let workspace = PDFWorkspace(note: note, root: root), original = try Data(contentsOf: workspace.fileURL)
        let inkPath = workspace.storage.appendingPathComponent("0.drawing"); try ink().dataRepresentation().write(to: inkPath)
        workspace.appendPaper(.dots)
        XCTAssertNil(workspace.error); XCTAssertEqual(workspace.document.pageCount, 2); XCTAssertEqual(workspace.page, 2)
        XCTAssertEqual(try Data(contentsOf: workspace.originalPDFURL), original)
        XCTAssertEqual(PDFWorkspace(note: note, root: root).document.pageCount, 2)
        XCTAssertEqual(try PKDrawing(data: Data(contentsOf: inkPath)).strokes.count, 1)
        let hits = try LibrarySearch.find("FINAL-MARKER", notes: library.notebooks, root: root)
        XCTAssertEqual(hits.count, 1)
    }
}
