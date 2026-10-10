import Foundation
import PDFKit
import CryptoKit
import SwiftUI

enum PageRemovalError: LocalizedError {
    case lastPage, changed, invalid
    var errorDescription: String? {
        switch self {
        case .lastPage: return "يجب أن يبقى في المستند صفحة واحدة على الأقل."
        case .changed: return "تغيّر المستند بعد الحذف. لم تتم استعادة نسخة قديمة فوق كتابتك الجديدة."
        case .invalid: return "تعذّر تعديل الصفحات بأمان. لم يتم استبدال بياناتك."
        }
    }
}
private struct PageEditJournal: Codable {
    var pending: Bool
    var existing: Set<String>
    var after: [String: String]
}
/// A recoverable transaction covers PDF and every page-indexed sidecar. A crash
/// during publication rolls back on the next open, before PDFKit reads the file.
enum DocumentPageRemoval {
    private static let fm = FileManager.default
    private static func folder(_ note: Notebook, _ root: URL) -> URL { root.appendingPathComponent(note.id.uuidString + "-page-edit") }
    private static func locations(_ note: Notebook, _ root: URL) -> [String: URL] {
        ["pdf": root.appendingPathComponent(note.file), "ink": root.appendingPathComponent(note.id.uuidString),
         "text": root.appendingPathComponent(note.id.uuidString + "-text.json"),
         "ocr": root.appendingPathComponent(note.id.uuidString + "-ocr.json"),
         "cards": root.appendingPathComponent(note.id.uuidString + "-cards.json"),
         "margins": root.appendingPathComponent(note.id.uuidString + "-margins"),
         "audio": root.appendingPathComponent(note.id.uuidString + "-audio")]
    }
    private static func journal(_ note: Notebook, _ root: URL) throws -> PageEditJournal {
        try JSONDecoder().decode(PageEditJournal.self, from: Data(contentsOf: folder(note, root).appendingPathComponent("journal.json")))
    }
    private static func write(_ value: PageEditJournal, to folder: URL) throws {
        try JSONEncoder().encode(value).write(to: folder.appendingPathComponent("journal.json"), options: .atomic)
    }
    static func recover(_ note: Notebook, root: URL) throws {
        guard fm.fileExists(atPath: folder(note, root).appendingPathComponent("journal.json").path) else { return }
        let state = try journal(note, root)
        if state.pending { try restore(note, root: root, state: state); try fm.removeItem(at: folder(note, root)) }
    }
    static func hasUndo(_ note: Notebook, root: URL) -> Bool { (try? journal(note, root).pending) == false }
    private static func restore(_ note: Notebook, root: URL, state: PageEditJournal) throws {
        let targets = locations(note, root), before = folder(note, root).appendingPathComponent("before")
        guard state.existing.isSubset(of: Set(targets.keys)), state.existing.contains("pdf") else { throw PageRemovalError.invalid }
        // Validate all snapshot bytes before changing any live resources.
        for key in state.existing where !fm.fileExists(atPath: before.appendingPathComponent(key).path) { throw PageRemovalError.invalid }
        for (key, target) in targets {
            if fm.fileExists(atPath: target.path) { try fm.removeItem(at: target) }
            if state.existing.contains(key) { try fm.copyItem(at: before.appendingPathComponent(key), to: target) }
        }
    }
    static func undo(_ note: Notebook, root: URL) throws {
        var state = try journal(note, root)
        guard !state.pending, try fingerprint(locations(note, root)) == state.after else { throw PageRemovalError.changed }
        state.pending = true; try write(state, to: folder(note, root))
        try restore(note, root: root, state: state)
        try fm.removeItem(at: folder(note, root))
    }
    private static func fingerprint(_ locations: [String: URL]) throws -> [String: String] {
        var result: [String: String] = [:]
        for (key, url) in locations where fm.fileExists(atPath: url.path) {
            let values = try url.resourceValues(forKeys: [.isDirectoryKey])
            let files: [URL]
            if values.isDirectory == true {
                guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey]) else { throw PageRemovalError.invalid }
                files = try enumerator.allObjects.compactMap { object in
                    guard let file = object as? URL else { return nil }
                    return try file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true ? file : nil
                }
                result[key + "/"] = "directory"
            } else { files = [url] }
            for file in files {
                let handle = try FileHandle(forReadingFrom: file); defer { try? handle.close() }
                var hash = SHA256()
                while let chunk = try handle.read(upToCount: 1024 * 1024), !chunk.isEmpty { hash.update(data: chunk) }
                result[key + String(file.path.dropFirst(url.path.count))] = hash.finalize().map { String(format: "%02x", $0) }.joined()
            }
        }
        return result
    }
    static func delete(_ number: Int, note: Notebook, root: URL) throws {
        try recover(note, root: root)
        let targets = locations(note, root)
        guard let document = PDFDocument(url: targets["pdf"]!), number > 0, number <= document.pageCount else { throw PageRemovalError.invalid }
        guard document.pageCount > 1 else { throw PageRemovalError.lastPage }
        let removed = number - 1
        let staging = root.appendingPathComponent("page-edit-" + UUID().uuidString)
        let before = staging.appendingPathComponent("before"), after = staging.appendingPathComponent("after")
        try fm.createDirectory(at: before, withIntermediateDirectories: true)
        try fm.createDirectory(at: after, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: staging) }
        var existing = Set<String>()
        for (key, source) in targets where fm.fileExists(atPath: source.path) {
            existing.insert(key); try fm.copyItem(at: source, to: before.appendingPathComponent(key))
            try fm.copyItem(at: source, to: after.appendingPathComponent(key))
        }
        document.removePage(at: removed)
        guard let pdf = document.dataRepresentation() else { throw PageRemovalError.invalid }
        try pdf.write(to: after.appendingPathComponent("pdf"), options: .atomic)
        func remap(_ page: Int, base: Int) -> Int? { page == removed + base ? nil : page > removed + base ? page - 1 : page }
        func transform<T: Codable>(_ type: T.Type, key: String, change: (T) throws -> T) throws {
            guard existing.contains(key) else { return }
            let path = after.appendingPathComponent(key)
            let value = try JSONDecoder().decode(T.self, from: Data(contentsOf: path))
            try JSONEncoder().encode(change(value)).write(to: path, options: .atomic)
        }
        try transform([PageText].self, key: "text") { values in values.compactMap { item in
            guard let page = remap(item.page, base: 0) else { return nil }; var value = item; value.page = page; return value
        } }
        try transform([OCRPage].self, key: "ocr") { values in values.compactMap { item in
            remap(item.page, base: 0).map { OCRPage(page: $0, text: item.text) }
        } }
        try transform([Flashcard].self, key: "cards") { values in values.compactMap { item in
            guard let page = remap(item.page, base: 1) else { return nil }; var value = item; value.page = page; return value
        } }
        if existing.contains("ink") {
            let destination = after.appendingPathComponent("ink")
            for source in try fm.contentsOfDirectory(at: before.appendingPathComponent("ink"), includingPropertiesForKeys: nil) where source.pathExtension == "drawing" {
                guard Int(source.deletingPathExtension().lastPathComponent) != nil else { continue }
                try fm.removeItem(at: destination.appendingPathComponent(source.lastPathComponent))
            }
            for source in try fm.contentsOfDirectory(at: before.appendingPathComponent("ink"), includingPropertiesForKeys: nil) where source.pathExtension == "drawing" {
                if let index = Int(source.deletingPathExtension().lastPathComponent), let page = remap(index, base: 0) {
                    try fm.copyItem(at: source, to: destination.appendingPathComponent("\(page).drawing"))
                }
            }
        }
        if existing.contains("margins") {
            let directory = after.appendingPathComponent("margins")
            let index = try JSONDecoder().decode(MarginIndex.self, from: Data(contentsOf: directory.appendingPathComponent("index.json")))
            guard index.version == 1 else { throw PageRemovalError.invalid }
            for id in index.pages + (index.deleted ?? []) {
                let path = directory.appendingPathComponent(id.uuidString + ".json")
                var page = try JSONDecoder().decode(MarginPage.self, from: Data(contentsOf: path))
                if let source = page.sourcePage { page.sourcePage = remap(source, base: 1) }
                try JSONEncoder().encode(page).write(to: path, options: .atomic)
            }
        }
        if existing.contains("audio") {
            let destination = after.appendingPathComponent("audio")
            for source in try fm.contentsOfDirectory(at: before.appendingPathComponent("audio"), includingPropertiesForKeys: nil) where Int(source.lastPathComponent) != nil {
                try fm.removeItem(at: destination.appendingPathComponent(source.lastPathComponent))
            }
            for source in try fm.contentsOfDirectory(at: before.appendingPathComponent("audio"), includingPropertiesForKeys: nil) {
                if let index = Int(source.lastPathComponent), let page = remap(index, base: 1) { try fm.copyItem(at: source, to: destination.appendingPathComponent(String(page))) }
            }
            let links = destination.appendingPathComponent("linked/links.json")
            if fm.fileExists(atPath: links.path) {
                let original = try JSONDecoder().decode([AudioLink].self, from: Data(contentsOf: links))
                let updated: [AudioLink] = original.compactMap { item in
                    guard let page = remap(item.page, base: 1) else { return nil }; var value = item; value.page = page; return value
                }
                try JSONEncoder().encode(updated).write(to: links, options: .atomic)
            }
        }
        let afterLocations = Dictionary(uniqueKeysWithValues: existing.map { ($0, after.appendingPathComponent($0)) })
        var state = PageEditJournal(pending: true, existing: existing, after: try fingerprint(afterLocations))
        try write(state, to: staging)
        let transaction = folder(note, root)
        if fm.fileExists(atPath: transaction.path) { try fm.removeItem(at: transaction) }
        try fm.moveItem(at: staging, to: transaction)
        do {
            for (key, target) in targets where existing.contains(key) {
                try fm.removeItem(at: target)
                try fm.copyItem(at: transaction.appendingPathComponent("after").appendingPathComponent(key), to: target)
            }
            state.pending = false; try write(state, to: transaction)
            try? fm.removeItem(at: transaction.appendingPathComponent("after"))
        } catch {
            try recover(note, root: root); throw error
        }
    }
}

struct DocumentPageList: View {
    @ObservedObject var workspace: PDFWorkspace
    let deleting: (Int) -> Void
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List(1...max(1, workspace.document.pageCount), id: \.self) { number in
                HStack(spacing: 16) {
                    Button { workspace.jump(number); dismiss() } label: {
                        HStack(spacing: 16) {
                            if let page = workspace.document.page(at: number - 1) {
                                Image(uiImage: page.thumbnail(of: CGSize(width: 100, height: 140), for: .mediaBox)).resizable().scaledToFit().frame(width: 54, height: 72)
                            }
                            Text("صفحة \(number)").font(.headline)
                            Spacer()
                            if number == workspace.page { Image(systemName: "checkmark.circle.fill") }
                        }
                    }.buttonStyle(.plain)
                    Button("حذف صفحة \(number)", systemImage: "trash", role: .destructive) { dismiss(); deleting(number) }
                        .labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44).disabled(workspace.document.pageCount <= 1)
                }
            }.navigationTitle("صفحات المستند").toolbar { ToolbarItem(placement: .cancellationAction) { Button("تم") { dismiss() } } }
        }.environment(\.layoutDirection, .rightToLeft)
    }
}
