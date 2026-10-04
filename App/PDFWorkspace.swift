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
    enum Tool { case read, ink, text, lasso }
    let document: PDFDocument
    let storage: URL
    let textURL: URL
    @Published var tool: Tool = .read
    @Published var page = 1
    @Published var inkStrokeCount = 0
    @Published var editing: PageText?
    @Published var error: String?
    @Published var exported: URL?
    @Published var selectedInkCount = 0
    var inkAction: ((String) -> Void)?
    var onTextSaved: ((PageText) -> Void)?
    var onInkSaved: ((Int, Int) -> Void)?
    var onTextTapped: ((UUID) -> Void)?
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
            onTextSaved?(item)
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
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Tayya-" + UUID().uuidString + ".pdf")
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
    @State private var marginInk = false
    @State private var splitNotes = false
    @State private var splitFraction = 0.6
    @State private var dragFraction: Double?
    @State private var cardDraft: Flashcard?
    @State private var showCards = false
    @State private var original = false
    @State private var showMedia = false
    @State private var ocrBusy = false
    @State private var ocrMessage = ""
    @StateObject private var audio: PageAudio
    let initialPage: Int?
    @Environment(\.scenePhase) private var scenePhase
    init(note: Notebook, root: URL, initialPage: Int? = nil) {
        self.note = note; self.root = root; self.initialPage = initialPage
        _workspace = StateObject(wrappedValue: PDFWorkspace(note: note, root: root))
        _audio = StateObject(wrappedValue: PageAudio(folder: root.appendingPathComponent(note.id.uuidString + "-audio").appendingPathComponent("linked")))
    }
    var body: some View {
        documentSheets
            .onAppear {
                margin = (try? String(contentsOf: root.appendingPathComponent(note.id.uuidString + "-margin.txt"), encoding: .utf8)) ?? ""
                if let initialPage { workspace.jump(initialPage) }
                workspace.onTextSaved = { item in do { try audio.link(page: item.page + 1, textID: item.id, label: String(item.text.prefix(70))) } catch { workspace.error = error.localizedDescription } }
                workspace.onInkSaved = { page, count in do { try audio.link(page: page + 1, strokeCount: count, label: "كتابة بخط اليد — صفحة \(page + 1)") } catch { workspace.error = error.localizedDescription } }
                workspace.onTextTapped = { id in if !audio.recording, let marker = audio.markers.last(where: { $0.textID == id }) { audio.seek(marker) } }
            }
            .onDisappear { audio.stop() }
            .onChange(of: scenePhase) { _, phase in if phase != .active { audio.stop() } }
            .overlay(alignment: .bottom) { if ocrBusy { ProgressView("قراءة الصفحات على الجهاز…").padding().background(.regularMaterial) } }
            .alert("قراءة الصفحات", isPresented: Binding(get: { !ocrMessage.isEmpty }, set: { if !$0 { ocrMessage = "" } })) { Button("حسنًا") { ocrMessage = "" } } message: { Text(ocrMessage) }
            .onChange(of: margin) { _, value in
                do {
                    try audio.link(page: workspace.page, label: "حاشية: " + String(value.suffix(70)))
                    try value.write(to: root.appendingPathComponent(note.id.uuidString + "-margin.txt"), atomically: true, encoding: .utf8) } catch { workspace.error = error.localizedDescription }
            }
            .alert("تعذّر إكمال العملية", isPresented: Binding(get: { workspace.error != nil }, set: { if !$0 { workspace.error = nil } })) { Button("حسناً") { workspace.error = nil } } message: { Text(workspace.error ?? "") }
    }
    private var documentContent: some View {
        VStack(spacing: 0) {
            if workspace.tool == .ink { pageControls }
            GeometryReader { geometry in
                if splitNotes && geometry.size.width >= 650 {
                    HStack(spacing: 0) {
                        NativePDF(workspace: workspace).frame(width: geometry.size.width * splitFraction)
                        Rectangle().fill(.secondary.opacity(0.3)).frame(width: 16)
                            .overlay { Image(systemName: "line.3.horizontal").font(.caption) }
                            .gesture(DragGesture().onChanged { value in
                                if dragFraction == nil { dragFraction = splitFraction }
                                splitFraction = min(0.75, max(0.3, (dragFraction ?? splitFraction) - value.translation.width / geometry.size.width))
                            }.onEnded { _ in dragFraction = nil })
                            .accessibilityLabel("تغيير عرض المستند").accessibilityAdjustableAction { direction in splitFraction = min(0.75, max(0.3, splitFraction + (direction == .increment ? 0.05 : -0.05))) }
                        notesPane
                    }
                } else if splitNotes {
                    VStack(spacing: 0) { NativePDF(workspace: workspace).frame(height: geometry.size.height * splitFraction); Divider(); notesPane }
                } else { NativePDF(workspace: workspace) }
            }
            if workspace.tool == .lasso { lassoControls }
            if audio.recording { Label("جارٍ التسجيل — الملاحظات مرتبطة بزمن الصوت", systemImage: "record.circle").font(.caption).foregroundStyle(.red).padding(8) }
            if workspace.tool != .ink { pageControls }
        }
    }
    private var documentPresentation: some View {
        documentContent.navigationTitle(note.title).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button(workspace.tool == .ink ? "قراءة" : "قلم", systemImage: workspace.tool == .ink ? "hand.draw" : "pencil.tip") { workspace.tool = workspace.tool == .ink ? .read : .ink }.accessibilityIdentifier("inkTool").accessibilityValue(String(workspace.inkStrokeCount))
                    Button("نص", systemImage: "textformat") { pageFocused = false; workspace.tool = .text }.tint(workspace.tool == .text ? .orange : nil).accessibilityIdentifier("textTool")
                    Menu {
                        Button(splitNotes ? "إغلاق الشاشة المقسومة" : "المستند والحاشية معًا", systemImage: "rectangle.split.2x1") { splitNotes.toggle() }
                        Button("تحديد الكتابة", systemImage: "lasso") { workspace.tool = .lasso }
                        Button("إنشاء بطاقة من النص المحدد", systemImage: "rectangle.on.rectangle") {
                            let selected = workspace.view?.currentSelection?.string ?? ""
                            cardDraft = Flashcard(question: "", answer: selected, page: workspace.page)
                        }
                        Button("بطاقات المراجعة", systemImage: "rectangle.stack") { showCards = true }
                        Button("الكتابة المرتبطة بالصوت", systemImage: "waveform") { splitNotes = true }
                        Button(audio.recording ? "إيقاف التسجيل المرتبط" : "تسجيل مع الكتابة", systemImage: "mic") { if audio.recording { audio.stop() } else { splitNotes = true; Task { await audio.start(); if let error = audio.error { workspace.error = error } } } }
                        Menu("قراءة الصفحات المصورة محليًا") {
                            Button("العربية") { recognize("ar") }
                            Button("الإنجليزية") { recognize("en") }
                        }.disabled(ocrBusy)
                        if note.originalFile != nil { Button("أصل Office والوسائط", systemImage: "doc") { original = true } }
                        Button("الحاشية", systemImage: "note.text") { showNotes = true }
                        Button("تسجيلات الصفحة", systemImage: "mic") { showAudio = true }
                        Button("تصدير PDF", systemImage: "square.and.arrow.up") { workspace.export() }
                    } label: { Image(systemName: "ellipsis.circle") }.accessibilityLabel("أدوات المستند").accessibilityIdentifier("documentTools")
                }
            }
            .overlay(alignment: .top) { if workspace.tool == .text { Text("المس الصفحة لإضافة نص، واضغط مرتين على نصك لتعديله.").font(.caption).padding(10).background(.regularMaterial, in: Capsule()).padding(8).allowsHitTesting(false) } }
            .onChange(of: pageFocused) { _, focused in
                if focused { pageNumber = "" }
                else if pageNumber.isEmpty { pageNumber = String(workspace.page) }
            }
            .onChange(of: workspace.page) { _, page in pageNumber = String(page) }

    }
    private var documentSheets: some View {
        documentPresentation
            .sheet(item: $cardDraft) { card in CardEditor(card: card) { updated in
                let cards = FlashcardStore(url: cardsURL); let saved = cards.save(updated); if let error = cards.error { workspace.error = error }; return saved
            } }
            .sheet(isPresented: $showCards) { FlashcardsScreen(url: cardsURL) }
            .sheet(isPresented: $original) { if let file = note.originalFile {
                NavigationStack { OfficePreview(url: root.appendingPathComponent(file)).toolbar {
                    Button("وسائط الملف") { showMedia = true }
                    Button("تم") { original = false }
                }.sheet(isPresented: $showMedia) { OfficeMediaScreen(source: root.appendingPathComponent(file)) } }
            } }
            .sheet(item: $workspace.editing) { item in TextEditorSheet(item: item, save: workspace.saveText) }
            .sheet(isPresented: $showAudio) { PageAudioScreen(folder: root.appendingPathComponent(note.id.uuidString + "-audio").appendingPathComponent(String(workspace.page))) }
            .sheet(isPresented: $showNotes) {
                NavigationStack { TextEditor(text: $margin).padding().navigationTitle("الحاشية").toolbar { Button("تم") { showNotes = false } } }.environment(\.layoutDirection, .rightToLeft)
            }
            .sheet(isPresented: Binding(get: { workspace.exported != nil }, set: { if !$0 { workspace.exported = nil } })) {
                if let url = workspace.exported { ShareDocument(url: url) }
            }

    }
    private var cardsURL: URL { root.appendingPathComponent(note.id.uuidString + "-cards.json") }
    private var notesPane: some View {
        VStack(alignment: .leading) {
            Text("الحاشية").font(.headline).padding(.horizontal)
            Picker("طريقة تدوين الحاشية", selection: $marginInk) { Text("نص").tag(false); Text("خط اليد").tag(true) }.pickerStyle(.segmented).padding(.horizontal)
            if marginInk {
                MarginNotebook(url: root.appendingPathComponent(note.id.uuidString + "-margin.drawing"), saved: { count in
                    do { try audio.link(page: workspace.page, strokeCount: count, label: "كتابة في دفتر الحاشية") } catch { workspace.error = error.localizedDescription }
                }, failed: { workspace.error = $0 })
            } else { TextEditor(text: $margin).padding(8).accessibilityIdentifier("splitNotes") }
            if !audio.markers.isEmpty {
                ScrollView { ForEach(audio.markers.filter { $0.page == workspace.page }) { marker in
                    Button("\(Int(marker.time / 60)):\(String(format: "%02d", Int(marker.time) % 60)) — " + marker.label) { audio.seek(marker) }.frame(maxWidth: .infinity, alignment: .leading).padding(8)
                } }.frame(maxHeight: 150)
            }
        }
    }
    private var lassoControls: some View {
        ScrollView(.horizontal) { HStack {
            Text("حدد بالقلم حول الكتابة (\(workspace.selectedInkCount))").font(.caption)
            ForEach([("يسار", "left"), ("يمين", "right"), ("أعلى", "up"), ("أسفل", "down"), ("تكبير", "grow"), ("تصغير", "shrink"), ("نسخ", "copy"), ("لصق", "paste")], id: \.1) { title, action in
                Button(title) { workspace.inkAction?(action) }.buttonStyle(.bordered)
            }
            Button("تم") { workspace.tool = .read }
        }.padding(8) }
    }
    private func recognize(_ language: String) {
        guard !ocrBusy else { return }; ocrBusy = true
        let file = root.appendingPathComponent(note.file), cache = root.appendingPathComponent(note.id.uuidString + "-ocr.json")
        Task {
            defer { ocrBusy = false }
            do { let count = try await Task.detached(priority: .userInitiated) { try LibrarySearch.recognize(file: file, cache: cache, language: language) }.value; ocrMessage = "تمت قراءة \(count) صفحات مصورة وإضافتها للبحث." }
            catch { ocrMessage = error.localizedDescription }
        }
    }
    private var pageControls: some View {
        HStack {
                Button("السابق", systemImage: "chevron.right") { workspace.jump(workspace.page - 1) }.labelStyle(.iconOnly).disabled(workspace.page <= 1)
                TextField("الصفحة", text: $pageNumber).keyboardType(.numberPad).multilineTextAlignment(.center).frame(width: 55).textFieldStyle(.roundedBorder).accessibilityIdentifier("pageNumber").focused($pageFocused)
                Text("من \(workspace.document.pageCount)").font(.caption)
                Button("اذهب") { pageFocused = false; workspace.jump(Int(pageNumber) ?? 0) }.accessibilityIdentifier("goToPage")
                Button("التالي", systemImage: "chevron.left") { workspace.jump(workspace.page + 1) }.labelStyle(.iconOnly).disabled(workspace.page >= workspace.document.pageCount)
                Spacer(minLength: 4)
                Button("ملاءمة", systemImage: "arrow.up.left.and.arrow.down.right") { workspace.fit() }.labelStyle(.iconOnly)
            }.padding(12).background(.ultraThinMaterial)
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
        let view = PDFView()
        // Register the overlay provider before PDFKit creates visible page views.
        // Assigning it after the document can leave the first page without ink.
        workspace.view = view
        view.pageOverlayViewProvider = context.coordinator
        view.document = workspace.document; view.autoScales = true; view.displayMode = .singlePageContinuous
        view.backgroundColor = UIColor(red: 0.92, green: 0.94, blue: 0.92, alpha: 1)
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
        if let target = workspace.document.page(at: workspace.page - 1) { view.go(to: target) }
        view.accessibilityIdentifier = "pdfCanvas"
        workspace.inkAction = { [weak coordinator = context.coordinator] action in coordinator?.applyInkAction(action) }
        return view
    }
    func updateUIView(_ view: PDFView, context: Context) { context.coordinator.setDrawing(workspace.tool == .ink || workspace.tool == .lasso) }
    @MainActor final class Coordinator: NSObject, PDFPageOverlayViewProvider, PKCanvasViewDelegate, UIGestureRecognizerDelegate {
        let workspace: PDFWorkspace
        var canvases: [Int: LassoCanvas] = [:]
        var copiedInk: PKDrawing?
        var lastStrokeCounts: [Int: Int] = [:]
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
        @objc func tap(_ gesture: UITapGestureRecognizer) {
            guard let view = workspace.view else { return }
            if workspace.tool == .read, let page = view.page(for: gesture.location(in: view), nearest: false), let id = page.annotation(at: view.convert(gesture.location(in: view), to: page))?.userName, let uuid = UUID(uuidString: id) { workspace.onTextTapped?(uuid) }
            if workspace.tool == .text { workspace.edit(at: gesture.location(in: view), in: view, allowNew: true) }
        }
        @objc func doubleTap(_ gesture: UITapGestureRecognizer) { guard (workspace.tool != .ink && workspace.tool != .lasso), let view = workspace.view else { return }; workspace.edit(at: gesture.location(in: view), in: view, allowNew: false) }
        @objc func hold(_ gesture: UILongPressGestureRecognizer) { guard gesture.state == .began, (workspace.tool != .ink && workspace.tool != .lasso), let view = workspace.view else { return }; workspace.edit(at: gesture.location(in: view), in: view, allowNew: false) }
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            // PDFKit has its own taps for selection. They must not consume our
            // text annotation taps. Panning and drawing remain exclusive.
            (workspace.tool != .ink && workspace.tool != .lasso) &&
                !(gestureRecognizer is UIPanGestureRecognizer) &&
                !(otherGestureRecognizer is UIPanGestureRecognizer)
        }
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard gestureRecognizer is UIPanGestureRecognizer else { return (workspace.tool != .ink && workspace.tool != .lasso) }
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
            for canvas in canvases.values { canvas.enableLasso(workspace.tool == .lasso); picker.setVisible(workspace.tool == .ink, forFirstResponder: canvas) }
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
            picker.setVisible(workspace.tool == .ink, forFirstResponder: canvas)
        }
        func pdfView(_ view: PDFView, overlayViewFor page: PDFPage) -> UIView? {
            let index = workspace.document.index(for: page)
            if let canvas = canvases[index] { return canvas }
            let canvas = LassoCanvas(frame: page.bounds(for: .mediaBox))
            canvas.backgroundColor = .clear; canvas.isOpaque = false; canvas.drawingPolicy = .anyInput; canvas.delegate = self; canvas.tag = index; canvas.isUserInteractionEnabled = enabled
            canvas.isScrollEnabled = false
            canvas.accessibilityIdentifier = "inkCanvas-\(index)"
            canvas.isAccessibilityElement = true
            canvas.accessibilityLabel = "مساحة القلم، عدد الخطوط"
            canvas.tool = PKInkingTool(.pen, color: .darkGray, width: 3)
            if let data = try? Data(contentsOf: workspace.storage.appendingPathComponent("\(index).drawing")), let ink = try? PKDrawing(data: data) { canvas.drawing = ink }
            canvas.accessibilityValue = String(canvas.drawing.strokes.count)
            canvas.enableLasso(workspace.tool == .lasso)
            canvas.selectionChanged = { [weak workspace] count in workspace?.selectedInkCount = count }
            lastStrokeCounts[index] = canvas.drawing.strokes.count
            canvases[index] = canvas; picker.addObserver(canvas)
            return canvas
        }
        func pdfView(_ view: PDFView, willDisplayOverlayView overlayView: UIView, for page: PDFPage) {
            if enabled { activateCurrentCanvas() }
        }
        func applyInkAction(_ action: String) {
            guard let canvas = canvases[workspace.page - 1] else { return }
            if action == "copy" {
                guard !canvas.selected.isEmpty else { return }
                copiedInk = PKDrawing(strokes: canvas.selected.map { canvas.drawing.strokes[$0] }); return
            }
            guard action == "paste" ? copiedInk != nil : !canvas.selected.isEmpty else { return }
            let previous = canvas.drawing
            canvas.undoManager?.registerUndo(withTarget: canvas) { target in target.drawing = previous }
            if action == "paste" { if let copiedInk { canvas.drawing = PKDrawing(strokes: canvas.drawing.strokes + copiedInk.strokes) }; return }
            let bounds = PKDrawing(strokes: canvas.selected.map { canvas.drawing.strokes[$0] }).bounds
            var transform = CGAffineTransform.identity
            switch action {
            case "left": transform = CGAffineTransform(translationX: -10, y: 0)
            case "right": transform = CGAffineTransform(translationX: 10, y: 0)
            case "up": transform = CGAffineTransform(translationX: 0, y: -10)
            case "down": transform = CGAffineTransform(translationX: 0, y: 10)
            case "grow", "shrink":
                let factor: CGFloat = action == "grow" ? 1.1 : 0.9
                transform = CGAffineTransform(translationX: -bounds.midX, y: -bounds.midY).concatenating(CGAffineTransform(scaleX: factor, y: factor)).concatenating(CGAffineTransform(translationX: bounds.midX, y: bounds.midY))
            default: return
            }
            canvas.drawing = InkSelection.transform(canvas.drawing, indices: canvas.selected, by: transform)
            canvas.points = canvas.points.map { $0.applying(transform) }; canvas.setNeedsDisplay()
        }
        func canvasViewDrawingDidChange(_ canvas: PKCanvasView) {
            canvas.accessibilityValue = String(canvas.drawing.strokes.count)
            do {
                try canvas.drawing.dataRepresentation().write(to: workspace.storage.appendingPathComponent("\(canvas.tag).drawing"), options: .atomic)
                let count = canvas.drawing.strokes.count
                if count > (lastStrokeCounts[canvas.tag] ?? 0) { workspace.onInkSaved?(canvas.tag, count) }
                lastStrokeCounts[canvas.tag] = count
                if canvas.tag == workspace.page - 1 { workspace.inkStrokeCount = canvas.drawing.strokes.count }
            }
            catch { workspace.error = error.localizedDescription }
        }
    }
}
