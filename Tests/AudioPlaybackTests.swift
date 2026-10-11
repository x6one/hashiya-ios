import XCTest
import Combine
@testable import Hashiya

final class AudioPlaybackTests: XCTestCase {
    @MainActor func testNaturalCompletionClearsPlaybackAndNextTapReplays() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let audio = PageAudio(folder: folder)
        defer { audio.stop(); try? FileManager.default.removeItem(at: folder) }
        let clip = folder.appendingPathComponent("short.wav")
        try shortWave().write(to: clip)

        let finished = expectation(description: "real clip completed")
        let first = audio.$playing.drop(while: { $0 == nil }).filter { $0 == nil }.prefix(1).sink { _ in finished.fulfill() }
        audio.play(clip)
        XCTAssertNil(audio.error)
        XCTAssertEqual(audio.playing, clip)
        await fulfillment(of: [finished], timeout: 5)
        XCTAssertNil(audio.playing)
        first.cancel()

        let replayed = expectation(description: "same clip completed again")
        let second = audio.$playing.drop(while: { $0 == nil }).filter { $0 == nil }.prefix(1).sink { _ in replayed.fulfill() }
        audio.play(clip)
        XCTAssertNil(audio.error)
        XCTAssertEqual(audio.playing, clip, "One tap after completion must restart playback")
        await fulfillment(of: [replayed], timeout: 5)
        XCTAssertNil(audio.playing)
        second.cancel()
    }

    @MainActor func testDamagedClipDoesNotClaimPlayback() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let audio = PageAudio(folder: folder)
        defer { audio.stop(); try? FileManager.default.removeItem(at: folder) }
        let clip = folder.appendingPathComponent("damaged.m4a")
        try Data([1, 2, 3]).write(to: clip)
        audio.play(clip)
        XCTAssertNil(audio.playing)
        XCTAssertNotNil(audio.error)
    }

    /// Valid mono 16-bit PCM WAV, 0.2 seconds at 8 kHz; no microphone or fixtures needed.
    private func shortWave() -> Data {
        let frames = 1600
        var data = Data()
        func word<T: FixedWidthInteger>(_ value: T) {
            var little = value.littleEndian
            withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
        }
        data.append(contentsOf: "RIFF".utf8); word(UInt32(36 + frames * 2))
        data.append(contentsOf: "WAVEfmt ".utf8); word(UInt32(16))
        word(UInt16(1)); word(UInt16(1)); word(UInt32(8000)); word(UInt32(16000))
        word(UInt16(2)); word(UInt16(16))
        data.append(contentsOf: "data".utf8); word(UInt32(frames * 2))
        for frame in 0..<frames { word(Int16(sin(Double(frame) * 2 * .pi * 440 / 8000) * 1000)) }
        return data
    }
}
