import XCTest
import UniformTypeIdentifiers
@testable import Hashiya

final class DocumentImportTests: XCTestCase {
    @MainActor func testPickerAllowsSystemTypesForSupportedDocuments() throws {
        for ext in ["pdf", "pptx", "docx", "xlsx", "ppt", "doc", "xls"] {
            let type = try XCTUnwrap(UTType(filenameExtension: ext))
            XCTAssertTrue(DocumentPicker.contentTypes.contains { type.conforms(to: $0) }, type.identifier)
        }
    }
    @MainActor func testAsyncImportRetainsOriginalAndReloadsPrivateCopy() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = try XCTUnwrap(Bundle(for: LibraryStore.self).url(forResource: "english", withExtension: "pdf"))
        let original = try Data(contentsOf: source)
        let store = LibraryStore(root: root, seedDemo: false)
        store.addSection("الجامعة")
        try await store.importDocumentAsync(source, section: "الجامعة")
        let note = try XCTUnwrap(store.notebooks.first)
        XCTAssertEqual(try Data(contentsOf: source), original)
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent(note.file)), original)
        XCTAssertEqual(note.title, "english")
        XCTAssertEqual(note.section, "الجامعة")
        XCTAssertEqual(LibraryStore(root: root, seedDemo: false).notebooks, [note])
    }

    @MainActor func testFailedIndexWriteRemovesCopyAndRetainsSource() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? fm.removeItem(at: root) }
        let store = LibraryStore(root: root, seedDemo: false)
        let source = try XCTUnwrap(Bundle(for: LibraryStore.self).url(forResource: "english", withExtension: "pdf"))
        let original = try Data(contentsOf: source)
        // A directory at the index path forces an actual filesystem save error.
        try fm.createDirectory(at: root.appendingPathComponent("library.json"), withIntermediateDirectories: true)
        do {
            try await store.importDocumentAsync(source)
            XCTFail("Import must fail when the library cannot persist")
        } catch {
            XCTAssertTrue(store.notebooks.isEmpty)
            XCTAssertEqual(try fm.contentsOfDirectory(atPath: root.path), ["library.json"])
            XCTAssertEqual(try Data(contentsOf: source), original)
        }
    }

    @MainActor func testMissingAndCorruptFilesDoNotCreateEntries() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? fm.removeItem(at: root) }
        let store = LibraryStore(root: root, seedDemo: false)
        let bad = root.appendingPathComponent("broken.pdf")
        try Data("invalid PDF".utf8).write(to: bad)
        for source in [bad, root.appendingPathComponent("missing.pdf")] {
            do {
                try await store.importDocumentAsync(source)
                XCTFail("Invalid source must be rejected")
            } catch { XCTAssertTrue(store.notebooks.isEmpty) }
        }
        XCTAssertEqual(try fm.contentsOfDirectory(atPath: root.path), ["broken.pdf"])
    }
    @MainActor func testIncomingCleanupNeverDeletesAnExternalInboxFile() throws {
        let fm = FileManager.default
        let external = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("Inbox")
        let ownInbox = fm.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Inbox")
        try fm.createDirectory(at: external, withIntermediateDirectories: true)
        try fm.createDirectory(at: ownInbox, withIntermediateDirectories: true)
        let outside = external.appendingPathComponent("original.pdf")
        let incoming = ownInbox.appendingPathComponent(UUID().uuidString + ".pdf")
        defer { try? fm.removeItem(at: external.deletingLastPathComponent()); try? fm.removeItem(at: incoming) }
        let bytes = Data("incoming fixture".utf8)
        try bytes.write(to: outside); try bytes.write(to: incoming)
        DocumentPicker.discardIncomingCopy(outside)
        XCTAssertEqual(try Data(contentsOf: outside), bytes)
        DocumentPicker.discardIncomingCopy(incoming)
        XCTAssertFalse(fm.fileExists(atPath: incoming.path))
    }

}
