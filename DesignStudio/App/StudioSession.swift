import Combine
import Foundation

struct StudioMarker: Identifiable {
    let id = UUID()
    let page: Int
    let time: Double
    let label: String
    let kind: String
}

/// In-memory design demonstrator. Intentionally unimplemented for the RED probe.
final class StudioSession: ObservableObject {
    @Published var page = 7
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

    func beginRecording() {}
    func tick(seconds: Double) {}
    func changePage(to page: Int) {}
    func markWriting(_ label: String) {}
    func addManualMarker() {}
    func activate(_ marker: StudioMarker) {}
    func seek(to time: Double) {}
    func setRate(_ value: Double) {}
    func rename(to value: String) {}
    func sceneBecameInactive() {}
}
