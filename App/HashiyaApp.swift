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
        if ProcessInfo.processInfo.arguments.contains("--test-review-entry") { UserDefaults.standard.removeObject(forKey: "tayya.welcomeSeen") }
        let reviewRoot = ProcessInfo.processInfo.arguments.contains("--test-review-entry") ? FileManager.default.temporaryDirectory.appendingPathComponent("ReviewEntry-" + UUID().uuidString) : nil
        let store = LibraryStore(root: reviewRoot, seedDemo: !UserDefaults.standard.bool(forKey: "maestroTesting") && !ProcessInfo.processInfo.arguments.contains("--test-export-fixtures") && !ProcessInfo.processInfo.arguments.contains("--test-review-entry"))
        if ProcessInfo.processInfo.arguments.contains("--test-office-preview"),
           !store.notebooks.contains(where: { $0.title == "ملف Office للاختبار" }),
           let source = Bundle.main.url(forResource: "office-demo", withExtension: "pptx") {
            try? store.importDocument(source, title: "ملف Office للاختبار")
        }
        if ProcessInfo.processInfo.arguments.contains("--test-app-owned-picker") {
            for (name, ext, targetName) in [("english", "pdf", "Owned-fixture.pdf"), ("office-demo", "pptx", "Owned-office.pptx")] {
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
    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--test-export-fixtures") {
                DebugFilesFixtures()
            } else { AppEntrance().environmentObject(library) }
            #else
            AppEntrance().environmentObject(library)
            #endif
        }
    }
}
struct Notebook: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var file: String
    var originalFile: String?
    var section: String = "مكتبتي"
    var favorite = false
    var trashed = false
}
