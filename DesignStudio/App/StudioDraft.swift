import Foundation
import SwiftUI

struct StudioPenPreset: Codable, Equatable {
    var brush: String
    var color: Int
    var width: Double
    var description: String { String(format: "%@:#%06X:%g", brush, color, width) }
}

struct StudioDraftState: Codable {
    var notes = L("ملاحظات مهمة\n\n• التركيز على طرفي المعادلة.\n• مراجعة المثال قبل المحاضرة القادمة.", "Key ideas\n\n• Watch both sides of the equation.\n• Review the example before the next lecture.")
    var page = 7
    var lastPage: Int?
    var split = 0.64
    var text = ""
    var textSize = 18.0
    var textColor = 0x244C43
    var textAlignment = 0
    var documentInk = Data()
    var marginInk = Data()
    var pdf: Data?
    var currentPen = StudioPenPreset(brush: "pen", color: 0x244C43, width: 3)
    var pens = [StudioPenPreset(brush: "pen", color: 0x244C43, width: 3),
                StudioPenPreset(brush: "pen", color: 0xA14F2B, width: 6),
                StudioPenPreset(brush: "highlighter", color: 0xD8AF47, width: 12)]
}

/// Atomic preview-only drafts. Never resolves production directories or audio files.
final class StudioDraft: ObservableObject {
    @Published var state: StudioDraftState { didSet { persist() } }
    @Published private(set) var status = "unsaved"
    private let url: URL
    private var unreadable = false
    private let writer = DispatchQueue(label: "TayyaStudio.preview-draft", qos: .utility)
    private var pending: DispatchWorkItem?
    private var revision = 0

    init(url: URL? = nil) {
        let args = ProcessInfo.processInfo.arguments
        let index = args.firstIndex(of: "--draft-id")
        let name = index.flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil }
        let safeName = (name ?? "sample").filter { $0.isLetter || $0.isNumber || $0 == "-" }
        let base = args.contains("--capture") && name == nil
            ? FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            : FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("TayyaStudioPreview", isDirectory: true)
        self.url = url ?? base.appendingPathComponent(safeName + ".json")
        if url == nil && args.contains("--reset-draft") { try? FileManager.default.removeItem(at: self.url) }
        state = StudioDraftState()
        if FileManager.default.fileExists(atPath: self.url.path) {
            do {
                let decoded = try JSONDecoder().decode(StudioDraftState.self, from: Data(contentsOf: self.url))
                guard decoded.pens.count == 3, (1...24).contains(decoded.page), decoded.split.isFinite,
                      decoded.pens.allSatisfy({ ["pen", "pencil", "highlighter", "eraser"].contains($0.brush) && $0.width.isFinite && $0.width > 0 }) else {
                    throw CocoaError(.fileReadCorruptFile)
                }
                state = decoded
                status = "saved"
            } catch { unreadable = true; status = "failed" }
        }
    }
    func savePen(at index: Int, pen: StudioPenPreset) {
        guard state.pens.indices.contains(index), pen.width.isFinite, pen.width > 0 else { return }
        state.pens[index] = pen
    }
    private func persist() {
        guard !unreadable else { status = "failed"; return }
        status = "saving"
        revision += 1
        let version = revision, snapshot = state, destination = url
        pending?.cancel()
        let task = DispatchWorkItem { [weak self] in
            let result: String
            do {
                try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
                try JSONEncoder().encode(snapshot).write(to: destination, options: .atomic)
                result = "saved"
            } catch { result = "failed" }
            DispatchQueue.main.async {
                guard let self, self.revision == version else { return }
                self.status = result
            }
        }
        pending = task
        // Coalesce typing/stroke notifications; this is save scheduling, never a UI-readiness delay.
        writer.asyncAfter(deadline: .now() + .milliseconds(250), execute: task)
    }
}
