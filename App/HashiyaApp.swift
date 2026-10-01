import SwiftUI
import PDFKit
import PencilKit
import UniformTypeIdentifiers
import UIKit
import ZIPFoundation

@main struct HashiyaApp: App {
    @StateObject private var library: LibraryStore
    init() {
        #if DEBUG
        let store = LibraryStore()
        if ProcessInfo.processInfo.arguments.contains("--test-office-preview"),
           !store.notebooks.contains(where: { $0.title == "ملف Office للاختبار" }),
           let source = Bundle.main.url(forResource: "office-demo", withExtension: "pptx") {
            try? store.importDocument(source, title: "ملف Office للاختبار")
        }
        if ProcessInfo.processInfo.arguments.contains("--test-file-picker") {
            for (name, ext, targetName) in [("english", "pdf", "Picker-fixture.pdf"), ("office-demo", "pptx", "Picker-office.pptx")] {
                guard let source = Bundle.main.url(forResource: name, withExtension: ext) else { continue }
                let target = store.root.appendingPathComponent(targetName)
                guard !FileManager.default.fileExists(atPath: target.path) else { continue }
                var coordinationError: NSError?
                NSFileCoordinator().coordinate(writingItemAt: target, options: [], error: &coordinationError) { destination in
                    try? FileManager.default.copyItem(at: source, to: destination)
                }
            }
        }
        #else
        let store = LibraryStore(seedDemo: false)
        #endif
        _library = StateObject(wrappedValue: store)
    }
    var body: some Scene { WindowGroup { AppEntrance().environmentObject(library) } }
}
struct Notebook: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var file: String
    var section: String = "مكتبتي"
    var favorite = false
    var trashed = false
}
