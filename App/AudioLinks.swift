import Foundation
import SwiftUI
struct AudioLink: Codable, Identifiable {
    var id = UUID()
    var clip: String
    var time: Double
    var page: Int
    var textID: UUID?
    var strokeCount: Int?
    var label: String
    var pageID: UUID?
    var notePageID: UUID?
    var kind: String?
}
extension PageAudio {
    var linksURL: URL { folder.appendingPathComponent("links.json") }
    func loadLinks() -> [AudioLink] {
        do { return try readLinks() }
        catch { self.error = error.localizedDescription; return [] }
    }
    /// A damaged existing index is not a new empty library. Every writer uses
    /// this throwing read before touching recordings or their marker bytes.
    func readLinks() throws -> [AudioLink] {
        guard FileManager.default.fileExists(atPath: linksURL.path) else { return [] }
        let links = try JSONDecoder().decode([AudioLink].self, from: Data(contentsOf: linksURL))
        guard Set(links.map(\.id)).count == links.count,
              links.allSatisfy({ $0.page > 0 && $0.time.isFinite && $0.time >= 0
                  && !$0.clip.isEmpty && $0.clip != "." && $0.clip != ".."
                  && ($0.clip as NSString).lastPathComponent == $0.clip
                  && !$0.clip.contains("\\") }) else { throw CocoaError(.fileReadCorruptFile) }
        return links
    }
    func link(page: Int, pageID: UUID? = nil, notePageID: UUID? = nil, kind: String? = nil, textID: UUID? = nil, strokeCount: Int? = nil, label: String) throws {
        guard let recorder, recording else { return }
        var links = try readLinks()
        if kind != "manual", let last = links.last, last.clip == recorder.url.lastPathComponent, last.page == page, last.textID == textID, last.strokeCount == strokeCount, last.notePageID == notePageID, last.kind == kind, recorder.currentTime - last.time < 1 { return }
        links.append(AudioLink(clip: recorder.url.lastPathComponent, time: recorder.currentTime, page: page, textID: textID, strokeCount: strokeCount, label: label, pageID: pageID, notePageID: notePageID, kind: kind))
        try JSONEncoder().encode(links).write(to: linksURL, options: .atomic)
        markers = links
    }
    func seek(_ marker: AudioLink) {
        let target = folder.appendingPathComponent(marker.clip)
        play(target, at: marker.time)
    }
}
