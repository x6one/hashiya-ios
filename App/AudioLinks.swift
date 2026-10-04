import Foundation
struct AudioLink: Codable, Identifiable {
    var id = UUID()
    var clip: String
    var time: Double
    var page: Int
    var textID: UUID?
    var strokeCount: Int?
    var label: String
}
extension PageAudio {
    var linksURL: URL { folder.appendingPathComponent("links.json") }
    func loadLinks() -> [AudioLink] {
        (try? JSONDecoder().decode([AudioLink].self, from: Data(contentsOf: linksURL))) ?? []
    }
    func link(page: Int, textID: UUID? = nil, strokeCount: Int? = nil, label: String) throws {
        guard let recorder, recording else { return }
        var links = loadLinks()
        if let last = links.last, last.clip == recorder.url.lastPathComponent, last.page == page, last.textID == textID, last.strokeCount == strokeCount, recorder.currentTime - last.time < 1 { return }
        links.append(AudioLink(clip: recorder.url.lastPathComponent, time: recorder.currentTime, page: page, textID: textID, strokeCount: strokeCount, label: label))
        try JSONEncoder().encode(links).write(to: linksURL, options: .atomic)
        markers = links
    }
    func seek(_ marker: AudioLink) {
        let target = folder.appendingPathComponent(marker.clip)
        play(target, at: marker.time)
    }
}
