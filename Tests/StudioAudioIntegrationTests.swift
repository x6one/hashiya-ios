import XCTest
@testable import Hashiya

final class StudioAudioIntegrationTests: XCTestCase {
    @MainActor func testCorruptExistingMarkersBlockDeletionWithoutReplacingUserBytes() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let clip = root.appendingPathComponent("old-recording.m4a")
        let recordingBytes = Data([1, 2, 3, 4])
        let corruptMarkers = Data("[{\"clip\":\"old-recording.m4a\", interrupted".utf8)
        try recordingBytes.write(to: clip)
        let links = root.appendingPathComponent("links.json")
        try corruptMarkers.write(to: links)

        let audio = PageAudio(folder: root)
        XCTAssertNotNil(audio.error, "Unreadable existing links must be visible, not silently treated as an empty store")
        audio.delete(clip)
        XCTAssertTrue(FileManager.default.fileExists(atPath: clip.path), "A destructive operation must fail closed if its marker transaction cannot be read")
        XCTAssertEqual(try Data(contentsOf: links), corruptMarkers, "Keep the exact original bytes available for recovery")
        XCTAssertEqual(try Data(contentsOf: clip), recordingBytes)
    }

    @MainActor func testOldMarkerIdentityAndFilenameSurviveReloadAndPlaybackAttempt() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let identity = UUID(), text = UUID()
        let oldJSON = """
        [{"id":"\(identity.uuidString)","clip":"legacy-name.m4a","time":12.5,"page":7,"textID":"\(text.uuidString)","strokeCount":3,"label":"old writing"}]
        """
        let bytes = Data(oldJSON.utf8)
        let links = root.appendingPathComponent("links.json")
        let clip = root.appendingPathComponent("legacy-name.m4a")
        try bytes.write(to: links)
        try Data([7, 8]).write(to: clip)
        let audio = PageAudio(folder: root)
        let marker = try XCTUnwrap(audio.markers.first)
        XCTAssertEqual(marker.id, identity)
        XCTAssertEqual(marker.textID, text)
        XCTAssertEqual(marker.page, 7)
        XCTAssertEqual(marker.time, 12.5)
        XCTAssertEqual(marker.strokeCount, 3)
        audio.seek(marker) // An invalid clip must fail safely without rewriting metadata.
        XCTAssertNil(audio.playing)
        XCTAssertNotNil(audio.error)
        audio.reload()
        XCTAssertEqual(audio.markers.first?.id, identity)
        XCTAssertEqual(try Data(contentsOf: links), bytes)
        XCTAssertEqual(try Data(contentsOf: clip), Data([7, 8]))
    }
}
