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

struct LinkedAudioScreen: View {
    @ObservedObject var audio: PageAudio
    let jump: (Int) -> Void
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                if audio.markers.isEmpty { Text("ستظهر هنا الأوقات المرتبطة بالكتابة أثناء التسجيل.").foregroundStyle(.secondary) }
                ForEach(audio.markers) { marker in
                    Button {
                        jump(marker.page); audio.seek(marker)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("\(Int(marker.time / 60)):\(String(format: "%02d", Int(marker.time) % 60)) — صفحة \(marker.page)", systemImage: "play.circle")
                            Text(marker.label).font(.caption).foregroundStyle(.secondary)
                        }
                    }.disabled(audio.recording)
                }
                Section("التسجيلات الكاملة") {
                    ForEach(audio.clips, id: \.self) { clip in Button(clip.deletingPathExtension().lastPathComponent, systemImage: "play.fill") { audio.play(clip) }.disabled(audio.recording) }
                }
            }.navigationTitle("التسجيلات المرتبطة").toolbar { Button("تم") { dismiss() } }
        }.environment(\.layoutDirection, .rightToLeft)
    }
}
