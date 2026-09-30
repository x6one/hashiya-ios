import SwiftUI
import UniformTypeIdentifiers

/// Present one system picker. LibraryStore coordinates and retains a private
/// copy of the selected security-scoped document.
struct DocumentPicker: UIViewControllerRepresentable {
    let directory: URL?
    let completed: ([URL]) -> Void
    let cancelled: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(completed: completed, cancelled: cancelled) }
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.data], asCopy: false)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        picker.shouldShowFileExtensions = true
        picker.directoryURL = directory
        return picker
    }
    func updateUIViewController(_ controller: UIDocumentPickerViewController, context: Context) {}
    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let completed: ([URL]) -> Void
        let cancelled: () -> Void
        init(completed: @escaping ([URL]) -> Void, cancelled: @escaping () -> Void) {
            self.completed = completed; self.cancelled = cancelled
        }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) { completed(urls) }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { cancelled() }
    }
}
