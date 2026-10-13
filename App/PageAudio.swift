import SwiftUI
import AVFoundation

/// Frequent samples belong to the recording readout, never the PDF workspace.
@MainActor final class RecordingActivity: ObservableObject {
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var level: Double = 0
    @Published private(set) var samples = Array(repeating: 0.0, count: 16)

    func update(elapsed: TimeInterval, averagePower: Float) {
        self.elapsed = elapsed.isFinite ? max(0, elapsed) : 0
        // AVAudioRecorder supplies decibels. Silence and invalid samples stay flat.
        level = averagePower.isFinite ? min(1, max(0, pow(10, Double(averagePower) / 20))) : 0
        samples.removeFirst()
        samples.append(level)
    }

    func reset() {
        elapsed = 0; level = 0
        samples = Array(repeating: 0, count: samples.count)
    }
}

@MainActor final class PageAudio: NSObject, ObservableObject, AVAudioPlayerDelegate, AVAudioRecorderDelegate {
    @Published var clips: [URL] = []
    @Published var recording = false
    @Published private(set) var requestingPermission = false
    @Published var playing: URL?
    @Published var error: String?
    @Published var markers: [AudioLink] = []
    let activity = RecordingActivity()
    let folder: URL
    var recorder: AVAudioRecorder?
    private var generation = 0
    private var player: AVAudioPlayer?
    private weak var playbackPeer: PageAudio?
    private var activityTimer: Timer?
    private var interruptionObserver: NSObjectProtocol?
    private let requestPermission: () async -> Bool
    init(folder: URL, requestPermission: @escaping () async -> Bool = {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) }
        }
    }) {
        self.folder = folder; self.requestPermission = requestPermission
        super.init()
        reload()
        interruptionObserver = NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] notification in
            guard let type = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  type == AVAudioSession.InterruptionType.began.rawValue else { return }
            Task { @MainActor [weak self] in self?.stop() }
        }
    }
    deinit {
        activityTimer?.invalidate()
        if let interruptionObserver { NotificationCenter.default.removeObserver(interruptionObserver) }
        recorder?.stop(); player?.stop()
    }
    /// The legacy destination and linked sheet retain separate folders and files.
    /// Weak peers only hand off playback while those screens are alive.
    func coordinatePlayback(with other: PageAudio) {
        guard other !== self else { return }
        playbackPeer = other
        other.playbackPeer = self
    }
    func stopPlayback() {
        guard player != nil || playing != nil else { return }
        player?.stop(); player = nil; playing = nil
        deactivateAudioSession()
    }
    func reload() {
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            clips = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.creationDateKey]).filter { $0.pathExtension == "m4a" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
            markers = loadLinks().filter { marker in clips.contains { $0.lastPathComponent == marker.clip } }
        } catch { self.error = error.localizedDescription }
    }
    func start() async {
        guard !recording, !requestingPermission,
              playbackPeer?.recording != true, playbackPeer?.requestingPermission != true else { return }
        stopActivity()
        requestingPermission = true
        error = nil
        generation += 1; let token = generation
        defer { if token == generation { requestingPermission = false } }
        let allowed = await requestPermission()
        guard token == generation else { return }
        guard allowed else { error = "اسمح لطَيّة باستخدام الميكروفون من إعدادات الجهاز."; return }
        guard playbackPeer?.recording != true, playbackPeer?.requestingPermission != true else { return }
        do {
            stopPlayback(); playbackPeer?.stopPlayback()
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try AVAudioSession.sharedInstance().setActive(true)
            let url = folder.appendingPathComponent("\(Int(Date().timeIntervalSince1970))-\(UUID().uuidString.prefix(6)).m4a")
            let recorder = try AVAudioRecorder(url: url, settings: [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 44100, AVNumberOfChannelsKey: 1, AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue])
            recorder.delegate = self
            recorder.isMeteringEnabled = true
            guard recorder.record() else { throw CocoaError(.fileWriteUnknown) }
            self.recorder = recorder; recording = true
            startActivity()
        } catch {
            stopActivity()
            self.error = error.localizedDescription
            deactivateAudioSession()
        }
    }
    private func startActivity() {
        activityTimer?.invalidate()
        sampleActivity()
        let timer = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.sampleActivity() }
        }
        activityTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }
    private func sampleActivity() {
        guard recording, let recorder, recorder.isRecording else {
            stopActivity()
            return
        }
        recorder.updateMeters()
        activity.update(elapsed: recorder.currentTime, averagePower: recorder.averagePower(forChannel: 0))
    }
    private func stopActivity() {
        activityTimer?.invalidate(); activityTimer = nil
        activity.reset()
    }
    func handleScenePhase(_ phase: ScenePhase) {
        // The permission alert may deactivate the scene before recording starts.
        // Existing recording/playback must stop on calls or other interruptions.
        if phase == .background || (phase == .inactive && (recording || playing != nil)) { stop() }
    }
    func stop() {
        let wasUsingAudioSession = recorder != nil || player != nil
        generation += 1
        requestingPermission = false
        stopActivity()
        recorder?.stop(); recorder = nil; recording = false
        player?.stop(); player = nil; playing = nil
        // An idle legacy destination must not deactivate its peer's new playback.
        if wasUsingAudioSession { deactivateAudioSession() }
        reload()
    }
    func play(_ url: URL, at time: TimeInterval = 0) {
        guard !recording, !requestingPermission,
              playbackPeer?.recording != true, playbackPeer?.requestingPermission != true else { return }
        if playing == url && time == 0 {
            player?.stop(); player = nil; playing = nil
            deactivateAudioSession()
            return
        }
        player?.stop(); player = nil; playing = nil
        playbackPeer?.stopPlayback()
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
            self.stopActivity()
            self.recorder = nil; self.recording = false
            if !flag { self.error = "تعذّر إكمال التسجيل. تحقق من التسجيلات المحفوظة." }
            self.reload()
            self.deactivateAudioSession()
        }
    }
    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor [weak self] in
            guard let self, self.recorder === recorder else { return }
            self.stopActivity()
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
    private let playbackPeer: PageAudio?
    init(folder: URL, allowRecording: Bool = true, playbackPeer: PageAudio? = nil) {
        self.allowRecording = allowRecording
        self.playbackPeer = playbackPeer
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
        }.environment(\.layoutDirection, .rightToLeft)
            .onAppear {
                if let playbackPeer {
                    audio.coordinatePlayback(with: playbackPeer)
                    playbackPeer.stopPlayback()
                }
            }
            .onDisappear { audio.stop() }
            .onChange(of: scenePhase) { _, phase in audio.handleScenePhase(phase) }
    }
}
