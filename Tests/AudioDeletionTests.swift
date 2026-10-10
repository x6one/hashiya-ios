import XCTest
@testable import Hashiya

final class AudioDeletionTests: XCTestCase {
    @MainActor func testDeletingClipRemovesOnlyItsLinksAndPersistsAfterReload() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let first = folder.appendingPathComponent("first.m4a"), other = folder.appendingPathComponent("other.m4a")
        try Data([1]).write(to: first); try Data([2]).write(to: other)
        let links = [AudioLink(clip: "first.m4a", time: 1, page: 1, label: "remove"), AudioLink(clip: "other.m4a", time: 2, page: 2, label: "keep")]
        try JSONEncoder().encode(links).write(to: folder.appendingPathComponent("links.json"))
        let audio = PageAudio(folder: folder)
        // The UI deletes the URL returned by directory enumeration, whose
        // directory metadata can differ from the URL used to create the file.
        let listed = try XCTUnwrap(audio.clips.first { $0.lastPathComponent == "first.m4a" })
        audio.delete(listed)
        XCTAssertNil(audio.error)
        XCTAssertFalse(FileManager.default.fileExists(atPath: first.path))
        XCTAssertEqual(try Data(contentsOf: other), Data([2]))
        let reloaded = PageAudio(folder: folder)
        XCTAssertEqual(reloaded.clips, [other])
        XCTAssertEqual(reloaded.markers.map(\.label), ["keep"])
        XCTAssertEqual(reloaded.loadLinks().map(\.clip), ["other.m4a"])
    }

    @MainActor func testMissingClipDoesNotLeavePlayableOrphanLinks() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        try JSONEncoder().encode([AudioLink(clip: "missing.m4a", time: 0, page: 1, label: "orphan")]).write(to: folder.appendingPathComponent("links.json"))
        let audio = PageAudio(folder: folder)
        XCTAssertTrue(audio.clips.isEmpty)
        XCTAssertTrue(audio.markers.isEmpty)
    }

    @MainActor func testCannotDeleteAClipFromAnotherFolder() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let audio = PageAudio(folder: root.appendingPathComponent("linked"))
        let outside = root.appendingPathComponent("outside.m4a")
        try Data([3]).write(to: outside)
        audio.delete(outside)
        XCTAssertEqual(try Data(contentsOf: outside), Data([3]))
    }
}
