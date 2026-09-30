import XCTest
@testable import Hashiya

final class DocumentImportTests: XCTestCase {
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
}
