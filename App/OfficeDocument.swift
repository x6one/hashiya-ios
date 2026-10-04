import SwiftUI
import QuickLook
import AVKit
import ZIPFoundation

// Office preview and embedded media remain available until the user converts
// the library item to a static PDF. External originals are never modified.
enum DocumentImportError: LocalizedError {
    case unsupported, tooLarge, damaged, mediaLimit
    var errorDescription: String? {
        switch self {
        case .unsupported: return "نوع الملف غير مدعوم في هذه النسخة."
        case .tooLarge: return "حجم الملف يتجاوز حد التجربة (128 ميجابايت)."
        case .damaged: return "تعذّر قراءة الملف. تأكد أنه غير تالف أو محمي بكلمة مرور."
        case .mediaLimit: return "تجاوزت الوسائط حد الاستخراج الآمن. الملف الأصلي محفوظ."
        }
    }
}
struct EmbeddedMedia: Identifiable, Sendable {
    var id: URL { url }
    let name: String
    let url: URL
}
enum OfficeMedia {
    static func extract(from source: URL, into destination: URL) throws -> [EmbeddedMedia] {
        let archive = try Archive(url: source, accessMode: .read)
        let fm = FileManager.default
        try fm.createDirectory(at: destination, withIntermediateDirectories: true)
        var result: [EmbeddedMedia] = []
        var total = 0
        var count = 0
        do {
            for entry in archive {
                count += 1
                guard count <= 10000 else { throw DocumentImportError.mediaLimit }
                let path = entry.path
                let ext = (path as NSString).pathExtension.lowercased()
                guard entry.type == .file,
                      ["ppt/media/", "word/media/", "xl/media/"].contains(where: { path.hasPrefix($0) }),
                      ["mp4", "mov", "m4v", "mp3", "m4a", "wav", "aac"].contains(ext) else { continue }
                guard entry.uncompressedSize <= 100 * 1024 * 1024 else { throw DocumentImportError.mediaLimit }
                // Never use archive paths as filesystem destinations.
                let target = destination.appendingPathComponent(UUID().uuidString).appendingPathExtension(ext)
                guard fm.createFile(atPath: target.path, contents: nil) else { throw CocoaError(.fileWriteUnknown) }
                let handle = try FileHandle(forWritingTo: target)
                var entryBytes = 0
                do {
                    let crc = try archive.extract(entry) { chunk in
                        entryBytes += chunk.count
                        total += chunk.count
                        guard entryBytes <= 100 * 1024 * 1024, total <= 256 * 1024 * 1024 else { throw DocumentImportError.mediaLimit }
                        try handle.write(contentsOf: chunk)
                    }
                    try handle.close()
                    guard crc == entry.checksum else { throw DocumentImportError.damaged }
                } catch {
                    try? handle.close()
                    throw error
                }
                result.append(EmbeddedMedia(name: (path as NSString).lastPathComponent, url: target))
            }
            return result
        } catch {
            try? fm.removeItem(at: destination)
            throw error
        }
    }
}
struct OfficePreview: UIViewControllerRepresentable {
    let url: URL
    func makeCoordinator() -> Coordinator { Coordinator(url: url) }
    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }
    func updateUIViewController(_ controller: QLPreviewController, context: Context) {}
    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL
        init(url: URL) { self.url = url }
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem { url as NSURL }
    }
}
/// Resolve by identity so conversion updates this route directly to the PDF editor.
struct NotebookScreen: View {
    let id: UUID
    @ObservedObject var store: LibraryStore
    var initialPage: Int? = nil
    var body: some View {
        if let note = store.notebooks.first(where: { $0.id == id }) {
            if (note.file as NSString).pathExtension.lowercased() == "pdf" {
                DocumentScreen(note: note, root: store.root, initialPage: initialPage)
            } else { OfficeDocumentScreen(note: note, store: store) }
        } else { ContentUnavailableView("الملف غير موجود", systemImage: "doc.questionmark") }
    }
}
struct OfficeDocumentScreen: View {
    let note: Notebook
    @ObservedObject var store: LibraryStore
    private var root: URL { store.root }
    @State private var showMedia = false
    @State private var converting = false
    @State private var conversionError: String?
    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                Label("للكتابة والتعليق على هذا الملف، حوّله إلى PDF", systemImage: "pencil.tip.crop.circle")
                    .font(.headline)
                if OfficeConversion.available {
                    Button(action: convert) {
                        HStack {
                            if converting { ProgressView().tint(TayyaTheme.paper) }
                            Text(converting ? "جارٍ التحويل…" : "تحويل إلى PDF والكتابة")
                            Spacer(minLength: 8)
                            Image(systemName: "arrow.left")
                        }.padding(.vertical, 8)
                    }.buttonStyle(.borderedProminent).foregroundStyle(TayyaTheme.paper).disabled(converting)
                        .accessibilityIdentifier("convertOfficePDF")
                    Text("ينشئ نسخة للكتابة ويحفظ أصل Office داخل مكتبتك.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("التحويل المحلي متاح في نسخة الجهاز المزوّدة بمحرك Office.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }.padding(18).background(TayyaTheme.surface)
            OfficePreview(url: root.appendingPathComponent(note.file))
        }.navigationTitle(note.title).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("وسائط الملف", systemImage: "play.rectangle") { showMedia = true }.accessibilityIdentifier("officeMedia")
            }
            .sheet(isPresented: $showMedia) { OfficeMediaScreen(source: root.appendingPathComponent(note.file)) }
            .alert("تعذّر تحويل المستند", isPresented: Binding(get: { conversionError != nil }, set: { if !$0 { conversionError = nil } })) {
                Button("حسناً") { conversionError = nil }
            } message: { Text(conversionError ?? "") }
    }
    private func convert() {
        guard !converting else { return }
        converting = true
        Task { @MainActor in
            defer { converting = false }
            do {
                let pdf = try await OfficeConversion.convert(root.appendingPathComponent(note.file))
                defer { try? FileManager.default.removeItem(at: pdf.deletingLastPathComponent()) }
                try await store.replaceOfficeWithPDF(note.id, source: pdf)
            } catch { conversionError = error.localizedDescription }
        }
    }
}
final class MediaSession: ObservableObject {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    deinit { try? FileManager.default.removeItem(at: folder) }
}
struct OfficeMediaScreen: View {
    let source: URL
    @Environment(\.dismiss) private var dismiss
    @State private var items: [EmbeddedMedia] = []
    @State private var loading = true
    @State private var error: String?
    @State private var selected: EmbeddedMedia?
    @StateObject private var session = MediaSession()
    var body: some View {
        NavigationStack {
            Group {
                if loading { ProgressView("قراءة الوسائط…") }
                else if let error { ContentUnavailableView("تعذّر استخراج الوسائط", systemImage: "exclamationmark.triangle", description: Text(error)) }
                else if items.isEmpty { ContentUnavailableView("لا توجد وسائط مضمّنة مدعومة", systemImage: "play.slash", description: Text("الفيديو المرتبط بموقع أو بملف خارجي لا يكون موجوداً داخل العرض.")) }
                else { List(items) { item in Button(item.name, systemImage: "play.circle") { selected = item } } }
            }.navigationTitle("وسائط الملف").toolbar { Button("تم") { dismiss() } }
                .sheet(item: $selected) { MediaPlayerScreen(item: $0) }
        }.environment(\.layoutDirection, .rightToLeft)
            .task {
                let folder = session.folder
                do {
                    guard ["pptx", "docx", "xlsx"].contains(source.pathExtension.lowercased()) else { throw DocumentImportError.unsupported }
                    items = try await Task.detached(priority: .userInitiated) { try OfficeMedia.extract(from: source, into: folder) }.value
                } catch { self.error = error.localizedDescription }
                loading = false
            }

    }
}
struct MediaPlayerScreen: View {
    let item: EmbeddedMedia
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?
    @State private var playbackError: String?
    var body: some View {
        NavigationStack {
            VStack {
                VideoPlayer(player: player)
                if let playbackError { Text(playbackError).foregroundStyle(.red).padding() }
            }.navigationTitle(item.name)
                .toolbar { Button("تم") { dismiss() } }
                .task {
                    do {
                        let asset = AVURLAsset(url: item.url)
                        guard try await asset.load(.isPlayable) else { throw DocumentImportError.unsupported }
                        player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
                        player?.play()
                    } catch { playbackError = "تعذّر تشغيل هذا الترميز على الجهاز: " + error.localizedDescription }
                }
                .onDisappear { player?.pause(); player = nil }
        }
    }
}
