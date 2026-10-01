import XCTest
@testable import Hashiya

final class OfficeReplacementTests: XCTestCase {
    private func fixture(_ name: String, _ ext: String) throws -> URL {
        try XCTUnwrap(Bundle(for: LibraryStore.self).url(forResource: name, withExtension: ext))
    }
    @MainActor func testConversionKeepsOneIdentityAndMetadataAfterReload() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? fm.removeItem(at: root) }
        let office = try fixture("office-demo", "pptx")
        let originalBytes = try Data(contentsOf: office)
        let store = LibraryStore(root: root, seedDemo: false)
        store.addSection("دراستي")
        let note = try await store.importDocumentAsync(office, title: "محاضرتي", section: "دراستي")
        store.change(note.id) { $0.favorite = true }
        let pdf = try fixture("english", "pdf")
        let converted = try await store.replaceOfficeWithPDF(note.id, source: pdf)
        XCTAssertEqual(converted.id, note.id)
        XCTAssertEqual(converted.title, "محاضرتي")
        XCTAssertEqual(converted.section, "دراستي")
        XCTAssertTrue(converted.favorite)
        XCTAssertEqual(store.notebooks, [converted])
        XCTAssertEqual(LibraryStore(root: root, seedDemo: false).notebooks, [converted])
        XCTAssertFalse(fm.fileExists(atPath: root.appendingPathComponent(note.file).path))
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent(converted.file)), try Data(contentsOf: pdf))
        XCTAssertEqual(try Data(contentsOf: office), originalBytes)
    }
    @MainActor func testFailedReplacementPreservesOfficeAndRemovesNewPDF() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? fm.removeItem(at: root) }
        let store = LibraryStore(root: root, seedDemo: false)
        let note = try await store.importDocumentAsync(fixture("office-demo", "pptx"), title: "محاضرتي")
        let bytes = try Data(contentsOf: root.appendingPathComponent(note.file))
        try fm.removeItem(at: root.appendingPathComponent("library.json"))
        try fm.createDirectory(at: root.appendingPathComponent("library.json"), withIntermediateDirectories: true)
        do {
            try await store.replaceOfficeWithPDF(note.id, source: fixture("english", "pdf"))
            XCTFail("A failed index write must reject the replacement")
        } catch {
            XCTAssertEqual(store.notebooks, [note])
            XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent(note.file)), bytes)
            XCTAssertEqual(Set(try fm.contentsOfDirectory(atPath: root.path)), Set([note.file, "library.json"]))
        }
    }
    @MainActor func testCorruptReplacementDoesNotAlterOffice() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? fm.removeItem(at: root) }
        let store = LibraryStore(root: root, seedDemo: false)
        let note = try await store.importDocumentAsync(fixture("office-demo", "pptx"), title: "محاضرتي")
        let bad = root.appendingPathComponent("corrupt.pdf")
        try Data("broken".utf8).write(to: bad)
        do { try await store.replaceOfficeWithPDF(note.id, source: bad); XCTFail("Corrupt PDF must be rejected") }
        catch { XCTAssertEqual(LibraryStore(root: root, seedDemo: false).notebooks, [note]) }
        XCTAssertTrue(fm.fileExists(atPath: root.appendingPathComponent(note.file).path))
    }
    @MainActor func testDemoCleanupDoesNotDeleteUserFileWithSameTitle() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? fm.removeItem(at: root) }
        let store = LibraryStore(root: root, seedDemo: false)
        let demo = try await store.importDocumentAsync(fixture("office-demo", "pptx"), title: "تجربة Office")
        let userFile = try await store.importDocumentAsync(fixture("english", "pdf"), title: "تجربة Office")
        let reloaded = LibraryStore(root: root, seedDemo: false)
        XCTAssertEqual(reloaded.notebooks, [userFile])
        XCTAssertFalse(fm.fileExists(atPath: root.appendingPathComponent(demo.file).path))
        XCTAssertTrue(fm.fileExists(atPath: root.appendingPathComponent(userFile.file).path))
    }
}
