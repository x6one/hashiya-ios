import SwiftUI
import UniformTypeIdentifiers

/// Present Files as a UIKit modal, rather than embedding its remote controller
/// as a SwiftUI child. Files owns the presentation, coordinate space and dismissal.
struct DocumentPicker: UIViewControllerRepresentable {
    let directory: URL?
    let completed: ([URL]) -> Void
    let cancelled: () -> Void

    func makeUIViewController(context: Context) -> Presenter {
        Presenter(directory: directory, completed: completed, cancelled: cancelled)
    }
    func updateUIViewController(_ controller: Presenter, context: Context) {
        controller.completed = completed
        controller.cancelled = cancelled
    }

    final class Presenter: UIViewController, UIDocumentPickerDelegate {
        let directory: URL?
        var completed: ([URL]) -> Void
        var cancelled: () -> Void
        private var presentedPicker = false

        init(directory: URL?, completed: @escaping ([URL]) -> Void, cancelled: @escaping () -> Void) {
            self.directory = directory
            self.completed = completed
            self.cancelled = cancelled
            super.init(nibName: nil, bundle: nil)
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .systemBackground
        }
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            guard !presentedPicker else { return }
            presentedPicker = true
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.data], asCopy: true)
            picker.delegate = self
            picker.allowsMultipleSelection = false
            picker.shouldShowFileExtensions = true
            picker.directoryURL = directory
            picker.modalPresentationStyle = .fullScreen
            present(picker, animated: true)
        }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            completed(urls)
        }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { cancelled() }
    }
}
