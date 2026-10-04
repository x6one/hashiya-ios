import XCTest
import PDFKit
import PencilKit
import ZIPFoundation
@testable import Hashiya

final class StudyUpdateTests: XCTestCase {
    @MainActor func testRepeatedLassoConfigurationDoesNotRepublishSelection() {
        let canvas = LassoCanvas(frame: .zero)
        var notifications = 0
        canvas.selectionChanged = { _ in notifications += 1 }
        canvas.enableLasso(true)
        canvas.enableLasso(false)
        XCTAssertEqual(notifications, 1)
        for _ in 0..<20 { canvas.enableLasso(false) }
        XCTAssertEqual(notifications, 1)
        XCTAssertTrue(canvas.drawingGestureRecognizer.isEnabled)
    }
    func directory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    @MainActor func testOldLibraryDecodesWithoutOriginalField() throws {
        let note = Notebook(title: "قديم", file: "old.pdf")
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(note)) as? [String: Any])
        json.removeValue(forKey: "originalFile")
        let migrated = try JSONDecoder().decode(Notebook.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(migrated.id, note.id); XCTAssertNil(migrated.originalFile)
    }
    @MainActor func testBackupRoundTripIncludesOriginalInkAudioCardsAndCollisionPolicy() async throws {
        let fm = FileManager.default, root = try directory(), restored = try directory()
        defer { try? fm.removeItem(at: root); try? fm.removeItem(at: restored) }
        let store = LibraryStore(root: root, seedDemo: false)
        store.addSection("دراستي"); store.create("محاضرة", section: "دراستي", template: .lecture)
        var note = try XCTUnwrap(store.notebooks.first)
        note.originalFile = "original.docx"
        try Data([1, 2, 3]).write(to: root.appendingPathComponent("original.docx"))
        store.change(note.id) { $0.originalFile = note.originalFile; $0.favorite = true }
        let ink = root.appendingPathComponent(note.id.uuidString)
        try fm.createDirectory(at: ink, withIntermediateDirectories: true)
        try PKDrawing().dataRepresentation().write(to: ink.appendingPathComponent("0.drawing"))
        try PKDrawing().dataRepresentation().write(to: root.appendingPathComponent(note.id.uuidString + "-margin.drawing"))
        let audio = root.appendingPathComponent(note.id.uuidString + "-audio")
        try fm.createDirectory(at: audio, withIntermediateDirectories: true)
        try Data([4, 5, 6]).write(to: audio.appendingPathComponent("voice.m4a"))
        let cards = FlashcardStore(url: root.appendingPathComponent(note.id.uuidString + "-cards.json"))
        cards.save(Flashcard(question: "سؤال", answer: "جواب", page: 1))
        let backup = try await store.exportBackup(); defer { try? fm.removeItem(at: backup) }
        let target = LibraryStore(root: restored, seedDemo: false)
        let first = try await target.restoreBackup(backup, policy: .keepBoth)
        XCTAssertEqual(first, 1)
        let reloaded = LibraryStore(root: restored, seedDemo: false)
        let recovered = try XCTUnwrap(reloaded.notebooks.first)
        XCTAssertTrue(recovered.favorite); XCTAssertEqual(recovered.section, "دراستي")
        XCTAssertEqual(try Data(contentsOf: restored.appendingPathComponent(try XCTUnwrap(recovered.originalFile))), Data([1, 2, 3]))
        XCTAssertEqual(try Data(contentsOf: restored.appendingPathComponent(recovered.id.uuidString + "-audio/voice.m4a")), Data([4, 5, 6]))
        XCTAssertTrue(fm.fileExists(atPath: restored.appendingPathComponent(recovered.id.uuidString + "-margin.drawing").path))
        XCTAssertEqual(FlashcardStore(url: restored.appendingPathComponent(recovered.id.uuidString + "-cards.json")).cards.count, 1)
        let skipped = try await target.restoreBackup(backup, policy: .skipExisting)
        XCTAssertEqual(skipped, 0)
        let duplicated = try await target.restoreBackup(backup, policy: .keepBoth)
        XCTAssertEqual(duplicated, 1); XCTAssertEqual(target.notebooks.count, 2)
        XCTAssertNotEqual(target.notebooks[0].id, target.notebooks[1].id)
    }
    @MainActor func testFailedRestoreLeavesExistingLibraryUntouched() async throws {
        let fm = FileManager.default, root = try directory(), source = try directory()
        defer { try? fm.removeItem(at: root); try? fm.removeItem(at: source) }
        let sourceStore = LibraryStore(root: source, seedDemo: false); sourceStore.create("جديد")
        let backup = try await sourceStore.exportBackup(); defer { try? fm.removeItem(at: backup) }
        let store = LibraryStore(root: root, seedDemo: false); store.create("قديم")
        let previous = store.notebooks
        try fm.removeItem(at: root.appendingPathComponent("library.json")); try fm.createDirectory(at: root.appendingPathComponent("library.json"), withIntermediateDirectories: true)
        let names = Set(try fm.contentsOfDirectory(atPath: root.path))
        do { _ = try await store.restoreBackup(backup, policy: .keepBoth); XCTFail("Must roll back") } catch {}
        XCTAssertEqual(store.notebooks, previous); XCTAssertEqual(Set(try fm.contentsOfDirectory(atPath: root.path)), names)
    }
    @MainActor func testSearchFindsTypedNoteAtCorrectPageAndExcludesTrash() throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let store = LibraryStore(root: root, seedDemo: false); store.create("محاضرة")
        let note = try XCTUnwrap(store.notebooks.first)
        let workspace = PDFWorkspace(note: note, root: root)
        workspace.saveText(PageText(page: 0, text: "مراجعة الفضاء", x: 20, y: 30))
        let hits = try LibrarySearch.find("الفضاء", notes: store.notebooks, root: root)
        XCTAssertEqual(hits.first?.page, 1); XCTAssertEqual(hits.first?.notebook, note.id)
        store.change(note.id) { $0.trashed = true }
        XCTAssertTrue(try LibrarySearch.find("الفضاء", notes: store.notebooks, root: root).isEmpty)
    }
    func testAllPaperTemplatesProduceReadablePDF() throws {
        for template in PaperTemplate.allCases {
            let document = try XCTUnwrap(PDFDocument(data: template.render(color: .mint)))
            XCTAssertEqual(document.pageCount, 1); XCTAssertEqual(document.page(at: 0)?.bounds(for: .mediaBox).width, 650)
        }
    }
    @MainActor func testFlashcardReviewStateSurvivesReload() throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("cards.json"), store = FlashcardStore(url: root.appendingPathComponent("cards.json"))
        var card = Flashcard(question: "س", answer: "ج", page: 3); store.save(card)
        card.known = true; store.save(card)
        XCTAssertEqual(FlashcardStore(url: url).cards.first?.known, true)
        store.delete(card.id); XCTAssertTrue(FlashcardStore(url: url).cards.isEmpty)
    }
    func testLassoSelectsOnlyEnclosedStrokeAndTransformLeavesOthersUnchanged() {
        func stroke(_ x: CGFloat) -> PKStroke {
            let points = [0, 10, 20].map { y in PKStrokePoint(location: CGPoint(x: x, y: CGFloat(y)), timeOffset: Double(y) / 100, size: CGSize(width: 3, height: 3), opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2) }
            return PKStroke(ink: PKInk(.pen, color: .black), path: PKStrokePath(controlPoints: points, creationDate: Date()))
        }
        let drawing = PKDrawing(strokes: [stroke(20), stroke(200)])
        let selection = InkSelection.indices(in: drawing, polygon: [CGPoint(x: 0, y: -10), CGPoint(x: 50, y: -10), CGPoint(x: 50, y: 50), CGPoint(x: 0, y: 50)])
        XCTAssertEqual(selection, [0])
        let transformed = InkSelection.transform(drawing, indices: selection, by: CGAffineTransform(translationX: 100, y: 0))
        XCTAssertEqual(transformed.strokes.count, 2)
        XCTAssertEqual(transformed.strokes[0].renderBounds.midX - drawing.strokes[0].renderBounds.midX, 100, accuracy: 0.01)
        XCTAssertEqual(transformed.strokes[1].renderBounds, drawing.strokes[1].renderBounds)
    }
    func testBackupRejectsTraversalBeforeExtractingOutsideStaging() throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("bad.zip")
        let archive = try Archive(url: url, accessMode: .create)
        try archive.addEntry(with: "../escaped.txt", type: .file, uncompressedSize: Int64(1)) { _, _ in Data([1]) }
        XCTAssertThrowsError(try LibraryBackup.unpack(url, into: root.appendingPathComponent("staging")))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("escaped.txt").path))
    }
}
