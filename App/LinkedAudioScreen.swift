import SwiftUI

struct LinkedAudioScreen: View {
    @ObservedObject var audio: PageAudio
    let currentPage: Int
    let jump: (AudioLink) -> Bool
    let manualMarker: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var legacyPages: [LegacyPageRecordings] = []
    @State private var deleting: URL?
    @State private var onlyCurrentPage = false
    @State private var renaming: URL?
    @State private var sharing: URL?

    private var markers: [AudioLink] {
        audio.markers.filter { !onlyCurrentPage || $0.page == currentPage }
    }
    private var clips: [URL] {
        audio.clips.filter { clip in
            !onlyCurrentPage || audio.markers.contains { $0.clip == clip.lastPathComponent && $0.page == currentPage }
        }
    }
    var body: some View {
        NavigationStack {
            List {
                if audio.recording {
                    Section {
                        RecordingStrip(audio: audio, compact: true, action: audio.stop)
                        Button(TayyaLocalized("إضافة علامة يدوية"), systemImage: "bookmark.badge.plus", action: manualMarker)
                            .frame(minHeight: TayyaMetrics.touch).accessibilityIdentifier("addAudioMarker")
                        Button(TayyaLocalized("إيقاف وحفظ التسجيل"), systemImage: "stop.circle", action: audio.stop)
                            .frame(minHeight: TayyaMetrics.touch).accessibilityIdentifier("stopLinkedRecording")
                    }
                }
                Section {
                    Picker(TayyaLocalized("نطاق التسجيلات"), selection: $onlyCurrentPage) {
                        Text(TayyaLocalized("كل المستند")).tag(false)
                        Text(TayyaLocalized("الصفحة الحالية")).tag(true)
                    }.pickerStyle(.menu)
                }
                if clips.isEmpty && legacyPages.isEmpty && !audio.recording {
                    ContentUnavailableView(TayyaLocalized("لا توجد تسجيلات"), systemImage: "waveform",
                        description: Text(TayyaLocalized("ابدأ التسجيل من أدوات الدراسة. يبقى عرض المستند والملاحظات كما اخترته.")))
                }
                Section(TayyaLocalized("أوقات الكتابة")) {
                    if markers.isEmpty {
                        Text(TayyaLocalized("تُحفظ أوقات الكتابة تلقائيًا أثناء التسجيل."))
                            .font(.caption).foregroundStyle(TayyaTheme.detail)
                    }
                    ForEach(markers) { marker in
                        Button {
                            guard jump(marker) else { return }
                            audio.seek(marker)
                            if audio.playing != nil { dismiss() }
                        } label: {
                            HStack(spacing: TayyaMetrics.compact) {
                                Image(systemName: audio.playing?.lastPathComponent == marker.clip ? "waveform.circle.fill" : "play.circle")
                                    .font(.title2)
                                VStack(alignment: .leading, spacing: TayyaMetrics.unit) {
                                    Text(String(format: TayyaLocalized("صفحة %d — %@"), marker.page, audioTime(marker.time)))
                                    Text(marker.label).font(.caption).foregroundStyle(TayyaTheme.detail)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }.frame(minHeight: TayyaMetrics.touch, alignment: .leading)
                        }.disabled(audio.recording || audio.requestingPermission)
                            .accessibilityIdentifier("audioMarker-" + marker.id.uuidString)
                    }
                }
                Section(TayyaLocalized("التسجيلات الكاملة")) {
                    ForEach(clips, id: \.self) { clip in
                        LinkedAudioCard(audio: audio, clip: clip, rename: { renaming = clip },
                                        share: { sharing = clip }, delete: { deleting = clip })
                    }
                }
                if !legacyPages.isEmpty {
                    Section(TayyaLocalized("تسجيلات الصفحات السابقة")) {
                        ForEach(legacyPages) { entry in
                            NavigationLink {
                                PageAudioScreen(folder: entry.folder, allowRecording: false, playbackPeer: audio)
                            } label: {
                                Label(String(format: TayyaLocalized(entry.archived ? "صفحة محذوفة %d" : "صفحة %d"), entry.page), systemImage: "waveform")
                            }.disabled(audio.recording || audio.requestingPermission)
                                .accessibilityIdentifier("legacyPageRecording-\(entry.page)")
                        }
                    }
                }
            }.scrollContentBackground(.hidden).background(TayyaTheme.paper)
                .navigationTitle(TayyaLocalized("التسجيلات"))
                .toolbar { Button(TayyaLocalized("تم")) { dismiss() } }
                .confirmationDialog(TayyaLocalized("حذف التسجيل وروابطه نهائيًا؟"),
                    isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
                    Button(TayyaLocalized("حذف التسجيل"), role: .destructive) {
                        if let deleting { audio.delete(deleting) }; deleting = nil
                    }
                    Button(TayyaLocalized("إلغاء"), role: .cancel) { deleting = nil }
                }
                .alert(TayyaLocalized("الصوت"), isPresented: Binding(get: { audio.error != nil }, set: { if !$0 { audio.error = nil } })) {
                    Button(TayyaLocalized("حسنًا")) { audio.error = nil }
                } message: { Text(audio.error ?? "") }
                .sheet(isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
                    if let clip = renaming { RecordingNameEditor(audio: audio, clip: clip) }
                }
                .sheet(isPresented: Binding(get: { sharing != nil }, set: { if !$0 { sharing = nil } })) {
                    if let clip = sharing { ShareDocument(url: clip) }
                }
        }.onAppear {
            audio.reload()
            legacyPages = LegacyPageRecordings.folders(in: audio.folder.deletingLastPathComponent())
                + LegacyPageRecordings.archivedFolders(in: audio.folder.deletingLastPathComponent())
        }
        // Marker playback continues in the retained document owner after dismiss.
        // Document exit, interruptions and background still stop the real engine.
    }
}

private struct LinkedAudioCard: View {
    @ObservedObject var audio: PageAudio
    let clip: URL
    let rename: () -> Void
    let share: () -> Void
    let delete: () -> Void
    var body: some View {
        let metadata = audio.clipMetadata(clip)
        VStack(alignment: .leading, spacing: TayyaMetrics.compact) {
            Text(metadata.title).font(.headline).fixedSize(horizontal: false, vertical: true)
            Text(metadata.created, format: .dateTime.year().month().day().hour().minute())
                .font(.caption).foregroundStyle(TayyaTheme.detail)
            HStack {
                Text(audioTime(metadata.duration)).monospacedDigit().accessibilityIdentifier("linkedRecordingDuration")
                if let page = metadata.startPage { Text(String(format: TayyaLocalized("صفحة %d"), page)) }
                if metadata.sourceDeleted == true { Text(TayyaLocalized("الصفحة المصدر محذوفة؛ التسجيل محفوظ")) }
            }.font(.caption).foregroundStyle(TayyaTheme.detail)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: TayyaMetrics.compact) {
                    TayyaIconButton(title: audio.playing == clip && !audio.paused ? "إيقاف مؤقت" : "تشغيل", symbol: audio.playing == clip && !audio.paused ? "pause.fill" : "play.fill") {
                        audio.togglePlayback(clip)
                    }.accessibilityIdentifier("playLinkedRecording")
                        .accessibilityValue(audio.playing == clip ? audio.paused ? "paused" : "playing" : "stopped")
                    TayyaIconButton(title: "إعادة تسمية التسجيل", symbol: "pencil", action: rename)
                        .accessibilityIdentifier("renameLinkedRecording")
                    TayyaIconButton(title: "مشاركة M4A", symbol: "square.and.arrow.up", action: share)
                        .accessibilityIdentifier("shareLinkedRecording")
                    TayyaIconButton(title: "حذف", symbol: "trash", action: delete)
                        .accessibilityIdentifier("deleteLinkedRecording")
                }
            }.disabled(audio.recording || audio.requestingPermission)
            if audio.playing == clip { AudioPlaybackControls(audio: audio) }
        }.padding(.vertical, TayyaMetrics.compact)
            .listRowBackground(TayyaTheme.surface)
    }
}

struct AudioPlaybackControls: View {
    @ObservedObject var audio: PageAudio
    var body: some View {
        VStack(spacing: TayyaMetrics.unit) {
            PlaybackTimeReadout(activity: audio.playbackActivity)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: TayyaMetrics.compact) {
                    TayyaIconButton(title: "تأخير 10 ثوانٍ", symbol: "gobackward.10") { audio.skipPlayback(by: -10) }
                        .accessibilityIdentifier("rewindLinkedRecording")
                    TayyaIconButton(title: audio.paused ? "متابعة التشغيل" : "إيقاف مؤقت", symbol: audio.paused ? "play.fill" : "pause.fill") {
                        if let clip = audio.playing { audio.togglePlayback(clip) }
                    }.accessibilityIdentifier("pauseLinkedRecording")
                    TayyaIconButton(title: "تقديم 10 ثوانٍ", symbol: "goforward.10") { audio.skipPlayback(by: 10) }
                        .accessibilityIdentifier("forwardLinkedRecording")
                    Menu {
                        ForEach([0.5, 0.75, 1, 1.25, 1.5, 2], id: \.self) { rate in
                            Button("\(rate.formatted())×") { audio.setPlaybackRate(Float(rate)) }
                        }
                    } label: {
                        Text("\(Double(audio.playbackRate).formatted())×")
                            .frame(minWidth: TayyaMetrics.touch, minHeight: TayyaMetrics.touch)
                    }.accessibilityLabel(TayyaLocalized("سرعة التشغيل")).accessibilityIdentifier("playbackRate")
                }
            }
        }
    }
}

private struct PlaybackTimeReadout: View {
    @ObservedObject var activity: PlaybackActivity
    var body: some View {
        Text(audioTime(activity.time) + " / " + audioTime(activity.duration))
            .font(.caption.monospacedDigit()).foregroundStyle(TayyaTheme.detail)
            .accessibilityIdentifier("playbackElapsed")
    }
}

private struct RecordingNameEditor: View {
    @ObservedObject var audio: PageAudio
    let clip: URL
    @State private var title = ""
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form { TextField(TayyaLocalized("اسم التسجيل"), text: $title).accessibilityIdentifier("recordingTitle") }
                .navigationTitle(TayyaLocalized("إعادة تسمية التسجيل"))
                .toolbar {
                    Button(TayyaLocalized("حفظ")) {
                        audio.rename(clip, title: title)
                        if audio.error == nil { dismiss() }
                    }.disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("saveRecordingTitle")
                    Button(TayyaLocalized("إلغاء")) { dismiss() }
                }
        }.onAppear { title = audio.clipMetadata(clip).title }
    }
}

func audioTime(_ value: TimeInterval) -> String {
    let seconds = Int(value.isFinite ? max(0, value) : 0)
    return seconds >= 3600 ? String(format: "%d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60)
        : String(format: "%d:%02d", seconds / 60, seconds % 60)
}
