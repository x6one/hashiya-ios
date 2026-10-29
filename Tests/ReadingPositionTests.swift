import XCTest
@testable import Hashiya

final class ReadingPositionTests: XCTestCase {
    func testResumeClampsToExistingPagesWithoutOverwritingStoredProgress() {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let notebook = UUID()
        LibraryReadingPosition.save(page: 8, for: notebook, root: root)
        XCTAssertEqual(LibraryReadingPosition.page(for: notebook, root: root, maximum: 3), 3)
        XCTAssertNil(LibraryReadingPosition.page(for: notebook, root: root, maximum: 0))
        LibraryReadingPosition.save(page: 0, for: notebook, root: root)
        XCTAssertEqual(LibraryReadingPosition.page(for: notebook, root: root), 8)
        XCTAssertNil(LibraryReadingPosition.page(for: UUID(), root: root))
        XCTAssertNil(LibraryReadingPosition.page(for: notebook, root: root.appendingPathComponent("another-library")))
    }
}
