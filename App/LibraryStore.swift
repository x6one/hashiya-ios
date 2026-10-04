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
            try removeBundledOfficeDemo()
        } catch { self.error = error.localizedDescription }
    }
    /// Remove only the obsolete bundled demo, never a user's similarly named file.
    private func removeBundledOfficeDemo() throws {
        guard let fixture = Bundle.main.url(forResource: "office-demo", withExtension: "pptx"),
              let bytes = try? Data(contentsOf: fixture) else { return }
        let demos = notebooks.filter {
            $0.title == "تجربة Office" && (try? Data(contentsOf: root.appendingPathComponent($0.file))) == bytes
        }
        guard !demos.isEmpty else { return }
        let ids = Set(demos.map(\.id))
        let remaining = notebooks.filter { !ids.contains($0.id) }
        try persist(remaining)
        notebooks = remaining
        for demo in demos { try? FileManager.default.removeItem(at: root.appendingPathComponent(demo.file)) }
    }
    /// Validate first, persist a single replacement, then retire our Office copy.
    /// The source outside the app is never deleted, and a failed save keeps Office.
    @discardableResult
    func replaceOfficeWithPDF(_ id: UUID, source: URL) async throws -> Notebook {
        guard source.pathExtension.lowercased() == "pdf",
              let original = notebooks.first(where: { $0.id == id && !$0.trashed }),
              (original.file as NSString).pathExtension.lowercased() != "pdf" else { throw DocumentImportError.unsupported }
        let snapshot = try await Task.detached(priority: .userInitiated) { try DocumentImport.prepare(source) }.value
        defer { snapshot.discard() }
        try Task.checkCancellation()
        var updated = notebooks
        guard let index = updated.firstIndex(where: { $0.id == id && $0.file == original.file && !$0.trashed }) else {
            throw DocumentImportError.unsupported
        }
        let name = UUID().uuidString + ".pdf"
        let target = root.appendingPathComponent(name)
        try FileManager.default.moveItem(at: snapshot.url, to: target)
        updated[index].originalFile = original.originalFile ?? original.file
        updated[index].file = name
        do { try persist(updated) }
        catch { try? FileManager.default.removeItem(at: target); throw error }
        notebooks = updated
        // Keep the original Office source for preview, media, sharing and backup.
        return updated[index]
    }
    func change(_ id: UUID, _ mutation: (inout Notebook) -> Void) {
        var updated = notebooks
        guard let i = updated.firstIndex(where: { $0.id == id }) else { return }
        mutation(&updated[i])
        do { try persist(updated); notebooks = updated } catch { self.error = error.localizedDescription }
    }
    func persist(_ items: [Notebook]) throws {
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
            for name in note.resources {
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
    func create(_ title: String, section: String? = nil, template: PaperTemplate = .ruled, color: PaperColor = .cream) {
        do {
            let name = UUID().uuidString + ".pdf"
            let url = root.appendingPathComponent(name)
            try template.render(color: color).write(to: url, options: .atomic)
            var note = Notebook(title: title, file: name)
            note.section = section.flatMap { sections.contains($0) ? $0 : nil } ?? "مكتبتي"
            var updated = notebooks
            updated.insert(note, at: 0)
            do { try persist(updated); notebooks = updated }
            catch { try? FileManager.default.removeItem(at: url); throw error }
        } catch { self.error = error.localizedDescription }
    }
}
