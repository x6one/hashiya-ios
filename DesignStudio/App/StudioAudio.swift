import SwiftUI

struct StudioRecordingStrip: View {
    @ObservedObject var session: StudioSession
    @ObservedObject var navigation: StudioNavigation
    var body: some View {
        HStack(spacing: StudioMetrics.compact) {
            Button {
                if session.recording { session.sceneBecameInactive() }
                else { session.beginRecording() }
            } label: {
                Image(systemName: session.recording ? "stop.fill" : "mic")
                    .font(.system(size: StudioMetrics.icon, weight: .medium))
                    .frame(width: StudioMetrics.touch, height: StudioMetrics.touch)
                    .foregroundStyle(session.recording ? StudioTheme.destructive : StudioTheme.primary)
                    .background(session.recording ? StudioTheme.destructive.opacity(0.1) : StudioTheme.selection, in: Circle())
                    .contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel(session.recording ? L("إيقاف وحفظ", "Stop and save") : L("بدء التسجيل", "Start recording"))
                .accessibilityIdentifier("recordAction").accessibilityValue(session.recording ? "recording" : "idle")
            Button { navigation.scene = .audio } label: {
                HStack(spacing: StudioMetrics.compact) {
                    Text(session.recording ? L("جارٍ التسجيل", "Recording") : session.playing ? L("جارٍ التشغيل", "Playing") : L("تسجيلات الصفحة", "Page recordings"))
                        .font(.caption.weight(.semibold)).lineLimit(1)
                    Spacer(minLength: 0)
                    Text(studioTime(session.recording ? session.elapsed : session.playhead))
                        .font(.caption.monospacedDigit()).environment(\.layoutDirection, .leftToRight)
                    Image(systemName: "chevron.up").font(.caption)
                }.frame(height: StudioMetrics.touch).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityIdentifier("openPageAudio")
                .accessibilityHint(L("توسيع تفاصيل التسجيل والعلامات", "Expand recording details and markers"))
        }.padding(.horizontal, StudioMetrics.inset).background(StudioTheme.surface)
            .overlay(alignment: .top) { StudioTheme.divider.frame(height: 0.5) }
    }
}

struct TayyaAudioCard: View {
    @ObservedObject var session: StudioSession
    @State private var renaming = false
    @State private var draft = ""
    var body: some View {
        VStack(spacing: 24) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(session.title).font(.title3.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                    Text(L("مدة التسجيل", "Duration") + " · " + studioTime(session.recording ? session.elapsed : session.duration)).font(.caption).foregroundStyle(StudioTheme.secondary)
                    Label(L("مبادئ المحاسبة · صفحة \(session.page)", "Accounting principles · Page \(session.page)"), systemImage: "doc")
                        .font(.caption).foregroundStyle(StudioTheme.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading)
                TayyaIconButton(title: L("إعادة تسمية التسجيل", "Rename recording"), symbol: "ellipsis") { draft = session.title; renaming = true }
            }
            StudioWaveform(active: session.recording || session.playing).frame(height: 72)
            VStack(spacing: 8) {
                Text(studioTime(session.recording ? session.elapsed : session.playhead)).font(.system(.largeTitle, design: .rounded).monospacedDigit().weight(.medium))
                    .environment(\.layoutDirection, .leftToRight).accessibilityIdentifier("audioTime")
                Label(session.recording ? L("جارٍ التسجيل", "Recording") : (session.playing ? L("جارٍ التشغيل", "Playing") : L("جاهز للتشغيل", "Ready to play")), systemImage: session.recording ? "record.circle.fill" : "waveform")
                    .font(.caption).foregroundStyle(session.recording ? StudioTheme.destructive : StudioTheme.secondary)
            }
            if session.recording {
                TayyaPrimaryButton(title: L("إيقاف وحفظ", "Stop and save"), symbol: "stop.fill") { session.sceneBecameInactive() }
                    .accessibilityIdentifier("audioStop")
            } else {
                VStack(spacing: 12) {
                    Slider(value: Binding(get: { session.playhead }, set: { session.seek(to: $0) }), in: 0...session.duration)
                        .tint(StudioTheme.primary).accessibilityLabel(L("موضع التشغيل", "Playback position"))
                    HStack {
                        Text("00:00"); Spacer(); Text(studioTime(session.duration))
                    }.font(.caption2.monospacedDigit()).foregroundStyle(StudioTheme.secondary).environment(\.layoutDirection, .leftToRight)
                    HStack(spacing: 24) {
                        TayyaIconButton(title: L("تأخير 10 ثوانٍ", "Back 10 seconds"), symbol: "gobackward.10") { session.seek(to: session.playhead - 10) }
                        TayyaIconButton(title: session.playing ? L("إيقاف مؤقت", "Pause") : L("تشغيل", "Play"), symbol: session.playing ? "pause.fill" : "play.fill", selected: true) { session.playing.toggle() }
                        TayyaIconButton(title: L("تقديم 10 ثوانٍ", "Forward 10 seconds"), symbol: "goforward.10") { session.seek(to: session.playhead + 10) }
                    }.environment(\.layoutDirection, .leftToRight)
                    Menu {
                        ForEach([0.75, 1, 1.25, 1.5, 2], id: \.self) { rate in
                            Button("\(rate, specifier: "%g")×") { session.setRate(rate) }
                        }
                    } label: { Text(L("سرعة التشغيل", "Playback speed") + "  \(session.rate.formatted())×").font(.caption).frame(minHeight: 44) }
                }
            }
        }.studioCard(24)
            .alert(L("اسم التسجيل", "Recording title"), isPresented: $renaming) {
                TextField(L("الاسم", "Title"), text: $draft)
                Button(L("حفظ", "Save")) { session.rename(to: draft) }
                Button(L("إلغاء", "Cancel"), role: .cancel) {}
            }
    }
}

struct StudioAudio: View {
    @ObservedObject var session: StudioSession
    @ObservedObject var navigation: StudioNavigation
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TayyaIconButton(title: L("العودة للمستند", "Back to document"), symbol: "chevron.backward") { navigation.scene = .document }
                Text(L("تسجيلات الصفحة", "Page recordings")).font(.headline).frame(maxWidth: .infinity, alignment: .leading)
                TayyaIconButton(title: L("علامة يدوية", "Manual marker"), symbol: "flag") { session.addManualMarker() }
                    .disabled(!session.recording).accessibilityIdentifier("manualMarker")
            }.padding(.horizontal, 12).padding(.vertical, 8).background(StudioTheme.surface)
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text(L("استمع. اكتب. عُد للفكرة.", "Listen. Write. Return to the idea.")).font(.title2.bold())
                    Text(L("جلسة تجريبية مرتبطة بصفحات الدراسة", "A sample session linked to your study pages")).font(.subheadline).foregroundStyle(StudioTheme.secondary)
                    TayyaAudioCard(session: session)
                    TayyaSectionHeader(title: L("علامات هذه الجلسة", "Session markers"), detail: "\(session.markers.count)")
                    VStack(spacing: 0) {
                        ForEach(session.markers) { marker in
                            Button {
                                guard !session.recording else { return }
                                session.activate(marker)
                                navigation.scene = .document
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: marker.kind == "writing" ? "pencil.tip" : marker.kind == "manual" ? "flag" : "doc")
                                        .frame(width: 36, height: 36).background(StudioTheme.selection, in: Circle())
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(marker.label).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                                        Text(session.title + " · " + L("الصفحة \(marker.page)", "Page \(marker.page)")).font(.caption).foregroundStyle(StudioTheme.secondary)
                                    }.frame(maxWidth: .infinity, alignment: .leading)
                                    Text(studioTime(marker.time)).font(.caption.monospacedDigit()).foregroundStyle(StudioTheme.secondary)
                                    Image(systemName: session.playing && session.activeMarkerID == marker.id ? "waveform" : session.recording ? "flag" : "play.fill").font(.caption).foregroundStyle(StudioTheme.primary)
                                }.padding(16).frame(minHeight: 56).contentShape(Rectangle())
                            }.buttonStyle(.plain).foregroundStyle(StudioTheme.text)
                                .background(session.playing && session.activeMarkerID == marker.id ? StudioTheme.selection : Color.clear)
                                .accessibilityValue(session.playing && session.activeMarkerID == marker.id ? "playing" : "idle")
                                .accessibilityHint(session.recording ? L("أوقف التسجيل لتشغيل العلامة", "Stop recording to play this marker") : L("انتقال للصفحة وتشغيل من العلامة", "Go to page and play from marker"))
                                .accessibilityIdentifier("marker-\(marker.kind)-\(marker.page)-\(Int(marker.time))")
                            if marker.id != session.markers.last?.id { Divider().padding(.leading, 64) }
                        }
                    }.background(StudioTheme.surface, in: RoundedRectangle(cornerRadius: 16))
                    Text(L("تتبع العلامات الصفحة والكتابة أثناء الجلسة. يمكنك إضافة علامة يدوية أثناء التسجيل.", "Marks follow pages and writing during a session. Add your own marker while recording."))
                        .font(.caption).foregroundStyle(StudioTheme.secondary).fixedSize(horizontal: false, vertical: true)
                }.padding(24).frame(maxWidth: 720).frame(maxWidth: .infinity)
            }
        }.background(StudioTheme.background)
    }
}

struct StudioCards: View {
    @ObservedObject var navigation: StudioNavigation
    @ObservedObject var session: StudioSession
    @State private var revealed = false
    @State private var index = 1
    @State private var scope = 0
    private var cards: [StudioStudyCard] { navigation.cards.filter { scope == 1 || $0.page == session.page } }
    private var current: StudioStudyCard? { cards.isEmpty ? nil : cards[(index - 1) % cards.count] }
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TayyaIconButton(title: L("العودة للمستند", "Back to document"), symbol: "chevron.backward") { navigation.scene = .document }
                Text(L("مراجعة سريعة", "Quick review")).font(.headline).frame(maxWidth: .infinity, alignment: .leading)
                TayyaIconButton(title: L("إضافة بطاقة", "Add card"), symbol: "plus") { navigation.sheet = .newCard }
            }.padding(12).background(StudioTheme.surface)
            ScrollView {
                VStack(spacing: 24) {
                    Picker(L("نطاق المراجعة", "Review scope"), selection: $scope) {
                        Text(L("هذه الصفحة", "This page")).tag(0)
                        Text(L("هذا الملف", "This document")).tag(1)
                    }.pickerStyle(.segmented).onChange(of: scope) { _, _ in index = 1; revealed = false }
                    Text(L("مبادئ المحاسبة · صفحة \(session.page)", "Accounting principles · Page \(session.page)")).font(.caption).foregroundStyle(StudioTheme.secondary)
                    VStack(spacing: 24) {
                        Image(systemName: revealed ? "checkmark" : "rectangle.stack").font(.title2).foregroundStyle(StudioTheme.copper)
                        Text(revealed ? current?.answer ?? "" : current?.question ?? L("لا توجد بطاقات لهذه الصفحة", "No cards for this page"))
                            .font(.title2.weight(.medium)).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                        Text(revealed ? L("تتوازن الموارد مع مصادر تمويلها.", "Resources balance with their funding sources.") : L("امنح نفسك لحظة للتفكير.", "Give yourself a moment to think."))
                            .font(.subheadline).foregroundStyle(StudioTheme.secondary).multilineTextAlignment(.center)
                    }.frame(maxWidth: .infinity, minHeight: 290).studioCard(24)
                    TayyaPrimaryButton(title: revealed ? L("البطاقة التالية", "Next card") : L("أظهر الإجابة", "Reveal answer"), symbol: revealed ? "chevron.forward" : "eye") {
                        if revealed { index = index % max(1, cards.count) + 1 }
                        revealed.toggle()
                    }.disabled(cards.isEmpty).accessibilityIdentifier("revealAnswer")
                    Text("\(cards.isEmpty ? 0 : index) / \(cards.count)").font(.caption.monospacedDigit()).foregroundStyle(StudioTheme.secondary)
                    if revealed {
                        HStack(spacing: 16) {
                            assessment(L("أتقنها", "Got it"), symbol: "checkmark.circle")
                            assessment(L("راجع لاحقًا", "Review later"), symbol: "clock")
                        }
                    }
                }.padding(24).frame(maxWidth: 620).frame(maxWidth: .infinity)
            }
        }.background(StudioTheme.background)
    }
    private func assessment(_ title: String, symbol: String) -> some View {
        Button { index = index % max(1, cards.count) + 1; revealed = false } label: {
            Label(title, systemImage: symbol).font(.subheadline).frame(maxWidth: .infinity, minHeight: 48).background(StudioTheme.selection, in: RoundedRectangle(cornerRadius: 12))
        }.buttonStyle(.plain)
    }
}
