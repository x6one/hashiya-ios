import XCTest
import PDFKit
import PencilKit
@testable import Hashiya

final class PageRemovalTests: XCTestCase {
    private func directory() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true); return root
    }
    @MainActor func testMiddlePageDeletionRemapsEveryAnchorAndUndoRestoresOriginalBytes() throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let library = LibraryStore(root: root, seedDemo: false); library.create("Notebook")
        let note = try XCTUnwrap(library.notebooks.first), workspace = PDFWorkspace(note: note, root: root)
        workspace.appendPaper(.dots); workspace.appendPaper(.lecture)
        let original = try Data(contentsOf: workspace.fileURL)
        let text = PageText(page: 2, text: "Keep last page", x: 20, y: 30)
        workspace.saveText(text)
        let retained = Data("last-ink".utf8), discarded = Data("middle-ink".utf8)
        try retained.write(to: workspace.storage.appendingPathComponent("2.drawing"))
        try discarded.write(to: workspace.storage.appendingPathComponent("1.drawing"))
        let cardsURL = root.appendingPathComponent(note.id.uuidString + "-cards.json")
        let cards = [Flashcard(question: "middle", answer: "a", page: 2), Flashcard(question: "last", answer: "b", page: 3)]
        try JSONEncoder().encode(cards).write(to: cardsURL)
        let ocrURL = root.appendingPathComponent(note.id.uuidString + "-ocr.json")
        try JSONEncoder().encode([OCRPage(page: 1, text: "remove"), OCRPage(page: 2, text: "keep")]).write(to: ocrURL)
        let margins = MarginPages(root: root, notebook: note.id)
        margins.linkCurrent(to: 2); margins.editText("Retain independent note", page: try XCTUnwrap(margins.currentID))
        XCTAssertTrue(margins.add(linkedTo: 3))
        let audio = root.appendingPathComponent(note.id.uuidString + "-audio")
        try FileManager.default.createDirectory(at: audio.appendingPathComponent("linked"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: audio.appendingPathComponent("3"), withIntermediateDirectories: true)
        try Data("audio-bytes".utf8).write(to: audio.appendingPathComponent("3/clip.m4a"))
        let linksURL = audio.appendingPathComponent("linked/links.json")
        try JSONEncoder().encode([AudioLink(clip: "clip.m4a", time: 3, page: 3, label: "last")]).write(to: linksURL)
        try workspace.deletePage(2, note: note, root: root)
        XCTAssertEqual(workspace.document.pageCount, 2); XCTAssertEqual(workspace.texts.first?.page, 1)
        XCTAssertEqual(try Data(contentsOf: workspace.storage.appendingPathComponent("1.drawing")), retained)
        XCTAssertFalse(FileManager.default.fileExists(atPath: workspace.storage.appendingPathComponent("2.drawing").path))
        XCTAssertEqual(try JSONDecoder().decode([Flashcard].self, from: Data(contentsOf: cardsURL)).map(\.page), [2])
        XCTAssertEqual(try JSONDecoder().decode([OCRPage].self, from: Data(contentsOf: ocrURL)).map(\.page), [1])
        let reopenedMargins = MarginPages(root: root, notebook: note.id)
        XCTAssertEqual(reopenedMargins.pages.map(\.sourcePage), [nil, 2])
        XCTAssertEqual(reopenedMargins.pages.first?.text, "Retain independent note")
        XCTAssertEqual(try JSONDecoder().decode([AudioLink].self, from: Data(contentsOf: linksURL)).map(\.page), [2])
        XCTAssertEqual(try Data(contentsOf: audio.appendingPathComponent("2/clip.m4a")), Data("audio-bytes".utf8))
        // Exercise reopening and disk-based undo, rather than an in-memory copy.
        let reopened = PDFWorkspace(note: note, root: root)
        XCTAssertTrue(reopened.canUndoPageDeletion)
        try reopened.undoPageDeletion(note: note, root: root)
        XCTAssertEqual(reopened.document.pageCount, 3)
        XCTAssertEqual(try Data(contentsOf: workspace.fileURL), original)
        XCTAssertEqual(reopened.texts.first?.page, 2)
        XCTAssertEqual(try Data(contentsOf: workspace.storage.appendingPathComponent("1.drawing")), discarded)
        XCTAssertEqual(MarginPages(root: root, notebook: note.id).pages.map(\.sourcePage), [2, 3])
    }
    @MainActor func testInvalidSidecarAndLastPageNeverPublishPartialDeletion() throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let library = LibraryStore(root: root, seedDemo: false); library.create("Study")
        let note = try XCTUnwrap(library.notebooks.first), workspace = PDFWorkspace(note: note, root: root)
        XCTAssertThrowsError(try workspace.deletePage(1, note: note, root: root))
        workspace.appendPaper(.dots)
        let original = try Data(contentsOf: workspace.fileURL), broken = Data("broken".utf8)
        try broken.write(to: workspace.textURL)
        XCTAssertThrowsError(try workspace.deletePage(1, note: note, root: root))
        XCTAssertEqual(try Data(contentsOf: workspace.fileURL), original)
        XCTAssertEqual(try Data(contentsOf: workspace.textURL), broken)
    }
    @MainActor func testUndoDoesNotOverwriteNewWritingAndInterruptedDeletionRecoversOnOpen() throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let library = LibraryStore(root: root, seedDemo: false); library.create("Study")
        let note = try XCTUnwrap(library.notebooks.first), workspace = PDFWorkspace(note: note, root: root)
        workspace.appendPaper(.dots)
        let original = try Data(contentsOf: workspace.fileURL)
        try workspace.deletePage(2, note: note, root: root)
        let text = PageText(page: 0, text: "New writing must survive", x: 10, y: 10)
        workspace.saveText(text)
        XCTAssertThrowsError(try workspace.undoPageDeletion(note: note, root: root))
        XCTAssertEqual(workspace.texts.first?.text, text.text)
        // A transaction marked pending models termination before publication completed.
        let journal = root.appendingPathComponent(note.id.uuidString + "-page-edit/journal.json")
        var state = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: journal)) as? [String: Any])
        state["pending"] = true; try JSONSerialization.data(withJSONObject: state).write(to: journal)
        let recovered = PDFWorkspace(note: note, root: root)
        XCTAssertNil(recovered.error); XCTAssertEqual(recovered.document.pageCount, 2)
        XCTAssertEqual(try Data(contentsOf: workspace.fileURL), original)
    }
    @MainActor func testMarginDeletionAndRestorePersistAllContentAndBlockLastPage() throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let id = UUID(), store = MarginPages(root: root, notebook: id)
        let first = try XCTUnwrap(store.currentID)
        XCTAssertFalse(store.delete(first)); XCTAssertTrue(store.add(linkedTo: 3))
        let added = try XCTUnwrap(store.currentID)
        store.editText("Deleted note stays recoverable", page: added); store.editTitle("My page", page: added)
        store.saveInk(PKDrawing(), page: added)
        let original = try XCTUnwrap(store.current?.ink)
        XCTAssertTrue(store.delete(added)); XCTAssertEqual(store.currentID, first)
        let reopened = MarginPages(root: root, notebook: id)
        XCTAssertEqual(reopened.deletedPages.map(\.id), [added]); XCTAssertTrue(reopened.restore(added))
        XCTAssertEqual(reopened.current?.text, "Deleted note stays recoverable")
        XCTAssertEqual(reopened.current?.ink, original); XCTAssertEqual(reopened.current?.sourcePage, 3)
        XCTAssertEqual(MarginPages(root: root, notebook: id).currentID, added)
    }
    @MainActor func testMovedDocumentLeavesRootAndReturnsWhenSectionIsDeleted() throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let store = LibraryStore(root: root, seedDemo: false); store.create("Reading")
        let note = try XCTUnwrap(store.notebooks.first), original = try Data(contentsOf: root.appendingPathComponent(note.file))
        store.addSection("Study"); store.change(note.id) { $0.section = "Study" }
        XCTAssertTrue(store.visibleNotebooks().isEmpty)
        XCTAssertEqual(store.visibleNotebooks(section: "Study").map(\.id), [note.id])
        let reopened = LibraryStore(root: root, seedDemo: false)
        XCTAssertTrue(reopened.visibleNotebooks().isEmpty); XCTAssertEqual(reopened.visibleNotebooks(section: nil).count, 1)
        reopened.deleteSection("Study"); XCTAssertEqual(reopened.visibleNotebooks().map(\.id), [note.id])
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent(note.file)), original)
    }
    @MainActor func testBackupKeepsDeletedMarginsAndPageUndoWithRenamedNotebookResources() async throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let library = LibraryStore(root: root, seedDemo: false); library.create("Backup")
        let note = try XCTUnwrap(library.notebooks.first), margins = MarginPages(root: root, notebook: note.id)
        XCTAssertTrue(margins.add(linkedTo: 1)); let deleted = try XCTUnwrap(margins.currentID)
        margins.editText("Recover from backup", page: deleted); XCTAssertTrue(margins.delete(deleted))
        let workspace = PDFWorkspace(note: note, root: root); workspace.appendPaper(.dots)
        let original = try Data(contentsOf: workspace.fileURL)
        try workspace.deletePage(2, note: note, root: root)
        let backup = try await library.exportBackup(); defer { try? FileManager.default.removeItem(at: backup) }
        _ = try await library.restoreBackup(backup, policy: .keepBoth)
        let restored = try XCTUnwrap(library.notebooks.last); XCTAssertNotEqual(restored.id, note.id)
        let restoredMargins = MarginPages(root: root, notebook: restored.id)
        XCTAssertEqual(restoredMargins.deletedPages.first?.text, "Recover from backup")
        let restoredPDF = PDFWorkspace(note: restored, root: root)
        XCTAssertTrue(restoredPDF.canUndoPageDeletion)
        try restoredPDF.undoPageDeletion(note: restored, root: root)
        XCTAssertEqual(try Data(contentsOf: restoredPDF.fileURL), original)
        XCTAssertTrue(restoredMargins.restore(deleted))
        XCTAssertEqual(restoredMargins.current?.text, "Recover from backup")
    }
    @MainActor func testDamagedArchivedMarginCannotBeOverwrittenByAddingAnEmptyPage() throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let id = UUID(), margins = MarginPages(root: root, notebook: id)
        XCTAssertTrue(margins.add(linkedTo: 1)); let removed = try XCTUnwrap(margins.currentID)
        XCTAssertTrue(margins.delete(removed))
        let index = margins.folder.appendingPathComponent("index.json"), original = try Data(contentsOf: index)
        try Data("broken".utf8).write(to: margins.folder.appendingPathComponent(removed.uuidString + ".json"))
        let reopened = MarginPages(root: root, notebook: id)
        XCTAssertNotNil(reopened.error); XCTAssertTrue(reopened.pages.isEmpty); XCTAssertFalse(reopened.add(linkedTo: 2))
        XCTAssertEqual(try Data(contentsOf: index), original)
    }
}
