import XCTest
import PDFKit
import PencilKit
@testable import Hashiya

final class DemoLibraryTests: XCTestCase {
    @MainActor func testDemonstrationIsCompletePersistentAndDoesNotReplaceUserEdits() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = LibraryStore(root: root, seedDemo: false)
        store.create("دفتر المستخدم")
        let user = try XCTUnwrap(store.notebooks.first)
        let original = try Data(contentsOf: root.appendingPathComponent(user.file))
        let guide = try store.installDemonstration()
        XCTAssertEqual(store.notebooks.count, 4)
        let pdf = try XCTUnwrap(PDFDocument(url: root.appendingPathComponent(guide.file)))
        XCTAssertEqual(pdf.pageCount, 3)
        XCTAssertTrue(pdf.page(at: 2)?.string?.contains("بيانات شخصية") == true, "The guide must not clip its last paragraph")
        let margins = MarginPages(root: root, notebook: guide.id)
        XCTAssertEqual(margins.pages.count, 2)
        XCTAssertEqual(margins.pages.map(\.sourcePage), [1, 2])
        XCTAssertEqual(try PKDrawing(data: margins.pages[0].ink).strokes.count, 1)
        let page = try XCTUnwrap(margins.currentID)
        margins.editText("تعديلي يبقى", page: page)
        let reopened = LibraryStore(root: root, seedDemo: false)
        XCTAssertEqual(try reopened.installDemonstration().id, guide.id)
        XCTAssertEqual(reopened.notebooks.count, 4)
        XCTAssertEqual(MarginPages(root: root, notebook: guide.id).current?.text, "تعديلي يبقى")
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent(user.file)), original)
        XCTAssertTrue(reopened.notebooks.contains { $0.id == user.id })
        XCTAssertTrue(reopened.notebooks.contains { $0.file.hasSuffix(".pptx") })
    }

    @MainActor func testFailedDemonstrationPublishLeavesExistingLibraryUnchanged() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = LibraryStore(root: root, seedDemo: false)
        store.create("دفتر المستخدم")
        let original = store.notebooks
        let libraryURL = root.appendingPathComponent("library.json")
        try FileManager.default.removeItem(at: libraryURL)
        try FileManager.default.createDirectory(at: libraryURL, withIntermediateDirectories: false)
        XCTAssertThrowsError(try store.installDemonstration())
        XCTAssertEqual(store.notebooks, original)
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("demonstration.json").path))
        let resources = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
        XCTAssertEqual(Set(resources.map(\.lastPathComponent)), Set(["library.json", original[0].file]))
    }
}
