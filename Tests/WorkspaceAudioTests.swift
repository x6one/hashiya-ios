import XCTest
import Combine
import AVFoundation
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
        XCTAssertEqual(audio.activity.elapsed, 0)
        XCTAssertEqual(audio.activity.level, 0)
        XCTAssertTrue(audio.activity.samples.allSatisfy { $0 == 0 })
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
        XCTAssertEqual(audio.activity.elapsed, 0)
        XCTAssertEqual(audio.activity.level, 0)
        XCTAssertTrue(audio.activity.samples.allSatisfy { $0 == 0 })
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

    @MainActor func testStopClearsActivityWithoutPublishingMeterTicksThroughWorkspaceAudio() {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let audio = PageAudio(folder: folder)
        defer { audio.stop(); try? FileManager.default.removeItem(at: folder) }
        var workspaceUpdates = 0
        let subscription = audio.objectWillChange.sink { workspaceUpdates += 1 }
        audio.activity.update(elapsed: 12.5, averagePower: -12)
        XCTAssertEqual(audio.activity.elapsed, 12.5)
        XCTAssertGreaterThan(audio.activity.level, 0)
        XCTAssertEqual(workspaceUpdates, 0, "Meter updates must not invalidate the PDF workspace")
        audio.stop()
        XCTAssertEqual(audio.activity.elapsed, 0)
        XCTAssertEqual(audio.activity.level, 0)
        XCTAssertTrue(audio.activity.samples.allSatisfy { $0 == 0 })
        subscription.cancel()
    }

    @MainActor func testActivityBoundsRealPowerAndRetainsOnlyRecentSamples() {
        let activity = RecordingActivity()
        activity.update(elapsed: -2, averagePower: -.infinity)
        XCTAssertEqual(activity.elapsed, 0)
        XCTAssertEqual(activity.level, 0)
        activity.update(elapsed: 2, averagePower: -20)
        XCTAssertEqual(activity.level, 0.1, accuracy: 0.0001, "Convert recorder decibels to linear amplitude")
        XCTAssertEqual(activity.samples.last, activity.level)
        let capacity = activity.samples.count
        for second in 3...100 { activity.update(elapsed: Double(second), averagePower: 12) }
        XCTAssertEqual(activity.samples.count, capacity, "Long recordings must keep bounded meter history")
        XCTAssertTrue(activity.samples.allSatisfy { $0 == 1 })
        activity.update(elapsed: .nan, averagePower: .nan)
        XCTAssertEqual(activity.elapsed, 0)
        XCTAssertEqual(activity.level, 0)
    }

    @MainActor func testDeniedPermissionClearsStaleRecordingActivity() async {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let audio = PageAudio(folder: folder, requestPermission: { false })
        defer { audio.stop(); try? FileManager.default.removeItem(at: folder) }
        audio.activity.update(elapsed: 12, averagePower: -10)
        await audio.start()
        XCTAssertFalse(audio.recording)
        XCTAssertFalse(audio.requestingPermission)
        XCTAssertNotNil(audio.error)
        XCTAssertEqual(audio.activity.elapsed, 0)
        XCTAssertEqual(audio.activity.level, 0)
        XCTAssertTrue(audio.activity.samples.allSatisfy { $0 == 0 })
    }

    @MainActor func testInterruptionCancelsPendingPermissionAndResetsActivity() async {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        var permission: CheckedContinuation<Bool, Never>?
        let requested = expectation(description: "permission requested")
        let audio = PageAudio(folder: folder, requestPermission: {
            await withCheckedContinuation { permission = $0; requested.fulfill() }
        })
        let pending = Task { await audio.start() }
        await fulfillment(of: [requested], timeout: 2)
        audio.activity.update(elapsed: 12, averagePower: -10)
        let interrupted = expectation(description: "interruption cancelled request")
        let subscription = audio.$requestingPermission.dropFirst().filter { !$0 }.prefix(1).sink { _ in interrupted.fulfill() }
        NotificationCenter.default.post(name: AVAudioSession.interruptionNotification, object: nil,
                                        userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue])
        await fulfillment(of: [interrupted], timeout: 2)
        permission?.resume(returning: true)
        await pending.value
        XCTAssertFalse(audio.recording)
        XCTAssertNil(audio.recorder)
        XCTAssertEqual(audio.activity.elapsed, 0)
        XCTAssertEqual(audio.activity.level, 0)
        XCTAssertTrue(audio.clips.isEmpty)
        subscription.cancel()
    }

    @MainActor func testCancelledPermissionCannotClearNewerPendingRequest() async {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        var permissions: [CheckedContinuation<Bool, Never>] = []
        let firstRequested = expectation(description: "first permission requested")
        let secondRequested = expectation(description: "second permission requested")
        let audio = PageAudio(folder: folder, requestPermission: {
            await withCheckedContinuation {
                permissions.append($0)
                if permissions.count == 1 { firstRequested.fulfill() } else { secondRequested.fulfill() }
            }
        })
        let first = Task { await audio.start() }
        await fulfillment(of: [firstRequested], timeout: 2)
        audio.stop()
        let second = Task { await audio.start() }
        await fulfillment(of: [secondRequested], timeout: 2)
        permissions[0].resume(returning: true)
        await first.value
        XCTAssertTrue(audio.requestingPermission)
        XCTAssertFalse(audio.recording)
        XCTAssertEqual(audio.activity.elapsed, 0)
        permissions[1].resume(returning: false)
        await second.value
        XCTAssertFalse(audio.requestingPermission)
        XCTAssertNotNil(audio.error)
        XCTAssertEqual(audio.activity.level, 0)
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
