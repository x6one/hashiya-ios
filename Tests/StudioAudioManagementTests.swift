import XCTest
import AVFoundation
import Combine
@testable import Hashiya

final class StudioAudioManagementTests: XCTestCase {
    private func directory() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
    @MainActor func testRenameUsesMetadataAndPreservesActualM4AAndLegacyMarkerBytes() throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let clip = root.appendingPathComponent("original-name.m4a")
        try m4a(at: clip)
        let id = UUID(), links = Data("[{\"id\":\"\(id)\",\"clip\":\"original-name.m4a\",\"time\":0.2,\"page\":7,\"label\":\"Old\"}]".utf8)
        try links.write(to: root.appendingPathComponent("links.json"))
        let original = try Data(contentsOf: clip)
        let audio = PageAudio(folder: root)
        audio.rename(clip, title: "محاضرة الدراسة")
        XCTAssertNil(audio.error)
        let reloaded = PageAudio(folder: root)
        XCTAssertEqual(reloaded.clipMetadata(clip).title, "محاضرة الدراسة")
        XCTAssertEqual(reloaded.clipMetadata(clip).duration, 4, accuracy: 0.1)
        XCTAssertEqual(reloaded.clipMetadata(clip).startPage, 7)
        XCTAssertEqual(reloaded.markers.first?.id, id)
        XCTAssertEqual(try Data(contentsOf: clip), original)
        XCTAssertEqual(try Data(contentsOf: audio.linksURL), links)
        XCTAssertEqual(try AVAudioPlayer(contentsOf: clip).duration, 4, accuracy: 0.1)
    }
    @MainActor func testDamagedMetadataBlocksRenameDeleteAndRecordBeforePermission() async throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let clip = root.appendingPathComponent("old.m4a"), original = Data([1, 2, 3])
        try original.write(to: clip)
        let broken = Data("{interrupted metadata".utf8)
        try broken.write(to: root.appendingPathComponent("recordings.json"))
        var requested = false
        let audio = PageAudio(folder: root, requestPermission: { requested = true; return true })
        XCTAssertNotNil(audio.error)
        audio.rename(clip, title: "New")
        audio.delete(clip)
        await audio.start(page: 1)
        XCTAssertFalse(requested)
        XCTAssertFalse(audio.recording)
        XCTAssertEqual(try Data(contentsOf: clip), original)
        XCTAssertEqual(try Data(contentsOf: audio.metadataURL), broken)
    }
    @MainActor func testRealPlaybackPauseSeekRateAndPeerHandoffPreserveMedia() async throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let clip = root.appendingPathComponent("playback.m4a")
        try m4a(at: clip)
        let original = try Data(contentsOf: clip)
        let audio = PageAudio(folder: root)
        defer { audio.stop() }
        audio.togglePlayback(clip)
        XCTAssertEqual(audio.playing, clip)
        XCTAssertFalse(audio.paused)
        audio.togglePlayback(clip)
        XCTAssertTrue(audio.paused)
        XCTAssertEqual(audio.playing, clip, "Pause retains the same player and position")
        audio.skipPlayback(by: 10)
        let seeked = expectation(description: "real AAC player reports its requested paused seek")
        let observation = audio.playbackActivity.$time.filter { $0 > 3 }.prefix(1).sink { _ in seeked.fulfill() }
        await fulfillment(of: [seeked], timeout: 2)
        observation.cancel()
        XCTAssertGreaterThan(audio.playbackActivity.time, 3)
        audio.skipPlayback(by: -10)
        XCTAssertEqual(audio.playbackActivity.time, 0, accuracy: 0.05)
        audio.setPlaybackRate(1.5)
        XCTAssertEqual(audio.playbackRate, 1.5)
        audio.setPlaybackRate(.nan)
        XCTAssertEqual(audio.playbackRate, 1.5)
        audio.togglePlayback(clip)
        XCTAssertFalse(audio.paused)
        let peer = PageAudio(folder: root.appendingPathComponent("legacy"))
        audio.coordinatePlayback(with: peer)
        peer.play(clip)
        defer { peer.stop() }
        XCTAssertNil(audio.playing)
        XCTAssertEqual(peer.playing, clip)
        XCTAssertEqual(try Data(contentsOf: clip), original)
    }
    @MainActor func testMarkerAtZeroRestartsAnAlreadyPlayingRecording() throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let clip = root.appendingPathComponent("start.m4a")
        try m4a(at: clip)
        let audio = PageAudio(folder: root)
        defer { audio.stop() }
        audio.play(clip)
        XCTAssertEqual(audio.playing, clip)
        audio.seek(AudioLink(clip: clip.lastPathComponent, time: 0, page: 1, label: "Start"))
        XCTAssertEqual(audio.playing, clip, "A timestamp at zero is a seek, independently of the whole-clip stop toggle")
        audio.play(clip)
        XCTAssertNil(audio.playing, "The existing whole-clip play toggle still stops playback")
    }
    @MainActor func testRealMarkerPlaybackStartsAtItsStoredNativeTime() async throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let clip = root.appendingPathComponent("timestamp.m4a")
        try m4a(at: clip)
        let audio = PageAudio(folder: root)
        defer { audio.stop() }
        audio.seek(AudioLink(clip: clip.lastPathComponent, time: 1.25, page: 2, label: "Writing"))
        let returnedAt = ProcessInfo.processInfo.systemUptime
        XCTAssertNil(audio.error)
        let actualTime = expectation(description: "AVAudioPlayer starts at the actual marker offset")
        let observation = audio.playbackActivity.$time.filter { $0 > 0.05 }.prefix(1).sink { _ in actualTime.fulfill() }
        await fulfillment(of: [actualTime], timeout: 2)
        observation.cancel()
        let offset = audio.playbackActivity.time - (ProcessInfo.processInfo.systemUptime - returnedAt)
        XCTAssertEqual(offset, 1.25, accuracy: 0.35, "Waiting must not let incorrect playback from zero masquerade as a successful seek")
        XCTAssertEqual(audio.playing, clip)
    }
    func testPendingAppendRecoversBothCrashStatesWithoutChangingExistingPageIDs() throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let index = AudioPageIdentityStore(folder: root)
        let first = try index.pageID(number: 1, pageCount: 2)
        let second = try index.pageID(number: 2, pageCount: 2)
        try index.prepareAppend(pageCount: 2)
        XCTAssertEqual(try index.identities(pageCount: 2), [first, second], "Crash before PDF publication resolves the old count")
        let after = try XCTUnwrap(index.identities(pageCount: 3))
        XCTAssertEqual(Array(after.prefix(2)), [first, second])
        XCTAssertEqual(try index.pageID(number: 3, pageCount: 3), after[2], "Crash after publication keeps the pending new page identity")
        try index.prepareAppend(pageCount: 3)
        XCTAssertEqual(try index.identities(pageCount: 3), after)
        XCTAssertThrowsError(try index.identities(pageCount: 7), "An unexplained count mismatch must fail closed")
        let bytes = try Data(contentsOf: index.url)
        try Data("broken".utf8).write(to: index.url)
        XCTAssertThrowsError(try index.pageID(number: 1, pageCount: 3))
        XCTAssertEqual(try Data(contentsOf: index.url), Data("broken".utf8))
        XCTAssertFalse(bytes.isEmpty)
    }
    @MainActor func testDeletionKeepsStableSurvivorsArchivesRemovedAudioAndUndoRestoresAll() throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let library = LibraryStore(root: root, seedDemo: false); library.create("Audio study")
        let note = try XCTUnwrap(library.notebooks.first), workspace = PDFWorkspace(note: note, root: root)
        workspace.appendPaper(.dots); workspace.appendPaper(.lecture)
        let index = AudioPageIdentityStore(folder: workspace.audioFolder)
        let ids = try XCTUnwrap(index.identities(pageCount: 3, create: true))
        let removed = AudioLink(clip: "same.m4a", time: 1, page: 2, label: "removed", pageID: ids[1])
        let surviving = AudioLink(clip: "same.m4a", time: 2, page: 3, label: "last", pageID: ids[2])
        let audio = PageAudio(folder: workspace.audioFolder)
        try audio.saveRecordingMetadata(workspace.audioFolder.appendingPathComponent("same.m4a"), duration: 3, startPage: 2, pageID: ids[1])
        try JSONEncoder().encode([removed, surviving]).write(to: audio.linksURL)
        let media = Data([9, 8, 7])
        try media.write(to: workspace.audioFolder.appendingPathComponent("same.m4a"))
        let legacy = workspace.audioFolder.deletingLastPathComponent().appendingPathComponent("2")
        try FileManager.default.createDirectory(at: legacy, withIntermediateDirectories: true)
        try media.write(to: legacy.appendingPathComponent("legacy.m4a"))
        let originalIndex = try Data(contentsOf: index.url), originalLinks = try Data(contentsOf: audio.linksURL)
        let originalMetadata = try Data(contentsOf: audio.metadataURL)
        try workspace.deletePage(2, note: note, root: root)
        XCTAssertEqual(try index.identities(pageCount: 2), [ids[0], ids[2]])
        let links = try audio.readLinks()
        XCTAssertEqual(links.map(\.id), [surviving.id]); XCTAssertEqual(links.first?.pageID, ids[2]); XCTAssertEqual(links.first?.page, 2)
        let archived = try JSONDecoder().decode([AudioLink].self, from: Data(contentsOf: workspace.audioFolder.appendingPathComponent("deleted-links.json")))
        XCTAssertEqual(archived.map(\.id), [removed.id])
        let legacyArchive = try XCTUnwrap(LegacyPageRecordings.archivedFolders(in: workspace.audioFolder.deletingLastPathComponent()).first)
        XCTAssertEqual(try Data(contentsOf: legacyArchive.folder.appendingPathComponent("legacy.m4a")), media)
        XCTAssertEqual(try Data(contentsOf: workspace.audioFolder.appendingPathComponent("same.m4a")), media)
        let changedMetadata = try audio.readMetadata()["same.m4a"]
        XCTAssertNil(changedMetadata?.startPage)
        XCTAssertEqual(changedMetadata?.sourceDeleted, true)
        try workspace.undoPageDeletion(note: note, root: root)
        XCTAssertEqual(try Data(contentsOf: index.url), originalIndex)
        XCTAssertEqual(try Data(contentsOf: audio.linksURL), originalLinks)
        XCTAssertEqual(try Data(contentsOf: audio.metadataURL), originalMetadata)
        XCTAssertEqual(try Data(contentsOf: legacy.appendingPathComponent("legacy.m4a")), media)
        XCTAssertTrue(LegacyPageRecordings.archivedFolders(in: workspace.audioFolder.deletingLastPathComponent()).isEmpty)
    }
    @MainActor func testNewAudioSidecarsSurviveActualAppendReloadAndBackupRestore() async throws {
        let root = try directory(), restoredRoot = try directory()
        defer { try? FileManager.default.removeItem(at: root); try? FileManager.default.removeItem(at: restoredRoot) }
        let library = LibraryStore(root: root, seedDemo: false); library.create("Safe audio")
        let note = try XCTUnwrap(library.notebooks.first), workspace = PDFWorkspace(note: note, root: root)
        let index = AudioPageIdentityStore(folder: workspace.audioFolder)
        let first = try index.pageID(number: 1, pageCount: 1)
        workspace.appendPaper(.dots)
        XCTAssertNil(workspace.error)
        let ids = try XCTUnwrap(index.identities(pageCount: 2))
        XCTAssertEqual(ids.first, first)
        let audio = PageAudio(folder: workspace.audioFolder)
        let clip = workspace.audioFolder.appendingPathComponent("keep-original.m4a")
        try m4a(at: clip)
        let media = try Data(contentsOf: clip)
        try audio.saveRecordingMetadata(clip, duration: 4, startPage: 2, pageID: ids[1])
        audio.rename(clip, title: "Preserve me")
        let marker = AudioLink(clip: clip.lastPathComponent, time: 1.2, page: 2, label: "Manual", pageID: ids[1], kind: "manual")
        try JSONEncoder().encode([marker]).write(to: audio.linksURL)
        let metadataBytes = try Data(contentsOf: audio.metadataURL), identityBytes = try Data(contentsOf: index.url)
        let backup = try await library.exportBackup()
        defer { try? FileManager.default.removeItem(at: backup) }
        let restored = LibraryStore(root: restoredRoot, seedDemo: false)
        let count = try await restored.restoreBackup(backup, policy: .skipExisting)
        XCTAssertEqual(count, 1)
        let reloadedNote = try XCTUnwrap(restored.notebooks.first)
        let reloaded = PDFWorkspace(note: reloadedNote, root: restoredRoot)
        let restoredAudio = PageAudio(folder: reloaded.audioFolder)
        XCTAssertEqual(reloaded.document.pageCount, 2)
        XCTAssertEqual(try Data(contentsOf: restoredAudio.metadataURL), metadataBytes)
        XCTAssertEqual(try Data(contentsOf: AudioPageIdentityStore(folder: reloaded.audioFolder).url), identityBytes)
        XCTAssertEqual(restoredAudio.clipMetadata(reloaded.audioFolder.appendingPathComponent(clip.lastPathComponent)).title, "Preserve me")
        XCTAssertEqual(restoredAudio.markers.first?.id, marker.id)
        XCTAssertEqual(restoredAudio.markers.first?.pageID, ids[1])
        XCTAssertEqual(try Data(contentsOf: reloaded.audioFolder.appendingPathComponent(clip.lastPathComponent)), media)
    }
    /// Encoded AAC media exercises playback and sharing bytes, not a microphone.
    private func m4a(at url: URL) throws {
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 44100 * 4))
        buffer.frameLength = 44100 * 4
        let samples = try XCTUnwrap(buffer.floatChannelData?.pointee)
        for index in 0..<Int(buffer.frameLength) { samples[index] = sin(Float(index) * 2 * .pi * 440 / 44100) * 0.05 }
        let file = try AVAudioFile(forWriting: url, settings: [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 44100, AVNumberOfChannelsKey: 1])
        try file.write(from: buffer)
    }
}
