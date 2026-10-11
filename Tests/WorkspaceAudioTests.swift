import XCTest
@testable import Hashiya

final class WorkspaceAudioTests: XCTestCase {
    @MainActor func testRepeatedStartWhilePermissionPendingRequestsPermissionOnce() async {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        var permission: CheckedContinuation<Bool, Never>?
        let requested = expectation(description: "permission requested")
        var requests = 0
        let audio = PageAudio(folder: folder, requestPermission: {
            requests += 1
            return await withCheckedContinuation { permission = $0; requested.fulfill() }
        })
        let first = Task { await audio.start() }
        await fulfillment(of: [requested], timeout: 2)
        XCTAssertTrue(audio.requestingPermission)
        await audio.start()
        XCTAssertEqual(requests, 1)
        permission?.resume(returning: false)
        await first.value
        XCTAssertFalse(audio.requestingPermission)
        XCTAssertFalse(audio.recording)
        XCTAssertNotNil(audio.error)
        XCTAssertTrue(audio.clips.isEmpty)
    }

    @MainActor func testStopDuringPermissionRequestPreventsLateGrantFromRecording() async {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        var permission: CheckedContinuation<Bool, Never>?
        let requested = expectation(description: "permission requested")
        let audio = PageAudio(folder: folder, requestPermission: {
            await withCheckedContinuation { permission = $0; requested.fulfill() }
        })
        let first = Task { await audio.start() }
        await fulfillment(of: [requested], timeout: 2)
        audio.stop()
        permission?.resume(returning: true)
        await first.value
        XCTAssertFalse(audio.requestingPermission)
        XCTAssertFalse(audio.recording)
        XCTAssertNil(audio.recorder)
        XCTAssertTrue(audio.clips.isEmpty)
    }

    @MainActor func testPermissionPromptSurvivesInactiveButBackgroundCancelsPendingStart() async {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        var permission: CheckedContinuation<Bool, Never>?
        let requested = expectation(description: "permission requested")
        let audio = PageAudio(folder: folder, requestPermission: {
            await withCheckedContinuation { permission = $0; requested.fulfill() }
        })
        let first = Task { await audio.start() }
        await fulfillment(of: [requested], timeout: 2)
        audio.handleScenePhase(.inactive)
        XCTAssertTrue(audio.requestingPermission, "Permission alert must not cancel the pending start")
        audio.handleScenePhase(.background)
        XCTAssertFalse(audio.requestingPermission)
        permission?.resume(returning: true)
        await first.value
        XCTAssertFalse(audio.recording)
        XCTAssertNil(audio.recorder)
    }

    func testLegacyPageFoldersIncludeOnlyExistingClipsInPageOrder() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        for name in ["10", "2", "3", "linked", "notes"] {
            let folder = root.appendingPathComponent(name)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            if name != "3" { try Data([1]).write(to: folder.appendingPathComponent("clip.m4a")) }
        }
        let folders = LegacyPageRecordings.folders(in: root)
        XCTAssertEqual(folders.map(\.page), [2, 10])
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("10/clip.m4a")), Data([1]))
        XCTAssertTrue(LegacyPageRecordings.folders(in: root.appendingPathComponent("missing")).isEmpty)
    }
}
