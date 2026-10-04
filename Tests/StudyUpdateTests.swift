import XCTest
import PDFKit
import PencilKit
import ZIPFoundation
@testable import Hashiya

final class StudyUpdateTests: XCTestCase {
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
}
