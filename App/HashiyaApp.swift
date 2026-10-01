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
