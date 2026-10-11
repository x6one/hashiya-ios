import SwiftUI
import AVFoundation

@MainActor final class PageAudio: NSObject, ObservableObject, AVAudioPlayerDelegate, AVAudioRecorderDelegate {
    @Published var clips: [URL] = []
    @Published var recording = false
    @Published private(set) var requestingPermission = false
    @Published var playing: URL?
    @Published var error: String?
    @Published var markers: [AudioLink] = []
    let folder: URL
    var recorder: AVAudioRecorder?
    private var generation = 0
    private var player: AVAudioPlayer?
    private let requestPermission: () async -> Bool
    init(folder: URL, requestPermission: @escaping () async -> Bool = {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) }
        }
    }) {
        self.folder = folder; self.requestPermission = requestPermission
        super.init()
        reload()
    }
    func reload() {
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            clips = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.creationDateKey]).filter { $0.pathExtension == "m4a" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
            markers = loadLinks().filter { marker in clips.contains { $0.lastPathComponent == marker.clip } }
        } catch { self.error = error.localizedDescription }
    }
    func start() async {
        guard !recording, !requestingPermission else { return }
        requestingPermission = true
        error = nil
        generation += 1; let token = generation
        defer { if token == generation { requestingPermission = false } }
        let allowed = await requestPermission()
        guard token == generation else { return }
        guard allowed else { error = "اسمح لطَيّة باستخدام الميكروفون من إعدادات الجهاز."; return }
        do {
            player?.stop(); player = nil; playing = nil
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try AVAudioSession.sharedInstance().setActive(true)
            let url = folder.appendingPathComponent("\(Int(Date().timeIntervalSince1970))-\(UUID().uuidString.prefix(6)).m4a")
            let recorder = try AVAudioRecorder(url: url, settings: [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 44100, AVNumberOfChannelsKey: 1, AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue])
            recorder.delegate = self
            guard recorder.record() else { throw CocoaError(.fileWriteUnknown) }
            self.recorder = recorder; recording = true
        } catch { self.error = error.localizedDescription }
    }
    func handleScenePhase(_ phase: ScenePhase) {
        // The permission alert may deactivate the scene before recording starts.
        // Existing recording/playback must stop on calls or other interruptions.
        if phase == .background || (phase == .inactive && (recording || playing != nil)) { stop() }
    }
    func stop() {
        generation += 1
        requestingPermission = false
        recorder?.stop(); recorder = nil; recording = false
        player?.stop(); player = nil; playing = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        reload()
    }
    func play(_ url: URL, at time: TimeInterval = 0) {
        guard !recording, !requestingPermission else { return }
        if playing == url && time == 0 {
            player?.stop(); player = nil; playing = nil
            deactivateAudioSession()
            return
        }
        player?.stop(); player = nil; playing = nil
        error = nil
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
            let next = try AVAudioPlayer(contentsOf: url)
            next.delegate = self
            next.currentTime = max(0, time)
            guard next.play() else { throw CocoaError(.fileReadUnknown) }
            player = next
            playing = url
        } catch {
            self.error = error.localizedDescription
            deactivateAudioSession()
        }
    }
    private func deactivateAudioSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            guard let self, self.player === player else { return }
            self.player = nil; self.playing = nil
            if !flag { self.error = "تعذّر إكمال تشغيل التسجيل." }
            self.deactivateAudioSession()
        }
    }
    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor [weak self] in
            guard let self, self.player === player else { return }
            self.player?.stop(); self.player = nil; self.playing = nil
            self.error = error?.localizedDescription ?? "تعذّر قراءة التسجيل."
            self.deactivateAudioSession()
        }
    }
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            guard let self, self.recorder === recorder else { return }
            self.recorder = nil; self.recording = false
            if !flag { self.error = "تعذّر إكمال التسجيل. تحقق من التسجيلات المحفوظة." }
            self.reload()
            self.deactivateAudioSession()
        }
    }
    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor [weak self] in
            guard let self, self.recorder === recorder else { return }
            self.recorder?.stop(); self.recorder = nil; self.recording = false
            self.error = error?.localizedDescription ?? "تعذّر حفظ التسجيل."
            self.reload()
            self.deactivateAudioSession()
        }
    }
    func delete(_ url: URL) {
        // Directory enumeration and appendingPathComponent can represent the
        // same folder with different trailing-slash URL metadata. Compare
        // canonical filesystem paths, while still rejecting outside clips.
        guard !recording, !requestingPermission, url.deletingLastPathComponent().resolvingSymlinksInPath().standardizedFileURL.path == folder.resolvingSymlinksInPath().standardizedFileURL.path else { return }
        let retained = loadLinks().filter { $0.clip != url.lastPathComponent }
        let parked = folder.appendingPathComponent(".deleting-" + UUID().uuidString)
        do {
            let data = try JSONEncoder().encode(retained)
            if playing == url { player?.stop(); player = nil; playing = nil; deactivateAudioSession() }
            try FileManager.default.moveItem(at: url, to: parked)
            do { try data.write(to: linksURL, options: .atomic) }
            catch { try? FileManager.default.moveItem(at: parked, to: url); throw error }
            try FileManager.default.removeItem(at: parked)
            reload()
        }
        catch { self.error = error.localizedDescription }
    }
}
struct PageAudioScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var audio: PageAudio
    @State private var deletingClip: URL?
    let allowRecording: Bool
    init(folder: URL, allowRecording: Bool = true) {
        self.allowRecording = allowRecording
        _audio = StateObject(wrappedValue: PageAudio(folder: folder))
    }
    var body: some View {
        NavigationStack {
            List {
                Section {
                    if allowRecording {
                        Button(audio.recording ? "إيقاف وحفظ التسجيل" : "تسجيل صوت للصفحة", systemImage: audio.recording ? "stop.circle.fill" : "mic.circle") {
                            if audio.recording { audio.stop() } else { Task { await audio.start() } }
                        }.tint(audio.recording ? .red : TayyaTheme.ink).disabled(audio.requestingPermission)
                    }
                    Text("التسجيلات محفوظة على جهازك ومرتبطة بهذه الصفحة.").font(.caption).foregroundStyle(.secondary)
                }
                ForEach(audio.clips, id: \.self) { url in
                    Button(audio.playing == url ? "إيقاف التشغيل" : url.deletingPathExtension().lastPathComponent, systemImage: audio.playing == url ? "stop.fill" : "play.fill") { audio.play(url) }
                        .disabled(audio.recording || audio.requestingPermission)
                        .swipeActions { Button("حذف", role: .destructive) { deletingClip = url } }
                }
            }.navigationTitle("تسجيلات الصفحة").toolbar { Button("تم") { audio.stop(); dismiss() } }
                .confirmationDialog("حذف التسجيل نهائيًا؟", isPresented: Binding(get: { deletingClip != nil }, set: { if !$0 { deletingClip = nil } }), titleVisibility: .visible) {
                    Button("حذف التسجيل", role: .destructive) {
                        if let deletingClip { audio.delete(deletingClip) }
                        deletingClip = nil
                    }
                    Button("إلغاء", role: .cancel) { deletingClip = nil }
                }
                .alert("الصوت", isPresented: Binding(get: { audio.error != nil }, set: { if !$0 { audio.error = nil } })) { Button("حسناً") { audio.error = nil } } message: { Text(audio.error ?? "") }
        }.environment(\.layoutDirection, .rightToLeft).onDisappear { audio.stop() }
            .onChange(of: scenePhase) { _, phase in audio.handleScenePhase(phase) }
    }
}
