import Foundation
import AVFoundation

struct AudioClipMetadata: Codable {
    var title: String
    var created: Date
    var duration: TimeInterval
    var startPage: Int?
    var startPageID: UUID?
    var sourceDeleted: Bool?
}

extension PageAudio {
    var metadataURL: URL { folder.appendingPathComponent("recordings.json") }
    func readMetadata() throws -> [String: AudioClipMetadata] {
        guard FileManager.default.fileExists(atPath: metadataURL.path) else { return [:] }
        let values = try JSONDecoder().decode([String: AudioClipMetadata].self, from: Data(contentsOf: metadataURL))
        guard values.allSatisfy({ name, value in
            !name.isEmpty && name != "." && name != ".." && (name as NSString).lastPathComponent == name
                && !name.contains("\\") && value.duration.isFinite && value.duration >= 0
                && (value.startPage == nil || value.startPage! > 0)
        }) else { throw CocoaError(.fileReadCorruptFile) }
        return values
    }
    func clipMetadata(_ clip: URL) -> AudioClipMetadata {
        if let value = metadata[clip.lastPathComponent] { return value }
        // Old M4A files need no migration or filename change merely to display.
        let date = (try? clip.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
        let duration = (try? AVAudioPlayer(contentsOf: clip).duration) ?? 0
        return AudioClipMetadata(title: clip.deletingPathExtension().lastPathComponent,
                                 created: date, duration: duration,
                                 startPage: markers.first { $0.clip == clip.lastPathComponent }?.page ?? Int(folder.lastPathComponent))
    }
    func rename(_ clip: URL, title: String) {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard owns(clip), !title.isEmpty else { return }
        do {
            var values = try readMetadata()
            var value = clipMetadata(clip); value.title = title
            values[clip.lastPathComponent] = value
            try JSONEncoder().encode(values).write(to: metadataURL, options: .atomic)
            metadata = values
        } catch { self.error = error.localizedDescription }
    }
    func saveRecordingMetadata(_ clip: URL, duration: TimeInterval, startPage: Int?, pageID: UUID?) throws {
        var values = try readMetadata()
        let previous = values[clip.lastPathComponent]
        values[clip.lastPathComponent] = AudioClipMetadata(title: previous?.title ?? TayyaLocalized("تسجيل الدراسة"),
            created: previous?.created ?? Date(), duration: max(0, duration), startPage: startPage, startPageID: pageID)
        try JSONEncoder().encode(values).write(to: metadataURL, options: .atomic)
        metadata = values
    }
    func owns(_ clip: URL) -> Bool {
        clip.deletingLastPathComponent().resolvingSymlinksInPath().standardizedFileURL.path == folder.resolvingSymlinksInPath().standardizedFileURL.path
            && clip.resolvingSymlinksInPath().deletingLastPathComponent().standardizedFileURL.path == folder.resolvingSymlinksInPath().standardizedFileURL.path
    }
}
