import SwiftUI
import AVFoundation

@MainActor final class PageAudio: ObservableObject {
    @Published var clips: [URL] = []
    @Published var recording = false
    @Published var playing: URL?
    @Published var error: String?
    @Published var markers: [AudioLink] = []
    let folder: URL
    var recorder: AVAudioRecorder?
    private var generation = 0
    private var player: AVAudioPlayer?
    init(folder: URL) { self.folder = folder; reload() }
    func reload() {
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            markers = loadLinks()
            clips = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.creationDateKey]).filter { $0.pathExtension == "m4a" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        } catch { self.error = error.localizedDescription }
    }
    func start() async {
        guard !recording else { return }
        generation += 1; let token = generation
        let allowed = await withCheckedContinuation { continuation in AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) } }
        guard token == generation else { return }
        guard allowed else { error = "اسمح لطَيّة باستخدام الميكروفون من إعدادات الجهاز."; return }
        do {
            player?.stop(); playing = nil
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try AVAudioSession.sharedInstance().setActive(true)
            let url = folder.appendingPathComponent("\(Int(Date().timeIntervalSince1970))-\(UUID().uuidString.prefix(6)).m4a")
            let recorder = try AVAudioRecorder(url: url, settings: [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 44100, AVNumberOfChannelsKey: 1, AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue])
            guard recorder.record() else { throw CocoaError(.fileWriteUnknown) }
            self.recorder = recorder; recording = true
        } catch { self.error = error.localizedDescription }
    }
    func stop() {
        generation += 1
        recorder?.stop(); recorder = nil; recording = false
        player?.stop(); playing = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        reload()
    }
    func play(_ url: URL, at time: TimeInterval = 0) {
        if playing == url && time == 0 { player?.stop(); playing = nil; return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
            player = try AVAudioPlayer(contentsOf: url); player?.currentTime = time; player?.play(); playing = url
        } catch { self.error = error.localizedDescription }
    }
    func delete(_ url: URL) {
        do { if playing == url { player?.stop(); playing = nil }; try FileManager.default.removeItem(at: url); reload() }
        catch { self.error = error.localizedDescription }
    }
}
struct PageAudioScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var audio: PageAudio
    init(folder: URL) { _audio = StateObject(wrappedValue: PageAudio(folder: folder)) }
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button(audio.recording ? "إيقاف وحفظ التسجيل" : "تسجيل صوت للصفحة", systemImage: audio.recording ? "stop.circle.fill" : "mic.circle") {
                        if audio.recording { audio.stop() } else { Task { await audio.start() } }
                    }.tint(audio.recording ? .red : .blue)
                    Text("التسجيلات محفوظة على جهازك ومرتبطة بهذه الصفحة.").font(.caption).foregroundStyle(.secondary)
                }
                ForEach(audio.clips, id: \.self) { url in
                    Button(audio.playing == url ? "إيقاف التشغيل" : url.deletingPathExtension().lastPathComponent, systemImage: audio.playing == url ? "stop.fill" : "play.fill") { audio.play(url) }
                        .disabled(audio.recording)
                        .swipeActions { Button("حذف", role: .destructive) { audio.delete(url) } }
                }
            }.navigationTitle("صوت الصفحة").toolbar { Button("تم") { audio.stop(); dismiss() } }
                .alert("الصوت", isPresented: Binding(get: { audio.error != nil }, set: { if !$0 { audio.error = nil } })) { Button("حسناً") { audio.error = nil } } message: { Text(audio.error ?? "") }
        }.environment(\.layoutDirection, .rightToLeft).onDisappear { audio.stop() }
            .onChange(of: scenePhase) { _, phase in if phase != .active { audio.stop() } }
    }
}
