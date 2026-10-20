import Combine
import Foundation

struct StudioMarker: Identifiable {
    let id = UUID()
    let page: Int
    let time: Double
    let label: String
    let kind: String
}

/// In-memory design demonstrator; never opens production files or a microphone.
final class StudioSession: ObservableObject {
    @Published var page = 7
    @Published var lastVisitedPage: Int?
    @Published var activeMarkerID: UUID?
    @Published var recording = false
    @Published var playing = false
    @Published var elapsed: Double = 0
    @Published var playhead: Double = 138
    @Published var rate: Double = 1
    @Published var title = "محاضرة المحاسبة"
    @Published var markers: [StudioMarker] = []
    @Published var marginOpen = false
    let totalPages = 24
    let duration: Double = 760
    let clipReference = "sample-session.m4a"

    func beginRecording() {
        guard !recording else { return }
        playing = false
        elapsed = 0
        recording = true
        markers = [StudioMarker(page: page, time: 0, label: L("بداية التسجيل", "Recording begins"), kind: "page")]
    }
    func tick(seconds: Double) {
        guard seconds.isFinite, seconds > 0 else { return }
        if recording { elapsed += seconds }
        else if playing { playhead = min(duration, playhead + seconds * rate); if playhead == duration { playing = false } }
    }
    func changePage(to value: Int) {
        let next = min(totalPages, max(1, value))
        guard page != next else { return }
        lastVisitedPage = page
        page = next
        if recording { markers.append(StudioMarker(page: page, time: elapsed, label: L("الانتقال للصفحة \(page)", "Turn to page \(page)"), kind: "page")) }
    }
    func markWriting(_ label: String) {
        guard recording, !label.isEmpty else { return }
        markers.append(StudioMarker(page: page, time: elapsed, label: label, kind: "writing"))
    }
    func addManualMarker() {
        guard recording else { return }
        markers.append(StudioMarker(page: page, time: elapsed, label: L("علامة يدوية", "Manual marker"), kind: "manual"))
    }
    func activate(_ marker: StudioMarker) {
        guard !recording else { return }
        changePage(to: marker.page)
        seek(to: marker.time)
        activeMarkerID = marker.id
        playing = true
    }
    @discardableResult func jump(to text: String) -> Bool {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, clean.allSatisfy({ $0.wholeNumberValue != nil }) else { return false }
        let digits = clean.compactMap { $0.wholeNumberValue }.map(String.init).joined()
        guard let target = Int(digits), (1...totalPages).contains(target) else { return false }
        changePage(to: target)
        return true
    }
    func seek(to time: Double) { if time.isFinite { playhead = min(duration, max(0, time)) } }
    func setRate(_ value: Double) { if value.isFinite { rate = min(2, max(0.75, value)) } }
    func rename(to value: String) {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if !clean.isEmpty { title = clean }
    }
    func sceneBecameInactive() { recording = false; playing = false }
}
