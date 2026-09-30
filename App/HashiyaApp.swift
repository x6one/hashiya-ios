import SwiftUI
import PDFKit
import PencilKit
import UniformTypeIdentifiers
import UIKit
import ZIPFoundation

@main struct HashiyaApp: App {
    @StateObject private var library = LibraryStore()
    var body: some Scene { WindowGroup { AppEntrance().environmentObject(library).preferredColorScheme(.light) } }
}
struct Notebook: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var file: String
    var section: String = "مكتبتي"
    var favorite = false
    var trashed = false
}
