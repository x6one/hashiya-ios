#if DEBUG
import SwiftUI
import UIKit

/// Test setup only: save fixtures through Files' own export operation so the
/// provider creates its document IDs. Never inserts anything into the library.
struct DebugFilesFixtures: View {
    @State private var urls: [URL] = []
    @State private var exporting = false
    @State private var status = "Preparing external fixtures"
    var body: some View {
        Text(status).accessibilityIdentifier("fixtureExportStatus")
            .task {
                do {
                    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                    for (name, ext, target) in [("english", "pdf", "Picker-fixture.pdf"), ("office-demo", "pptx", "Picker-office.pptx")] {
                        guard let source = Bundle.main.url(forResource: name, withExtension: ext) else {
                            throw CocoaError(.fileNoSuchFile)
                        }
                        let destination = folder.appendingPathComponent(target)
                        try FileManager.default.copyItem(at: source, to: destination)
                        urls.append(destination)
                    }
                    exporting = true
                } catch { status = error.localizedDescription }
            }
            .sheet(isPresented: $exporting) {
                FixturesExporter(urls: urls) { destinations in
                    exporting = false
                    status = destinations.isEmpty ? "Export cancelled" : "Fixtures exported"
                }.ignoresSafeArea()
            }
    }
}

private struct FixturesExporter: UIViewControllerRepresentable {
    let urls: [URL]
    let finished: ([URL]) -> Void
    func makeCoordinator() -> DocumentPicker.Coordinator { .init(finished: finished) }
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let controller = UIDocumentPickerViewController(forExporting: urls, asCopy: true)
        controller.delegate = context.coordinator
        return controller
    }
    func updateUIViewController(_ controller: UIDocumentPickerViewController, context: Context) {}
}
#endif
