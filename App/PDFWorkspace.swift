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
    @Published private(set) var document: PDFDocument
    let storage: URL
    let textURL: URL
    let fileURL: URL
    let originalPDFURL: URL
    @Published var tool: Tool = .read
    @Published var brush: InkBrush = .pen
    @Published var inkColor = TayyaTheme.brandInk
    @Published var inkWidth = 3.0
    @Published var page = 1
    @Published var inkStrokeCount = 0
    @Published var editing: PageText?
    @Published var error: String?
    @Published var exported: URL?
    @Published var selectedInkCount = 0
    @Published var canUndoPageDeletion = false
    var inkAction: ((String) -> Void)?
    var onTextSaved: ((PageText) -> Void)?
    var onInkSaved: ((Int, Int) -> Void)?
    var onTextTapped: ((UUID) -> Void)?
    private(set) var texts: [PageText] = []
    weak var view: PDFView?
    init(note: Notebook, root: URL) {
        fileURL = root.appendingPathComponent(note.file)
        originalPDFURL = root.appendingPathComponent(note.id.uuidString + "-source.pdf")
        var recoveryError: Error?
        do { try DocumentPageRemoval.recover(note, root: root) } catch { recoveryError = error }
        document = recoveryError == nil ? (PDFDocument(url: fileURL) ?? PDFDocument()) : PDFDocument()
        storage = root.appendingPathComponent(note.id.uuidString)
        textURL = root.appendingPathComponent(note.id.uuidString + "-text.json")
        do {
            try FileManager.default.createDirectory(at: storage, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: textURL.path) { texts = try JSONDecoder().decode([PageText].self, from: Data(contentsOf: textURL)) }
            for item in texts { install(item) }
            inkStrokeCount = savedInkCount(on: 0)
            canUndoPageDeletion = DocumentPageRemoval.hasUndo(note, root: root)
            if let recoveryError { self.error = recoveryError.localizedDescription }
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
            texts = updated; canUndoPageDeletion = false
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
    /// Append keeps the existing page-indexed ink, text, OCR and audio anchors valid.
    func appendPaper(_ template: PaperTemplate) {
        guard let paper = PDFDocument(data: template.render(color: .cream))?.page(at: 0) else { return }
        let index = document.pageCount
        var copiedOriginal = false
        do {
            if !FileManager.default.fileExists(atPath: originalPDFURL.path) {
                try FileManager.default.copyItem(at: fileURL, to: originalPDFURL); copiedOriginal = true
            }
            document.insert(paper, at: index)
            guard let data = document.dataRepresentation() else { throw DocumentImportError.damaged }
            try data.write(to: fileURL, options: .atomic)
            canUndoPageDeletion = false; jump(index + 1)
        } catch {
            if document.pageCount > index { document.removePage(at: index) }
            if copiedOriginal { try? FileManager.default.removeItem(at: originalPDFURL) }
            self.error = error.localizedDescription
        }
    }
    func deletePage(_ number: Int, note: Notebook, root: URL) throws {
        try DocumentPageRemoval.delete(number, note: note, root: root)
        try reload(page: min(number, document.pageCount - 1))
        canUndoPageDeletion = true
    }
    func undoPageDeletion(note: Notebook, root: URL) throws {
        try DocumentPageRemoval.undo(note, root: root)
        try reload(page: page)
        canUndoPageDeletion = false
    }
    private func reload(page requested: Int) throws {
        guard let updated = PDFDocument(url: fileURL) else { throw PageRemovalError.invalid }
        let newTexts = FileManager.default.fileExists(atPath: textURL.path) ? try JSONDecoder().decode([PageText].self, from: Data(contentsOf: textURL)) : []
        document = updated; texts = newTexts
        for item in texts { install(item) }
        page = max(1, min(requested, document.pageCount)); inkStrokeCount = savedInkCount(on: page - 1)
        selectedInkCount = 0; editing = nil
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
    @State private var toolGroup: WorkspaceToolGroup = .writing
    @State private var showPaperPicker = false
    @State private var showDocumentPages = false
    @State private var deletingPage: Int?
    @State private var confirmDocumentDeletion = false
    @State private var pendingPageDeletion: Int?
    @State private var showAudio = false
    @State private var showLinkedAudio = false
    @StateObject private var margins: MarginPages
    @State private var notesExpanded = false
    @State private var splitNotes = false
    @AppStorage("tayya.splitFraction") private var splitFraction = 0.55
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
        _margins = StateObject(wrappedValue: MarginPages(root: root, notebook: note.id))
        _audio = StateObject(wrappedValue: PageAudio(folder: root.appendingPathComponent(note.id.uuidString + "-audio").appendingPathComponent("linked")))
    }
    var body: some View {
        documentSheets
            .onAppear {
                if let initialPage { workspace.jump(initialPage) }
                workspace.onTextSaved = { item in do { try audio.link(page: item.page + 1, textID: item.id, label: String(item.text.prefix(70))) } catch { workspace.error = error.localizedDescription } }
                workspace.onInkSaved = { page, count in do { try audio.link(page: page + 1, strokeCount: count, label: "كتابة بخط اليد — صفحة \(page + 1)") } catch { workspace.error = error.localizedDescription } }
                workspace.onTextTapped = { id in if !audio.recording, let marker = audio.markers.last(where: { $0.textID == id }) { audio.seek(marker) } }
            }
            .onDisappear { audio.stop(); _ = margins.flush() }
            .onChange(of: scenePhase) { _, phase in if phase != .active { audio.stop() } }
            .overlay(alignment: .bottom) { if ocrBusy { ProgressView("قراءة الصفحات على الجهاز…").padding().background(.regularMaterial) } }
            .alert("قراءة الصفحات", isPresented: Binding(get: { !ocrMessage.isEmpty }, set: { if !$0 { ocrMessage = "" } })) { Button("حسنًا") { ocrMessage = "" } } message: { Text(ocrMessage) }
            .alert("تعذّر إكمال العملية", isPresented: Binding(get: { workspace.error != nil }, set: { if !$0 { workspace.error = nil } })) { Button("حسناً") { workspace.error = nil } } message: { Text(workspace.error ?? "") }
    }
    private var documentContent: some View {
        VStack(spacing: 0) {
            if !notesExpanded { toolsBar }
            // Navigation is outside the drawing area and tool picker on every device.
            if !notesExpanded { pageControls }
            if workspace.tool == .ink && !notesExpanded {
                InkToolbar(brush: $workspace.brush, color: $workspace.inkColor, width: $workspace.inkWidth) { action in
                    if action == "fit" { workspace.fit() } else { workspace.inkAction?(action) }
                }
            }
            GeometryReader { geometry in
                if notesExpanded { notesPane }
                else if splitNotes && geometry.size.width >= 650 {
                    HStack(spacing: 0) {
                        NativePDF(workspace: workspace).frame(width: (geometry.size.width - 16) * boundedFraction)
                        splitDivider(size: geometry.size, horizontal: true)
                        notesPane.frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else if splitNotes {
                    VStack(spacing: 0) {
                        NativePDF(workspace: workspace).frame(height: (geometry.size.height - 16) * boundedFraction)
                        splitDivider(size: geometry.size, horizontal: false)
                        notesPane.frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else { NativePDF(workspace: workspace) }
            }
            if workspace.tool == .lasso && !notesExpanded { lassoControls }
            if audio.recording { Label("جارٍ التسجيل — الملاحظات مرتبطة بزمن الصوت", systemImage: "record.circle").font(.caption).foregroundStyle(.red).padding(8) }
        }
    }
    private var boundedFraction: Double { min(0.7, max(0.3, splitFraction)) }
    private func splitDivider(size: CGSize, horizontal: Bool) -> some View {
        Rectangle().fill(TayyaTheme.ink.opacity(0.12))
            .frame(width: horizontal ? 16 : nil, height: horizontal ? nil : 16)
            .overlay { Capsule().fill(TayyaTheme.ink.opacity(0.5)).frame(width: horizontal ? 4 : 40, height: horizontal ? 40 : 4) }
            .contentShape(Rectangle())
            .gesture(DragGesture().onChanged { value in
                if dragFraction == nil { dragFraction = boundedFraction }
                let delta = horizontal ? -value.translation.width / max(1, size.width - 16) : value.translation.height / max(1, size.height - 16)
                splitFraction = min(0.7, max(0.3, (dragFraction ?? boundedFraction) + delta))
            }.onEnded { _ in dragFraction = nil })
            .accessibilityElement().accessibilityLabel("تغيير تقسيم الشاشة")
            .accessibilityIdentifier("splitDivider")
            .accessibilityAdjustableAction { direction in splitFraction = min(0.7, max(0.3, boundedFraction + (direction == .increment ? 0.05 : -0.05))) }
    }
    private var documentPresentation: some View {
        documentContent.navigationTitle(note.title).navigationBarTitleDisplayMode(.inline)
            .overlay(alignment: .top) { if workspace.tool == .text { Text("المس الصفحة لإضافة نص، واضغط مرتين على نصك لتعديله.").font(.caption).padding(10).background(.regularMaterial, in: Capsule()).padding(8).allowsHitTesting(false) } }
            .onChange(of: pageFocused) { _, focused in
                if focused { pageNumber = "" }
                else if pageNumber.isEmpty { pageNumber = String(workspace.page) }
            }
            .onChange(of: workspace.page) { _, page in pageNumber = String(page) }

    }
    private var toolsBar: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { toolGroupPicker.frame(width: 240); toolActions.frame(minWidth: 360) }
            VStack(spacing: 6) { toolGroupPicker; toolActions }
        }.padding(.horizontal, 8).padding(.top, 6).background(TayyaTheme.surface)
    }
    private var toolGroupPicker: some View {
        Picker("مجموعة الأدوات", selection: $toolGroup) {
                ForEach(WorkspaceToolGroup.allCases) { group in Text(group.rawValue).tag(group) }
            }.pickerStyle(.segmented).accessibilityIdentifier("workspaceToolGroups")
    }
    private var toolActions: some View {
        ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    switch toolGroup {
                    case .writing:
                        WorkspaceAction(title: "قلم", symbol: "pencil.tip", selected: workspace.tool == .ink) { pageFocused = false; workspace.tool = workspace.tool == .ink ? .read : .ink }.accessibilityIdentifier("inkTool").accessibilityValue(String(workspace.inkStrokeCount))
                        WorkspaceAction(title: "نص", symbol: "textformat", selected: workspace.tool == .text) { pageFocused = false; workspace.tool = .text }.accessibilityIdentifier("textTool")
                        WorkspaceAction(title: "تحديد", symbol: "lasso", selected: workspace.tool == .lasso) { workspace.tool = .lasso }
                        WorkspaceAction(title: "تقسيم", symbol: "rectangle.split.2x1", selected: splitNotes && !notesExpanded) { workspace.tool = .read; notesExpanded = false; splitNotes.toggle() }.accessibilityIdentifier("splitDocumentNotes")
                        WorkspaceAction(title: "الحاشية", symbol: "note.text", selected: notesExpanded) { workspace.tool = .read; splitNotes = true; notesExpanded = true }.accessibilityIdentifier("openMargin")
                    case .pages:
                        WorkspaceAction(title: "إضافة ورقة", symbol: "doc.badge.plus") { showPaperPicker = true }.accessibilityIdentifier("addWritingPaper")
                        WorkspaceAction(title: "كل الصفحات", symbol: "square.grid.2x2") { showDocumentPages = true }.accessibilityIdentifier("documentPages")
                        WorkspaceAction(title: "حذف الصفحة", symbol: "trash") { deletingPage = workspace.page; confirmDocumentDeletion = true }.disabled(workspace.document.pageCount <= 1).accessibilityIdentifier("deleteDocumentPage")
                        WorkspaceAction(title: "تراجع الحذف", symbol: "arrow.uturn.backward") { changeDocumentPage(undo: true) }.disabled(!workspace.canUndoPageDeletion).accessibilityIdentifier("undoDocumentPageDeletion")
                        WorkspaceAction(title: "ملاءمة", symbol: "arrow.up.left.and.arrow.down.right") { workspace.fit() }
                    case .study:
                        WorkspaceAction(title: "بطاقة جديدة", symbol: "rectangle.badge.plus") { cardDraft = Flashcard(question: "", answer: workspace.view?.currentSelection?.string ?? "", page: workspace.page) }
                        WorkspaceAction(title: "البطاقات", symbol: "rectangle.stack") { showCards = true }.accessibilityIdentifier("openFlashcards")
                        WorkspaceAction(title: audio.recording ? "إيقاف التسجيل" : "تسجيل", symbol: audio.recording ? "stop.circle" : "mic", selected: audio.recording) {
                            if audio.recording { audio.stop() } else { splitNotes = true; Task { await audio.start(); if let error = audio.error { workspace.error = error } } }
                        }.accessibilityIdentifier("recordLinkedAudio")
                        WorkspaceAction(title: "الصوت المرتبط", symbol: "waveform") { showLinkedAudio = true }.accessibilityIdentifier("openLinkedAudio")
                        WorkspaceAction(title: "صوت الصفحة", symbol: "mic.circle") { showAudio = true }
                        WorkspaceAction(title: "قراءة العربية", symbol: "text.viewfinder") { recognize("ar") }.disabled(ocrBusy)
                        WorkspaceAction(title: "قراءة الإنجليزية", symbol: "text.viewfinder") { recognize("en") }.disabled(ocrBusy)
                    case .files:
                        WorkspaceAction(title: "تصدير PDF", symbol: "square.and.arrow.up") { workspace.export() }
                        if note.originalFile != nil { WorkspaceAction(title: "أصل Office", symbol: "doc") { original = true } }
                    }
                }.padding(.vertical, 2).disabled(toolGroup == .pages && ocrBusy)
            }
    }
    private func changeDocumentPage(undo: Bool = false) {
        audio.stop(); workspace.tool = .read
        guard margins.flush() else { workspace.error = margins.error; return }
        do {
            if undo { try workspace.undoPageDeletion(note: note, root: root) }
            else if let deletingPage { try workspace.deletePage(deletingPage, note: note, root: root) }
            margins.reload(); audio.markers = audio.loadLinks()
            deletingPage = nil
        } catch { workspace.error = error.localizedDescription }
    }
    private var documentSheets: some View {
        documentPresentation
            .sheet(isPresented: $showPaperPicker) { WritingPaperPicker(add: workspace.appendPaper) }
            .sheet(isPresented: $showDocumentPages, onDismiss: { deletingPage = pendingPageDeletion; confirmDocumentDeletion = pendingPageDeletion != nil; pendingPageDeletion = nil }) { DocumentPageList(workspace: workspace, deleting: { pendingPageDeletion = $0 }) }
            .confirmationDialog("حذف صفحة المستند \(deletingPage ?? 0) وكتابتها؟", isPresented: $confirmDocumentDeletion, titleVisibility: .visible) {
                Button("حذف الصفحة", role: .destructive) { changeDocumentPage(); confirmDocumentDeletion = false }
                Button("إلغاء", role: .cancel) { deletingPage = nil }
            } message: { Text("حواشيك المستقلة تبقى محفوظة. يمكنك التراجع عن الحذف ما لم تعدّل المستند بعده.") }
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
            .sheet(isPresented: $showLinkedAudio) { LinkedAudioScreen(audio: audio, jump: workspace.jump) }
            .sheet(isPresented: $showAudio) { PageAudioScreen(folder: root.appendingPathComponent(note.id.uuidString + "-audio").appendingPathComponent(String(workspace.page))) }
            .sheet(isPresented: Binding(get: { workspace.exported != nil }, set: { if !$0 { workspace.exported = nil } })) {
                if let url = workspace.exported { ShareDocument(url: url) }
            }

    }
    private var cardsURL: URL { root.appendingPathComponent(note.id.uuidString + "-cards.json") }
    private var notesPane: some View {
        MarginPane(store: margins, editor: margins.editor, sourcePage: workspace.page, expanded: notesExpanded,
                   toggleExpanded: { pageFocused = false; notesExpanded.toggle() },
                   jump: { page in workspace.jump(page); notesExpanded = false }, inkSaved: recordMarginInk, textSaved: recordMarginText)
    }
    private func recordMarginText(_ text: String, _ id: UUID) {
        workspace.canUndoPageDeletion = false
        let source = margins.pages.first { $0.id == id }?.sourcePage ?? workspace.page
        do { try audio.link(page: source, label: "حاشية \(margins.position + 1): " + String(text.suffix(70))) }
        catch { workspace.error = error.localizedDescription }
    }
    private func recordMarginInk(_ count: Int, _ id: UUID) {
        workspace.canUndoPageDeletion = false
        let source = margins.pages.first { $0.id == id }?.sourcePage ?? workspace.page
        do { try audio.link(page: source, strokeCount: count, label: "خط يد في الحاشية \(margins.position + 1)") }
        catch { workspace.error = error.localizedDescription }
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
                Button("السابق في المستند", systemImage: "chevron.right") { workspace.jump(workspace.page - 1) }.labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44).disabled(workspace.page <= 1).accessibilityIdentifier("previousDocumentPage")
                TextField("الصفحة", text: $pageNumber).keyboardType(.numberPad).multilineTextAlignment(.center).frame(width: 55).textFieldStyle(.roundedBorder).accessibilityIdentifier("pageNumber").focused($pageFocused)
                Text("من \(workspace.document.pageCount)").font(.caption)
                Button("اذهب") { pageFocused = false; workspace.jump(Int(pageNumber) ?? 0) }.accessibilityIdentifier("goToPage")
                Button("التالي في المستند", systemImage: "chevron.left") { workspace.jump(workspace.page + 1) }.labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44).disabled(workspace.page >= workspace.document.pageCount).accessibilityIdentifier("nextDocumentPage")
                Spacer(minLength: 4)
                Button("ملاءمة", systemImage: "arrow.up.left.and.arrow.down.right") { workspace.fit() }.labelStyle(.iconOnly)
            }.padding(.horizontal, 8).background(TayyaTheme.surface)
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
final class ResizingPDFView: PDFView {
    private var previousSize = CGSize.zero
    override func layoutSubviews() {
        let resized = bounds.size != previousSize
        previousSize = bounds.size
        let page = currentPage
        super.layoutSubviews()
        guard resized, autoScales, bounds.width > 0, bounds.height > 0 else { return }
        scaleFactor = scaleFactorForSizeToFit
        if let page { go(to: page) }
    }
}
struct NativePDF: UIViewRepresentable {
    @ObservedObject var workspace: PDFWorkspace
    func makeCoordinator() -> Coordinator { Coordinator(workspace: workspace) }
    func makeUIView(context: Context) -> PDFView {
        let view = ResizingPDFView()
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
    func updateUIView(_ view: PDFView, context: Context) {
        if view.document !== workspace.document {
            for canvas in context.coordinator.canvases.values { canvas.delegate = nil; canvas.resignFirstResponder() }
            context.coordinator.canvases.removeAll(); context.coordinator.lastStrokeCounts.removeAll()
            view.document = workspace.document
            if let page = workspace.document.page(at: workspace.page - 1) { view.go(to: page) }
        }
        context.coordinator.setDrawing(workspace.tool == .ink || workspace.tool == .lasso)
    }
    @MainActor final class Coordinator: NSObject, PDFPageOverlayViewProvider, PKCanvasViewDelegate, UIGestureRecognizerDelegate {
        let workspace: PDFWorkspace
        var canvases: [Int: LassoCanvas] = [:]
        var copiedInk: PKDrawing?
        var lastStrokeCounts: [Int: Int] = [:]
        var enabled = false
        var dragging: PageText?
        var dragOrigin: CGPoint?
        init(workspace: PDFWorkspace) { self.workspace = workspace }
        deinit { NotificationCenter.default.removeObserver(self) }
        @objc func pageChanged() {
            guard let view = workspace.view, let page = view.currentPage else { return }
            let index = workspace.document.index(for: page)
            guard index >= 0, index < workspace.document.pageCount else { return }
            workspace.page = index + 1
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
            for canvas in canvases.values {
                canvas.enableLasso(workspace.tool == .lasso)
                canvas.tool = workspace.brush.tool(color: UIColor(workspace.inkColor), width: workspace.inkWidth)
            }
            guard enabled != value else { return }; enabled = value
            for canvas in canvases.values {
                canvas.isUserInteractionEnabled = value
                if !value { canvas.resignFirstResponder() }
            }
            if value { activateCurrentCanvas() }
        }
        private func activateCurrentCanvas() {
            guard let view = workspace.view, let page = view.currentPage,
                  let canvas = canvases[workspace.document.index(for: page)], canvas.window != nil else { return }
            canvas.becomeFirstResponder()
        }
        func pdfView(_ view: PDFView, overlayViewFor page: PDFPage) -> UIView? {
            let index = workspace.document.index(for: page)
            if let canvas = canvases[index] { return canvas }
            let canvas = LassoCanvas(frame: page.bounds(for: .mediaBox))
            canvas.backgroundColor = .clear; canvas.isOpaque = false; canvas.drawingPolicy = .anyInput; canvas.tag = index; canvas.isUserInteractionEnabled = enabled
            canvas.isScrollEnabled = false
            canvas.accessibilityIdentifier = "inkCanvas-\(index)"
            canvas.isAccessibilityElement = true
            canvas.accessibilityLabel = "مساحة القلم، عدد الخطوط"
            canvas.tool = workspace.brush.tool(color: UIColor(workspace.inkColor), width: workspace.inkWidth)
            if let data = try? Data(contentsOf: workspace.storage.appendingPathComponent("\(index).drawing")), let ink = try? PKDrawing(data: data) { canvas.drawing = ink }
            canvas.delegate = self
            canvas.accessibilityValue = String(canvas.drawing.strokes.count)
            canvas.enableLasso(workspace.tool == .lasso)
            canvas.selectionChanged = { [weak workspace] count in workspace?.selectedInkCount = count }
            lastStrokeCounts[index] = canvas.drawing.strokes.count
            canvases[index] = canvas
            return canvas
        }
        func pdfView(_ view: PDFView, willDisplayOverlayView overlayView: UIView, for page: PDFPage) {
            if enabled { activateCurrentCanvas() }
        }
        func applyInkAction(_ action: String) {
            guard let canvas = canvases[workspace.page - 1] else { return }
            if action == "undo" { canvas.undoManager?.undo(); return }
            if action == "redo" { canvas.undoManager?.redo(); return }
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
                workspace.canUndoPageDeletion = false
                let count = canvas.drawing.strokes.count
                if count > (lastStrokeCounts[canvas.tag] ?? 0) { workspace.onInkSaved?(canvas.tag, count) }
                lastStrokeCounts[canvas.tag] = count
                if canvas.tag == workspace.page - 1 { workspace.inkStrokeCount = canvas.drawing.strokes.count }
            }
            catch { workspace.error = error.localizedDescription }
        }
    }
}
