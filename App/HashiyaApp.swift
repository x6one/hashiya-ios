import SwiftUI
import PDFKit
import PencilKit
import UniformTypeIdentifiers
import UIKit

@main struct HashiyaApp: App {
    @StateObject private var library = LibraryStore()
    var body: some Scene { WindowGroup { LibraryScreen().environmentObject(library).preferredColorScheme(.light) } }
}
struct Notebook: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var file: String
    var section: String = "مكتبتي"
    var favorite = false
    var trashed = false
}
@MainActor final class LibraryStore: ObservableObject {
    @Published var notebooks: [Notebook] = []
    @Published var error: String?
    let root: URL
    init() {
        root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        do {
            let file = root.appendingPathComponent("library.json")
            if FileManager.default.fileExists(atPath: file.path) { notebooks = try JSONDecoder().decode([Notebook].self, from: Data(contentsOf: file)) }
            else if let demo = Bundle.main.url(forResource: "english", withExtension: "pdf") { try importPDF(demo, title: "ملف التجربة") }
        } catch { self.error = error.localizedDescription }
    }
    func save() {
        do { try JSONEncoder().encode(notebooks).write(to: root.appendingPathComponent("library.json"), options: .atomic) }
        catch { self.error = error.localizedDescription }
    }
    func importPDF(_ source: URL, title: String? = nil) throws {
        let granted = source.startAccessingSecurityScopedResource()
        defer { if granted { source.stopAccessingSecurityScopedResource() } }
        guard PDFDocument(url: source) != nil else { throw CocoaError(.fileReadCorruptFile) }
        let name = UUID().uuidString + ".pdf"
        try FileManager.default.copyItem(at: source, to: root.appendingPathComponent(name))
        notebooks.insert(Notebook(title: title ?? source.deletingPathExtension().lastPathComponent, file: name), at: 0)
        save()
    }
    func create(_ title: String) {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 650, height: 900))
        let data = renderer.pdfData { ctx in
            ctx.beginPage()
            UIColor(red: 1, green: 0.995, blue: 0.98, alpha: 1).setFill()
            ctx.cgContext.fill(CGRect(x: 0, y: 0, width: 650, height: 900))
            UIColor.systemGray5.setStroke()
            for y in stride(from: 70, through: 850, by: 30) { ctx.cgContext.move(to: CGPoint(x: 40, y: CGFloat(y))); ctx.cgContext.addLine(to: CGPoint(x: 610, y: CGFloat(y))) }
            ctx.cgContext.strokePath()
        }
        do { let name = UUID().uuidString + ".pdf"; try data.write(to: root.appendingPathComponent(name), options: .atomic); notebooks.insert(Notebook(title: title, file: name), at: 0); save() }
        catch { self.error = error.localizedDescription }
    }
}
struct LibraryScreen: View {
    @EnvironmentObject private var store: LibraryStore
    @State private var importing = false
    @State private var creating = false
    @State private var title = "دفتر جديد"
    @State private var query = ""
    @State private var showTrash = false
    private let paper = Color(red: 0.965, green: 0.964, blue: 0.943)
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("أهلاً أحمد، فكرة جديدة؟").font(.largeTitle.weight(.semibold))
                        Text("اترك لأفكارك حاشية.").foregroundStyle(.secondary)
                    }.padding(.vertical, 20)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 235), spacing: 22)], spacing: 22) {
                        ForEach(store.notebooks.filter { $0.trashed == showTrash && (query.isEmpty || $0.title.localizedCaseInsensitiveContains(query)) }) { note in
                            NavigationLink { DocumentScreen(note: note, root: store.root) } label: {
                                VStack(alignment: .leading, spacing: 15) {
                                    Image(systemName: "book.closed").font(.system(size: 36)).padding(.bottom, 20)
                                    Text(note.title).font(.title3.weight(.medium)).lineLimit(2)
                                    Text(note.section).font(.caption).foregroundStyle(.secondary)
                                }.frame(maxWidth: .infinity, minHeight: 165, alignment: .leading).padding(24).background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 20))
                            }.contextMenu {
                                Button(showTrash ? "استعادة" : "نقل للمحذوفات", systemImage: showTrash ? "arrow.uturn.backward" : "trash") {
                                    if let i = store.notebooks.firstIndex(where: {$0.id == note.id}) { store.notebooks[i].trashed.toggle(); store.save() }
                                }
                            }
                        }
                    }
                    Text("By Ahmad Al-awi").font(.footnote).foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.top, 25)
                }.padding(32)
            }.background(paper).navigationTitle("حاشية").searchable(text: $query, prompt: "ابحث في دفاترك")
                .toolbar {
                    ToolbarItemGroup(placement: .primaryAction) {
                        Button { showTrash.toggle() } label: { Image(systemName: showTrash ? "books.vertical" : "trash") }
                        Button("استيراد", systemImage: "square.and.arrow.down") { importing = true }
                        Button("دفتر جديد", systemImage: "plus") { creating = true }
                    }
                }
                .fileImporter(isPresented: $importing, allowedContentTypes: [.pdf]) { result in
                    do { try store.importPDF(result.get()) } catch { store.error = error.localizedDescription }
                }
                .alert("دفتر جديد", isPresented: $creating) { TextField("الاسم", text: $title); Button("إنشاء") { store.create(title.isEmpty ? "دفتر جديد" : title) }; Button("إلغاء", role: .cancel) {} }
                .alert("تعذّر إكمال العملية", isPresented: Binding(get: {store.error != nil}, set: {if !$0 {store.error = nil}})) { Button("حسناً") {store.error = nil} } message: { Text(store.error ?? "") }
        }.tint(Color(red: 0.26, green: 0.42, blue: 0.53)).environment(\.layoutDirection, .rightToLeft)
    }
}
struct DocumentScreen: View {
    let note: Notebook
    let root: URL
    @State private var drawing = false
    @State private var margin = ""
    @State private var showMargin = true
    var body: some View {
        HStack(spacing: 0) {
            NativePDF(url: root.appendingPathComponent(note.file), storage: root.appendingPathComponent(note.id.uuidString), drawing: drawing)
            if showMargin {
                VStack(alignment: .leading) {
                    Text("على الهامش").font(.headline)
                    TextEditor(text: $margin).scrollContentBackground(.hidden)
                        .onChange(of: margin) { _, value in try? value.write(to: root.appendingPathComponent(note.id.uuidString + "-margin.txt"), atomically: true, encoding: .utf8) }
                    Text("يمكن استخدام Scribble هنا").font(.caption).foregroundStyle(.secondary)
                }.padding(20).frame(width: 240).background(Color(red: 0.98, green: 0.98, blue: 0.95))
            }
        }.navigationTitle(note.title).navigationBarTitleDisplayMode(.inline)
            .toolbar { Button(drawing ? "قراءة" : "قلم", systemImage: drawing ? "hand.draw" : "pencil.tip") { drawing.toggle() }; Button("الحاشية", systemImage: "sidebar.right") { showMargin.toggle() } }
            .onAppear { margin = (try? String(contentsOf: root.appendingPathComponent(note.id.uuidString + "-margin.txt"), encoding: .utf8)) ?? "" }
    }
}
struct NativePDF: UIViewRepresentable {
    let url: URL
    let storage: URL
    let drawing: Bool
    func makeCoordinator() -> Coordinator { Coordinator(storage: storage) }
    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.document = PDFDocument(url: url)
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.backgroundColor = UIColor(red: 0.92, green: 0.94, blue: 0.92, alpha: 1)
        view.pageOverlayViewProvider = context.coordinator
        context.coordinator.pdf = view
        return view
    }
    func updateUIView(_ view: PDFView, context: Context) { context.coordinator.setDrawing(drawing) }
    final class Coordinator: NSObject, PDFPageOverlayViewProvider, PKCanvasViewDelegate {
        weak var pdf: PDFView?
        let storage: URL
        var canvases: [Int: PKCanvasView] = [:]
        let picker = PKToolPicker()
        var enabled = false
        init(storage: URL) { self.storage = storage; super.init(); try? FileManager.default.createDirectory(at: storage, withIntermediateDirectories: true) }
        func setDrawing(_ value: Bool) {
            enabled = value
            for canvas in canvases.values { canvas.isUserInteractionEnabled = value; picker.setVisible(value, forFirstResponder: canvas) }
            if value { canvases.values.first?.becomeFirstResponder() }
        }
        func pdfView(_ view: PDFView, overlayViewFor page: PDFPage) -> UIView? {
            guard let index = view.document?.index(for: page) else { return nil }
            if let existing = canvases[index] { return existing }
            let canvas = PKCanvasView()
            canvas.backgroundColor = .clear
            canvas.isOpaque = false
            canvas.drawingPolicy = .anyInput
            canvas.delegate = self
            canvas.tag = index
            canvas.isUserInteractionEnabled = enabled
            canvas.tool = PKInkingTool(.pen, color: .darkGray, width: 3)
            if let data = try? Data(contentsOf: storage.appendingPathComponent("\(index).drawing")), let drawing = try? PKDrawing(data: data) { canvas.drawing = drawing }
            canvases[index] = canvas
            picker.addObserver(canvas)
            picker.setVisible(enabled, forFirstResponder: canvas)
            return canvas
        }
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) { try? canvasView.drawing.dataRepresentation().write(to: storage.appendingPathComponent("\(canvasView.tag).drawing"), options: .atomic) }
    }
}
