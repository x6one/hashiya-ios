#if DEBUG
import SwiftUI
import UIKit

/// Test setup only: save fixtures through Files' own export operation so the
/// provider creates its document IDs. Never inserts anything into the library.
struct DebugFilesFixtures: View {
    private struct ExportRequest: Identifiable {
        let id = UUID()
        let urls: [URL]
    }
    @State private var request: ExportRequest?
    @State private var status = "Preparing external fixtures"
    var body: some View {
        Text(status).accessibilityIdentifier("fixtureExportStatus")
            .task {
                do {
                    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                    var urls: [URL] = []
                    // Export one document per native Save operation. iPadOS
                    // 26.2 can leave the second item of a batch with a visible
                    // row but an unresolvable LocalStorage provider ID.
                    let fixture = ProcessInfo.processInfo.arguments.contains("--test-export-office")
                        ? ("office-demo", "pptx", "Picker-office.pptx")
                        : ("english", "pdf", "Picker-fixture.pdf")
                    for (name, ext, target) in [fixture] {
                        guard let source = Bundle.main.url(forResource: name, withExtension: ext) else {
                            throw CocoaError(.fileNoSuchFile)
                        }
                        let destination = folder.appendingPathComponent(target)
                        try FileManager.default.copyItem(at: source, to: destination)
                        urls.append(destination)
                    }
                    status = "Exporting \(urls.count) fixtures"
                    request = ExportRequest(urls: urls)
                } catch { status = error.localizedDescription }
            }
            .sheet(item: $request) { payload in
                FixturesExporter(urls: payload.urls) { destinations in
                    request = nil
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
        precondition(urls.count == 1 && urls.allSatisfy { FileManager.default.fileExists(atPath: $0.path) },
            "Export setup requires one staged fixture")
        let controller = UIDocumentPickerViewController(forExporting: urls, asCopy: true)
        controller.delegate = context.coordinator
        return controller
    }
    func updateUIViewController(_ controller: UIDocumentPickerViewController, context: Context) {}
}
#endif
