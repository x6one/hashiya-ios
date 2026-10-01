import SwiftUI
import PDFKit
import ZIPFoundation
@MainActor final class LibraryStore: ObservableObject {
    @Published var notebooks: [Notebook] = []
    @Published var error: String?
    @Published var sections: [String] = ["مكتبتي"]
    let root: URL
    init(root directory: URL? = nil, seedDemo: Bool = true) {
        root = directory ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let file = root.appendingPathComponent("library.json")
            let sectionFile = root.appendingPathComponent("sections.json")
            if let data = try? Data(contentsOf: sectionFile) { sections = try JSONDecoder().decode([String].self, from: data) }
            if FileManager.default.fileExists(atPath: file.path) { notebooks = try JSONDecoder().decode([Notebook].self, from: Data(contentsOf: file)) }
            else if seedDemo, let demo = Bundle.main.url(forResource: "english", withExtension: "pdf") { try importPDF(demo, title: "ملف التجربة") }
        } catch { self.error = error.localizedDescription }
    }
    func change(_ id: UUID, _ mutation: (inout Notebook) -> Void) {
        var updated = notebooks
        guard let i = updated.firstIndex(where: { $0.id == id }) else { return }
        mutation(&updated[i])
        do { try persist(updated); notebooks = updated } catch { self.error = error.localizedDescription }
    }
    private func persist(_ items: [Notebook]) throws {
        try JSONEncoder().encode(items).write(to: root.appendingPathComponent("library.json"), options: .atomic)
    }
    func addSection(_ raw: String) {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !sections.contains(name) else { return }
        do { let updated = sections + [name]; try JSONEncoder().encode(updated).write(to: root.appendingPathComponent("sections.json"), options: .atomic); sections = updated }
        catch { self.error = error.localizedDescription }
    }
    func deleteSection(_ name: String) {
        guard name != "مكتبتي" else { return }
        do {
            var updated = notebooks
            for i in updated.indices where updated[i].section == name { updated[i].section = "مكتبتي" }
            try persist(updated); notebooks = updated
            let remaining = sections.filter { $0 != name }
            try JSONEncoder().encode(remaining).write(to: root.appendingPathComponent("sections.json"), options: .atomic)
            sections = remaining
        } catch { self.error = error.localizedDescription }
    }
    func permanentlyDelete(_ note: Notebook) {
        guard notebooks.contains(where: { $0.id == note.id && $0.trashed }) else { return }
        let fm = FileManager.default
        let staging = root.appendingPathComponent("deleting-" + UUID().uuidString)
        var moved: [(URL, URL)] = []
        do {
            try fm.createDirectory(at: staging, withIntermediateDirectories: true)
            for name in [note.file, note.id.uuidString, note.id.uuidString + "-margin.txt", note.id.uuidString + "-text.json", note.id.uuidString + "-audio"] {
                let original = root.appendingPathComponent(name)
                if fm.fileExists(atPath: original.path) {
                    let target = staging.appendingPathComponent(name)
                    try fm.moveItem(at: original, to: target); moved.append((original, target))
                }
            }
            let remaining = notebooks.filter { $0.id != note.id }
            do { try persist(remaining) }
            catch { for (original, target) in moved { try? fm.moveItem(at: target, to: original) }; throw error }
            notebooks = remaining
            try fm.removeItem(at: staging)
        } catch {
            if notebooks.contains(where: { $0.id == note.id }) {
                for (original, target) in moved where fm.fileExists(atPath: target.path) { try? fm.moveItem(at: target, to: original) }
                try? fm.removeItem(at: staging)
            }
            self.error = error.localizedDescription
        }
    }
    func save() {
        do { try JSONEncoder().encode(notebooks).write(to: root.appendingPathComponent("library.json"), options: .atomic) }
        catch { self.error = error.localizedDescription }
    }
    func importPDF(_ source: URL, title: String? = nil) throws { try importDocument(source, title: title) }
    func importDocument(_ source: URL, title: String? = nil, section: String? = nil) throws {
        let snapshot = try DocumentImport.prepare(source)
        defer { snapshot.discard() }
        try acceptImport(snapshot, title: title, section: section)
    }
    @discardableResult
    func importDocumentAsync(_ source: URL, title: String? = nil, section: String? = nil) async throws -> Notebook {
        let snapshot = try await Task.detached(priority: .userInitiated) {
            try DocumentImport.prepare(source)
        }.value
        defer { snapshot.discard() }
        try Task.checkCancellation()
        return try acceptImport(snapshot, title: title, section: section)
    }
    @discardableResult
    private func acceptImport(_ snapshot: ImportedDocument, title: String?, section: String?) throws -> Notebook {
        let name = UUID().uuidString + "." + snapshot.url.pathExtension
        let target = root.appendingPathComponent(name)
        try FileManager.default.moveItem(at: snapshot.url, to: target)
        var updated = notebooks
        var note = Notebook(title: title ?? snapshot.title, file: name)
        note.section = section.flatMap { sections.contains($0) ? $0 : nil } ?? "مكتبتي"
        updated.insert(note, at: 0)
        do {
            try JSONEncoder().encode(updated).write(to: root.appendingPathComponent("library.json"), options: .atomic)
            notebooks = updated
        } catch { try? FileManager.default.removeItem(at: target); throw error }
        return note
    }
    func create(_ title: String, section: String? = nil) {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 650, height: 900))
        let data = renderer.pdfData { ctx in
            ctx.beginPage()
            UIColor(red: 1, green: 0.995, blue: 0.98, alpha: 1).setFill()
            ctx.cgContext.fill(CGRect(x: 0, y: 0, width: 650, height: 900))
            UIColor.systemGray5.setStroke()
            for y in stride(from: 70, through: 850, by: 30) { ctx.cgContext.move(to: CGPoint(x: 40, y: CGFloat(y))); ctx.cgContext.addLine(to: CGPoint(x: 610, y: CGFloat(y))) }
            ctx.cgContext.strokePath()
        }
        do {
            let name = UUID().uuidString + ".pdf"
            let url = root.appendingPathComponent(name)
            try data.write(to: url, options: .atomic)
            var note = Notebook(title: title, file: name)
            note.section = section.flatMap { sections.contains($0) ? $0 : nil } ?? "مكتبتي"
            var updated = notebooks
            updated.insert(note, at: 0)
            do { try persist(updated); notebooks = updated }
            catch { try? FileManager.default.removeItem(at: url); throw error }
        }
        catch { self.error = error.localizedDescription }
    }
}
