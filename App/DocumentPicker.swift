import SwiftUI
import UniformTypeIdentifiers

/// Copy-mode selection ends with the native Open button, including one file.
/// LibraryStore coordinates and retains a private
/// copy of the selected security-scoped document.
struct DocumentPicker: UIViewControllerRepresentable {
    // Ask Files for the system types of the supported extensions themselves.
    // Composite Office types must not depend on a broad data/content filter.
    static let contentTypes: [UTType] = ["pdf", "pptx", "docx", "xlsx", "ppt", "doc", "xls"]
        .compactMap { UTType(filenameExtension: $0) }
    let directory: URL?
    let completed: ([URL]) -> Void
    let cancelled: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(completed: completed, cancelled: cancelled) }
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--test-file-picker") {
            NSLog("Hashiya Files allowed types: %@", Self.contentTypes.map(\.identifier).joined(separator: ","))
            for name in ["Picker-fixture.pdf", "Picker-office.pptx"] {
                if let url = directory?.appendingPathComponent(name),
                   let values = try? url.resourceValues(forKeys: [.typeIdentifierKey]) {
                    NSLog("Hashiya Files fixture %@ type: %@", name, values.typeIdentifier ?? "missing")
                }
            }
        }
        #endif
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: Self.contentTypes, asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = true
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
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--test-file-picker") { NSLog("Hashiya Files delegate picked %ld documents", urls.count) }
            #endif
            completed(urls)
        }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { cancelled() }
    }
}
