import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct DocumentPicker: UIViewControllerRepresentable {
    let finished: ([URL]) -> Void
    static let contentTypes: [UTType] = ["pdf", "pptx", "docx", "xlsx", "ppt", "doc", "xls"]
        .compactMap { UTType(filenameExtension: $0) }

    func makeCoordinator() -> Coordinator { Coordinator(finished: finished) }
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // Deliver a local copy instead of resolving a provider bookmark in
        // SwiftUI after the remote Files process returns.
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: Self.contentTypes, asCopy: true)
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ controller: UIDocumentPickerViewController, context: Context) {}

    /// Retire only our incoming copy after the library has saved its own copy.
    static func discardIncomingCopy(_ source: URL) {
        let inbox = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Inbox", isDirectory: true).standardizedFileURL
        guard source.standardizedFileURL.deletingLastPathComponent() == inbox else { return }
        try? FileManager.default.removeItem(at: source)
    }

    @MainActor final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let finished: ([URL]) -> Void
        init(finished: @escaping ([URL]) -> Void) { self.finished = finished }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) { finished(urls) }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { finished([]) }
    }
}
