import XCTest
import AVFoundation

/// Isolate native AAC semantics from PageAudio before another production fix.
final class StudioAudioNativeProbeTests: XCTestCase {
    @MainActor func testPreparedAndPausedAACOffsetsAgainstRealPlaybackWithAndWithoutRate() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".m4a")
        defer { try? FileManager.default.removeItem(at: url) }
        try m4a(at: url)
        try AVAudioSession.sharedInstance().setCategory(.playback)
        try AVAudioSession.sharedInstance().setActive(true)
        defer { try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation) }
        for enableRate in [false, true] {
            for target in [1.25, 3.99] {
                let player = try AVAudioPlayer(contentsOf: url)
                player.enableRate = enableRate; player.rate = 1
                XCTAssertTrue(player.prepareToPlay())
                player.currentTime = target
                print("NativeAACProbe stage=prepared rate=\(enableRate) target=\(target) actual=\(player.currentTime) duration=\(player.duration)")
                XCTAssertTrue(player.play())
                print("NativeAACProbe stage=playing rate=\(enableRate) target=\(target) actual=\(player.currentTime) playing=\(player.isPlaying)")
                player.pause(); player.currentTime = 0.75
                print("NativeAACProbe stage=paused rate=\(enableRate) target=0.75 actual=\(player.currentTime)")
                XCTAssertTrue(player.play())
                print("NativeAACProbe stage=resumed rate=\(enableRate) target=0.75 actual=\(player.currentTime)")
                XCTAssertEqual(player.currentTime, 0.75, accuracy: 0.2, "Observe the actual decoded start, independently of paused getter reporting")
                player.stop()
            }
        }
    }
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
