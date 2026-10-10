import SwiftUI
import PencilKit
import PDFKit

struct MarginPage: Codable, Identifiable {
    var id = UUID()
    var title = ""
    var sourcePage: Int?
    var text = ""
    var ink = Data()
    var width: Double = 650
    var height: Double = 900
}
struct MarginIndex: Codable {
    var version = 1
    var pages: [UUID]
    var current: UUID
    var deleted: [UUID]? = nil
}
enum MarginError: LocalizedError {
    case damaged
    var errorDescription: String? { "تعذّر فتح صفحات الحاشية. بياناتك محفوظة ولم يتم استبدالها." }
}

/// Each page is an atomic file. The index is published only after a new page
/// exists; the pre-0.4.1 files are retained unchanged after migration.
@MainActor final class MarginPages: ObservableObject {
    @Published private(set) var pages: [MarginPage] = []
    @Published private(set) var currentID: UUID?
    @Published private(set) var deletedPages: [MarginPage] = []
    @Published var error: String?
    @Published private(set) var saved = true
    let editor = MarginEditorState()
    let folder: URL
    private let notebookID: UUID
    private var pending = Set<UUID>()
    var current: MarginPage? { pages.first { $0.id == currentID } }
    var position: Int { pages.firstIndex { $0.id == currentID } ?? 0 }
    init(root: URL, notebook: UUID) {
        notebookID = notebook
        folder = root.appendingPathComponent(notebook.uuidString + "-margins")
        do {
            let indexURL = folder.appendingPathComponent("index.json")
            if FileManager.default.fileExists(atPath: indexURL.path) {
                let index = try JSONDecoder().decode(MarginIndex.self, from: Data(contentsOf: indexURL))
                guard index.version == 1, !index.pages.isEmpty,
                      Set(index.pages).count == index.pages.count, index.pages.contains(index.current) else { throw MarginError.damaged }
                pages = try index.pages.map { id in
                    let page = try JSONDecoder().decode(MarginPage.self, from: Data(contentsOf: pageURL(id)))
                    guard page.id == id, page.width.isFinite, page.height.isFinite,
                          page.width > 0, page.height > 0 else { throw MarginError.damaged }
                    if !page.ink.isEmpty { _ = try PKDrawing(data: page.ink) }
                    return page
                }
                deletedPages = try (index.deleted ?? []).map { id in
                    let page = try JSONDecoder().decode(MarginPage.self, from: Data(contentsOf: pageURL(id)))
                    guard page.id == id, !index.pages.contains(id), page.width.isFinite, page.height.isFinite, page.width > 0, page.height > 0 else { throw MarginError.damaged }
                    if !page.ink.isEmpty { _ = try PKDrawing(data: page.ink) }
                    return page
                }
                guard Set(deletedPages.map(\.id)).count == deletedPages.count else { throw MarginError.damaged }
                currentID = index.current
            } else {
                var page = MarginPage()
                let textURL = root.appendingPathComponent(notebook.uuidString + "-margin.txt")
                let inkURL = root.appendingPathComponent(notebook.uuidString + "-margin.drawing")
                if FileManager.default.fileExists(atPath: textURL.path) { page.text = try String(contentsOf: textURL, encoding: .utf8) }
                if FileManager.default.fileExists(atPath: inkURL.path) {
                    page.ink = try Data(contentsOf: inkURL)
                    let drawing = try PKDrawing(data: page.ink)
                    page.height = max(1200, drawing.bounds.maxY + 40)
                    page.width = max(650, drawing.bounds.maxX + 40)
                }
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                try write(page)
                try writeIndex([page], current: page.id)
                pages = [page]; currentID = page.id
            }
        } catch { pages = []; deletedPages = []; currentID = nil; self.error = error.localizedDescription }
    }
    private func pageURL(_ id: UUID) -> URL { folder.appendingPathComponent(id.uuidString + ".json") }
    private func write(_ page: MarginPage) throws { try JSONEncoder().encode(page).write(to: pageURL(page.id), options: .atomic) }
    private func writeIndex(_ pages: [MarginPage], current: UUID, deleted: [MarginPage]? = nil) throws {
        try JSONEncoder().encode(MarginIndex(pages: pages.map(\.id), current: current, deleted: (deleted ?? deletedPages).map(\.id)))
            .write(to: folder.appendingPathComponent("index.json"), options: .atomic)
    }
    @discardableResult func flush() -> Bool {
        do {
            for page in pages where pending.contains(page.id) { try write(page); pending.remove(page.id) }
            saved = pending.isEmpty; return true
        } catch { saved = false; self.error = error.localizedDescription; return false }
    }
    func editText(_ value: String, page id: UUID) {
        guard let index = pages.firstIndex(where: { $0.id == id }), pages[index].text != value else { return }
        pages[index].text = value; pending.insert(id); saved = false
        // Atomic save on every edit keeps app termination from losing a debounce.
        _ = flush()
    }
    func editTitle(_ value: String, page id: UUID) {
        guard let index = pages.firstIndex(where: { $0.id == id }) else { return }
        pages[index].title = value; pending.insert(id); saved = false; _ = flush()
    }
    func saveInk(_ drawing: PKDrawing, page id: UUID) {
        guard let index = pages.firstIndex(where: { $0.id == id }) else { return }
        pages[index].ink = drawing.dataRepresentation()
        if !drawing.strokes.isEmpty {
            pages[index].width = max(pages[index].width, drawing.bounds.maxX + 24)
            pages[index].height = max(pages[index].height, drawing.bounds.maxY + 24)
        }
        pending.insert(id); saved = false; _ = flush()
    }
    @discardableResult func select(_ id: UUID) -> Bool {
        guard pages.contains(where: { $0.id == id }), flush() else { return false }
        do { try writeIndex(pages, current: id); currentID = id; return true }
        catch { self.error = error.localizedDescription; return false }
    }
    func move(_ offset: Int) {
        let target = position + offset
        guard pages.indices.contains(target) else { return }; _ = select(pages[target].id)
    }
    @discardableResult func add(linkedTo source: Int?) -> Bool {
        guard !pages.isEmpty, flush() else { return false }
        var page = MarginPage(); page.sourcePage = source
        do {
            try write(page)
            try writeIndex(pages + [page], current: page.id)
            pages.append(page); currentID = page.id; return true
        } catch { self.error = error.localizedDescription; return false }
    }
    @discardableResult func delete(_ id: UUID) -> Bool {
        guard pages.count > 1, let index = pages.firstIndex(where: { $0.id == id }), flush() else { return false }
        var remaining = pages; let removed = remaining.remove(at: index)
        let selected = currentID == id ? remaining[min(index, remaining.count - 1)].id : (currentID ?? remaining[0].id)
        let archived = deletedPages + [removed]
        do {
            try writeIndex(remaining, current: selected, deleted: archived)
            pages = remaining; deletedPages = archived; currentID = selected; return true
        } catch { self.error = error.localizedDescription; return false }
    }
    @discardableResult func restore(_ id: UUID) -> Bool {
        guard let page = deletedPages.first(where: { $0.id == id }), flush() else { return false }
        let archived = deletedPages.filter { $0.id != id }
        do {
            try writeIndex(pages + [page], current: id, deleted: archived)
            pages.append(page); deletedPages = archived; currentID = id; return true
        } catch { self.error = error.localizedDescription; return false }
    }
    func reload() {
        guard flush() else { return }
        let updated = MarginPages(root: folder.deletingLastPathComponent(), notebook: notebookID)
        guard updated.error == nil else { error = updated.error; return }
        pages = updated.pages; deletedPages = updated.deletedPages; currentID = updated.currentID
    }
    func linkCurrent(to source: Int?) {
        guard let id = currentID, let index = pages.firstIndex(where: { $0.id == id }), flush() else { return }
        var updated = pages[index]; updated.sourcePage = source
        do { try write(updated); pages[index] = updated } catch { self.error = error.localizedDescription }
    }
    /// Read without creating or migrating resources (used by search).
    nonisolated static func read(root: URL, notebook: UUID) throws -> [MarginPage] {
        let folder = root.appendingPathComponent(notebook.uuidString + "-margins")
        let index = try JSONDecoder().decode(MarginIndex.self, from: Data(contentsOf: folder.appendingPathComponent("index.json")))
        guard index.version == 1 else { throw MarginError.damaged }
        return try index.pages.map { try JSONDecoder().decode(MarginPage.self, from: Data(contentsOf: folder.appendingPathComponent($0.uuidString + ".json"))) }
    }
    func export() throws -> URL {
        guard flush() else { throw MarginError.damaged }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Tayya-Notes-" + UUID().uuidString + ".pdf")
        let bounds = CGRect(x: 0, y: 0, width: 650, height: 900)
        let drawings = try pages.map { $0.ink.isEmpty ? PKDrawing() : try PKDrawing(data: $0.ink) }
        let renderer = UIGraphicsPDFRenderer(bounds: bounds)
        try renderer.writePDF(to: url) { context in
            for (index, page) in pages.enumerated() {
                let title = page.title.isEmpty ? "الحاشية \(index + 1)" : page.title
                func begin(_ suffix: String = "") {
                    context.beginPage(); PaperColor.cream.uiColor.setFill(); context.cgContext.fill(bounds)
                    ((title + suffix) as NSString).draw(in: CGRect(x: 40, y: 25, width: 570, height: 35), withAttributes: [.font: UIFont.systemFont(ofSize: 20), .foregroundColor: UIColor.darkGray])
                    if let source = page.sourcePage {
                        ("مرتبطة بصفحة المستند \(source)" as NSString).draw(at: CGPoint(x: 40, y: 860), withAttributes: [.font: UIFont.systemFont(ofSize: 12), .foregroundColor: UIColor.darkGray])
                    }
                }
                let drawing = drawings[index]
                if !drawing.strokes.isEmpty || page.text.isEmpty {
                    begin()
                    let source = CGRect(x: 0, y: 0, width: page.width, height: page.height).union(drawing.bounds)
                    let scale = min(570 / source.width, 760 / source.height)
                    drawing.image(from: source, scale: 1).draw(in: CGRect(x: 40, y: 75, width: source.width * scale, height: source.height * scale))
                }
                // Text gets its own continuation pages when ink is also present.
                // TextKit lays out every glyph; export never clips a long note.
                if !page.text.isEmpty {
                    let style = NSMutableParagraphStyle(); style.alignment = .natural; style.lineSpacing = 6
                    let storage = NSTextStorage(string: page.text, attributes: [.font: UIFont.systemFont(ofSize: 20), .foregroundColor: UIColor.darkGray, .paragraphStyle: style])
                    let layout = NSLayoutManager(); storage.addLayoutManager(layout)
                    var consumed = 0, continuation = 0
                    repeat {
                        let container = NSTextContainer(size: CGSize(width: 570, height: 750)); container.lineFragmentPadding = 0
                        layout.addTextContainer(container)
                        let range = layout.glyphRange(for: container)
                        guard range.length > 0 else { break }
                        begin(continuation == 0 ? " — النص" : " — متابعة النص")
                        layout.drawGlyphs(forGlyphRange: range, at: CGPoint(x: 40, y: 80))
                        consumed = NSMaxRange(range); continuation += 1
                    } while consumed < layout.numberOfGlyphs
                }
            }
        }
        return url
    }
}
