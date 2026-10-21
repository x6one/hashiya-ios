import XCTest
@testable import Hashiya

final class StudioLibraryWriteSafetyTests: XCTestCase {
    @MainActor func testUnreadableLibraryBlocksImportAndExplicitSaveWithoutLosingOriginalBytes() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let source = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".pdf")
        defer { try? FileManager.default.removeItem(at: root); try? FileManager.default.removeItem(at: source) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let index = root.appendingPathComponent("library.json"), broken = Data("[{unfinished original library".utf8)
        try broken.write(to: index)
        let pdf = PaperTemplate.ruled.render(color: .cream)
        try pdf.write(to: source)
        let library = LibraryStore(root: root, seedDemo: false)
        XCTAssertNotNil(library.error)
        XCTAssertThrowsError(try library.importPDF(source, title: "Do not overwrite the old index"))
        XCTAssertEqual(try Data(contentsOf: index), broken)
        library.save()
        XCTAssertNotNil(library.error)
        XCTAssertEqual(try Data(contentsOf: index), broken, "Every writer, including explicit save, must respect the failed initial load")
        XCTAssertEqual(try Data(contentsOf: source), pdf, "Failed import must keep the user's original PDF")
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.path), ["library.json"], "No orphan private copy may survive a rejected import")
    }
}
