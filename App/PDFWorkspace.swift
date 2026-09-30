import SwiftUI
import PDFKit
import PencilKit

struct PageText: Codable, Identifiable {
    var id = UUID()
    var page: Int
    var text = ""
    var x: Double
    var y: Double
    var width: Double = 220
    var height: Double = 80
    var size: Double = 16
    var font = "Arial"
    var red: Double = 0.16
    var green: Double = 0.22
    var blue: Double = 0.28
}
@MainActor final class PDFWorkspace: ObservableObject {
    enum Tool { case read, ink, text }
    let document: PDFDocument
    let storage: URL
    let textURL: URL
    @Published var tool: Tool = .read
    @Published var page = 1
    @Published var inkStrokeCount = 0
    @Published var editing: PageText?
    @Published var error: String?
    @Published var exported: URL?
    private(set) var texts: [PageText] = []
    weak var view: PDFView?
    init(note: Notebook, root: URL) {
        document = PDFDocument(url: root.appendingPathComponent(note.file)) ?? PDFDocument()
        storage = root.appendingPathComponent(note.id.uuidString)
        textURL = root.appendingPathComponent(note.id.uuidString + "-text.json")
        do {
            try FileManager.default.createDirectory(at: storage, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: textURL.path) { texts = try JSONDecoder().decode([PageText].self, from: Data(contentsOf: textURL)) }
            for item in texts { install(item) }
            inkStrokeCount = savedInkCount(on: 0)
        } catch { self.error = error.localizedDescription }
    }
    func savedInkCount(on index: Int) -> Int {
        guard let data = try? Data(contentsOf: storage.appendingPathComponent("\(index).drawing")),
              let drawing = try? PKDrawing(data: data) else { return 0 }
        return drawing.strokes.count
    }
    private func install(_ item: PageText) {
        guard let page = document.page(at: item.page) else { return }
        for annotation in page.annotations where annotation.userName == item.id.uuidString { page.removeAnnotation(annotation) }
        let annotation = PDFAnnotation(bounds: CGRect(x: item.x, y: item.y, width: item.width, height: item.height), forType: .freeText, withProperties: nil)
        annotation.contents = item.text
        annotation.font = UIFont(name: item.font, size: item.size) ?? .systemFont(ofSize: item.size)
        annotation.fontColor = UIColor(red: item.red, green: item.green, blue: item.blue, alpha: 1)
        annotation.color = .clear
        annotation.alignment = .natural
        annotation.userName = item.id.uuidString
        let border = PDFBorder(); border.lineWidth = 0; annotation.border = border
        page.addAnnotation(annotation)
    }
    func previewPosition(_ item: PageText) { install(item); view?.setNeedsDisplay() }
    func saveText(_ item: PageText) {
        var updated = texts.filter { $0.id != item.id }
        if !item.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { updated.append(item) }
        do {
            try JSONEncoder().encode(updated).write(to: textURL, options: .atomic)
            if let page = document.page(at: item.page) { for annotation in page.annotations where annotation.userName == item.id.uuidString { page.removeAnnotation(annotation) } }
            texts = updated
            if updated.contains(where: { $0.id == item.id }) { install(item) }
            view?.setNeedsDisplay()
            editing = nil
        } catch { self.error = error.localizedDescription }
    }
    func jump(_ number: Int) {
        guard number > 0, number <= document.pageCount, let target = document.page(at: number - 1) else { error = "أدخل رقمًا بين 1 و\(document.pageCount)."; return }
        view?.go(to: target); page = number
    }
    func fit() { view?.autoScales = true; if let view { view.scaleFactor = view.scaleFactorForSizeToFit } }
    func edit(at location: CGPoint, in pdf: PDFView, allowNew: Bool) {
        guard let target = pdf.page(for: location, nearest: false) else { return }
        let point = pdf.convert(location, to: target)
        if let annotation = target.annotation(at: point), let id = annotation.userName, let item = texts.first(where: { $0.id.uuidString == id }) { editing = item; return }
        guard allowNew else { return }
        let bounds = target.bounds(for: .mediaBox)
        let size = max(10, min(18, bounds.width / 40))
        editing = PageText(page: document.index(for: target), x: max(0, min(point.x, bounds.width - 220)), y: max(0, min(point.y - 60, bounds.height - 80)), size: size)
    }
    func export() {
        guard let first = document.page(at: 0) else { return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Hashiya-" + UUID().uuidString + ".pdf")
        let renderer = UIGraphicsPDFRenderer(bounds: first.bounds(for: .mediaBox))
        do {
            try renderer.writePDF(to: url) { context in
                for index in 0..<document.pageCount {
                    guard let page = document.page(at: index) else { continue }
                    let bounds = page.bounds(for: .mediaBox)
                    context.beginPage(withBounds: bounds, pageInfo: [:])
                    let cg = context.cgContext
                    cg.saveGState(); cg.translateBy(x: 0, y: bounds.height); cg.scaleBy(x: 1, y: -1)
                    page.draw(with: .mediaBox, to: cg); cg.restoreGState()
                    if let data = try? Data(contentsOf: storage.appendingPathComponent("\(index).drawing")), let ink = try? PKDrawing(data: data) {
                        ink.image(from: CGRect(origin: .zero, size: bounds.size), scale: 2).draw(in: bounds)
                    }
                }
            }
            exported = url
        } catch { self.error = error.localizedDescription }
    }
}
struct DocumentScreen: View {
    let note: Notebook
    let root: URL
    @StateObject private var workspace: PDFWorkspace
    @State private var pageNumber = "1"
    @FocusState private var pageFocused: Bool
    @State private var showNotes = false
    @State private var showAudio = false
    @State private var margin = ""
    init(note: Notebook, root: URL) { self.note = note; self.root = root; _workspace = StateObject(wrappedValue: PDFWorkspace(note: note, root: root)) }
    var body: some View {
        VStack(spacing: 0) {
            NativePDF(workspace: workspace)
            HStack {
                Button("السابق", systemImage: "chevron.right") { workspace.jump(workspace.page - 1) }.labelStyle(.iconOnly).disabled(workspace.page <= 1)
                TextField("الصفحة", text: $pageNumber).keyboardType(.numberPad).multilineTextAlignment(.center).frame(width: 55).textFieldStyle(.roundedBorder).accessibilityIdentifier("pageNumber").focused($pageFocused)
                Text("من \(workspace.document.pageCount)").font(.caption)
                Button("اذهب") { pageFocused = false; workspace.jump(Int(pageNumber) ?? 0) }.accessibilityIdentifier("goToPage")
                Button("التالي", systemImage: "chevron.left") { workspace.jump(workspace.page + 1) }.labelStyle(.iconOnly).disabled(workspace.page >= workspace.document.pageCount)
                Spacer(minLength: 4)
                Button("ملاءمة", systemImage: "arrow.up.left.and.arrow.down.right") { workspace.fit() }.labelStyle(.iconOnly)
            }.padding(12).background(.ultraThinMaterial)
        }.navigationTitle(note.title).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button(workspace.tool == .ink ? "قراءة" : "قلم", systemImage: workspace.tool == .ink ? "hand.draw" : "pencil.tip") { workspace.tool = workspace.tool == .ink ? .read : .ink }.accessibilityIdentifier("inkTool").accessibilityValue(String(workspace.inkStrokeCount))
                    Button("نص", systemImage: "textformat") { pageFocused = false; workspace.tool = .text }.tint(workspace.tool == .text ? .orange : nil).accessibilityIdentifier("textTool")
                    Menu {
                        Button("الحاشية", systemImage: "note.text") { showNotes = true }
                        Button("تسجيلات الصفحة", systemImage: "mic") { showAudio = true }
                        Button("تصدير PDF", systemImage: "square.and.arrow.up") { workspace.export() }
                    } label: { Image(systemName: "ellipsis.circle") }
                }
            }
            .overlay(alignment: .top) { if workspace.tool == .text { Text("المس الصفحة لإضافة نص، واضغط مرتين على نصك لتعديله.").font(.caption).padding(10).background(.regularMaterial, in: Capsule()).padding(8).allowsHitTesting(false) } }
            .onChange(of: pageFocused) { _, focused in
                if focused { pageNumber = "" }
                else if pageNumber.isEmpty { pageNumber = String(workspace.page) }
            }
            .onChange(of: workspace.page) { _, page in pageNumber = String(page) }
            .sheet(item: $workspace.editing) { item in TextEditorSheet(item: item, save: workspace.saveText) }
            .sheet(isPresented: $showAudio) { PageAudioScreen(folder: root.appendingPathComponent(note.id.uuidString + "-audio").appendingPathComponent(String(workspace.page))) }
            .sheet(isPresented: $showNotes) {
                NavigationStack { TextEditor(text: $margin).padding().navigationTitle("الحاشية").toolbar { Button("تم") { showNotes = false } } }.environment(\.layoutDirection, .rightToLeft)
            }
            .sheet(isPresented: Binding(get: { workspace.exported != nil }, set: { if !$0 { workspace.exported = nil } })) {
                if let url = workspace.exported { ShareDocument(url: url) }
            }
            .onAppear { margin = (try? String(contentsOf: root.appendingPathComponent(note.id.uuidString + "-margin.txt"), encoding: .utf8)) ?? "" }
            .onChange(of: margin) { _, value in
                do { try value.write(to: root.appendingPathComponent(note.id.uuidString + "-margin.txt"), atomically: true, encoding: .utf8) } catch { workspace.error = error.localizedDescription }
            }
            .alert("تعذّر إكمال العملية", isPresented: Binding(get: { workspace.error != nil }, set: { if !$0 { workspace.error = nil } })) { Button("حسناً") { workspace.error = nil } } message: { Text(workspace.error ?? "") }
    }
}
struct TextEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var item: PageText
    let save: (PageText) -> Void
    @State private var color = Color.primary
    init(item: PageText, save: @escaping (PageText) -> Void) { _item = State(initialValue: item); self.save = save }
    var body: some View {
        NavigationStack {
            Form {
                Section("النص فوق الصفحة") { TextEditor(text: $item.text).frame(minHeight: 140).accessibilityIdentifier("annotationText") }
                Section("التنسيق") {
                    Picker("الخط", selection: $item.font) { ForEach(["Arial", "GeezaPro", "TimesNewRomanPSMT", "HelveticaNeue", "CourierNewPSMT"], id: \.self) { Text($0).tag($0) } }
                    Stepper("الحجم: \(Int(item.size))", value: $item.size, in: 8...96)
                    ColorPicker("اللون", selection: $color, supportsOpacity: false)
                    Stepper("عرض النص: \(Int(item.width))", value: $item.width, in: 60...1000, step: 20)
                    Stepper("ارتفاع النص: \(Int(item.height))", value: $item.height, in: 30...1000, step: 20)
                }
                Section("الموضع على الصفحة") {
                    Stepper("أفقي: \(Int(item.x))", value: $item.x, in: 0...2000, step: 5)
                    Stepper("رأسي: \(Int(item.y))", value: $item.y, in: 0...2000, step: 5)
                }
                Button("حذف هذا النص", role: .destructive) { item.text = ""; save(item); dismiss() }
            }.navigationTitle("تحرير النص").toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("حفظ") {
                    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                    UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
                    item.red = r; item.green = g; item.blue = b
                    save(item); dismiss()
                }.accessibilityIdentifier("saveAnnotation") }
                ToolbarItem(placement: .cancellationAction) { Button("إلغاء") { dismiss() } }
            }
        }.environment(\.layoutDirection, .rightToLeft)
            .onAppear { color = Color(red: item.red, green: item.green, blue: item.blue) }
    }
}
struct ShareDocument: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: [url], applicationActivities: nil) }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
struct NativePDF: UIViewRepresentable {
    @ObservedObject var workspace: PDFWorkspace
    func makeCoordinator() -> Coordinator { Coordinator(workspace: workspace) }
    func makeUIView(context: Context) -> PDFView {
        let view = PDFView(); view.document = workspace.document; view.autoScales = true; view.displayMode = .singlePageContinuous
        view.backgroundColor = UIColor(red: 0.92, green: 0.94, blue: 0.92, alpha: 1)
        view.pageOverlayViewProvider = context.coordinator; workspace.view = view
        let double = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.doubleTap(_:))); double.numberOfTapsRequired = 2
        let single = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tap(_:))); single.require(toFail: double)
        let hold = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.hold(_:)))
        let secondary = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.doubleTap(_:))); secondary.buttonMaskRequired = .secondary
        let drag = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.drag(_:))); drag.delegate = context.coordinator
        for recognizer in [single, double, hold, secondary] {
            recognizer.delegate = context.coordinator
        }
        view.addGestureRecognizer(single); view.addGestureRecognizer(double); view.addGestureRecognizer(hold); view.addGestureRecognizer(secondary); view.addGestureRecognizer(drag)
        NotificationCenter.default.addObserver(context.coordinator, selector: #selector(Coordinator.pageChanged), name: .PDFViewPageChanged, object: view)
        view.accessibilityIdentifier = "pdfCanvas"
        return view
    }
    func updateUIView(_ view: PDFView, context: Context) { context.coordinator.setDrawing(workspace.tool == .ink) }
    @MainActor final class Coordinator: NSObject, PDFPageOverlayViewProvider, PKCanvasViewDelegate, UIGestureRecognizerDelegate {
        let workspace: PDFWorkspace
        var canvases: [Int: PKCanvasView] = [:]
        let picker = PKToolPicker()
        var enabled = false
        var dragging: PageText?
        var dragOrigin: CGPoint?
        init(workspace: PDFWorkspace) { self.workspace = workspace }
        deinit { NotificationCenter.default.removeObserver(self) }
        @objc func pageChanged() {
            guard let view = workspace.view, let page = view.currentPage else { return }
            workspace.page = workspace.document.index(for: page) + 1
            workspace.inkStrokeCount = canvases[workspace.page - 1]?.drawing.strokes.count ?? workspace.savedInkCount(on: workspace.page - 1)
            if enabled { activateCurrentCanvas() }
        }
        @objc func tap(_ gesture: UITapGestureRecognizer) { guard workspace.tool == .text, let view = workspace.view else { return }; workspace.edit(at: gesture.location(in: view), in: view, allowNew: true) }
        @objc func doubleTap(_ gesture: UITapGestureRecognizer) { guard workspace.tool != .ink, let view = workspace.view else { return }; workspace.edit(at: gesture.location(in: view), in: view, allowNew: false) }
        @objc func hold(_ gesture: UILongPressGestureRecognizer) { guard gesture.state == .began, workspace.tool != .ink, let view = workspace.view else { return }; workspace.edit(at: gesture.location(in: view), in: view, allowNew: false) }
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            // PDFKit has its own taps for selection. They must not consume our
            // text annotation taps. Panning and drawing remain exclusive.
            workspace.tool != .ink &&
                !(gestureRecognizer is UIPanGestureRecognizer) &&
                !(otherGestureRecognizer is UIPanGestureRecognizer)
        }
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard gestureRecognizer is UIPanGestureRecognizer else { return workspace.tool != .ink }
            guard workspace.tool == .text, let view = workspace.view,
                  let page = view.page(for: gestureRecognizer.location(in: view), nearest: false),
                  let annotation = page.annotation(at: view.convert(gestureRecognizer.location(in: view), to: page)),
                  let id = annotation.userName,
                  let item = workspace.texts.first(where: { $0.id.uuidString == id }) else { return false }
            dragging = item; dragOrigin = view.convert(gestureRecognizer.location(in: view), to: page); return true
        }
        @objc func drag(_ gesture: UIPanGestureRecognizer) {
            guard var item = dragging, let origin = dragOrigin, let view = workspace.view, let page = workspace.document.page(at: item.page) else { return }
            let point = view.convert(gesture.location(in: view), to: page)
            let bounds = page.bounds(for: .mediaBox)
            item.x = max(0, min(bounds.width - item.width, item.x + point.x - origin.x))
            item.y = max(0, min(bounds.height - item.height, item.y + point.y - origin.y))
            if gesture.state == .changed || gesture.state == .ended {
                workspace.previewPosition(item)
            }
            if gesture.state == .ended { workspace.saveText(item); dragging = nil; dragOrigin = nil }
            if gesture.state == .cancelled || gesture.state == .failed { if let original = dragging { workspace.previewPosition(original) }; dragging = nil; dragOrigin = nil }
        }
        func setDrawing(_ value: Bool) {
            workspace.view?.isInMarkupMode = value
            guard enabled != value else { return }; enabled = value
            for canvas in canvases.values {
                canvas.isUserInteractionEnabled = value
                if !value { picker.setVisible(false, forFirstResponder: canvas); canvas.resignFirstResponder() }
            }
            if value { activateCurrentCanvas() }
        }
        private func activateCurrentCanvas() {
            guard let view = workspace.view, let page = view.currentPage,
                  let canvas = canvases[workspace.document.index(for: page)], canvas.window != nil else { return }
            canvas.becomeFirstResponder()
            picker.setVisible(true, forFirstResponder: canvas)
        }
        func pdfView(_ view: PDFView, overlayViewFor page: PDFPage) -> UIView? {
            let index = workspace.document.index(for: page)
            if let canvas = canvases[index] { return canvas }
            let canvas = PKCanvasView(frame: page.bounds(for: .mediaBox))
            canvas.backgroundColor = .clear; canvas.isOpaque = false; canvas.drawingPolicy = .anyInput; canvas.delegate = self; canvas.tag = index; canvas.isUserInteractionEnabled = enabled
            canvas.isScrollEnabled = false
            canvas.accessibilityIdentifier = "inkCanvas-\(index)"
            canvas.isAccessibilityElement = true
            canvas.accessibilityLabel = "مساحة القلم، عدد الخطوط"
            canvas.tool = PKInkingTool(.pen, color: .darkGray, width: 3)
            if let data = try? Data(contentsOf: workspace.storage.appendingPathComponent("\(index).drawing")), let ink = try? PKDrawing(data: data) { canvas.drawing = ink }
            canvas.accessibilityValue = String(canvas.drawing.strokes.count)
            canvases[index] = canvas; picker.addObserver(canvas)
            return canvas
        }
        func pdfView(_ view: PDFView, willDisplayOverlayView overlayView: UIView, for page: PDFPage) {
            if enabled { activateCurrentCanvas() }
        }
        func canvasViewDrawingDidChange(_ canvas: PKCanvasView) {
            canvas.accessibilityValue = String(canvas.drawing.strokes.count)
            do {
                try canvas.drawing.dataRepresentation().write(to: workspace.storage.appendingPathComponent("\(canvas.tag).drawing"), options: .atomic)
                if canvas.tag == workspace.page - 1 { workspace.inkStrokeCount = canvas.drawing.strokes.count }
            }
            catch { workspace.error = error.localizedDescription }
        }
    }
}
