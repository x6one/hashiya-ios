import Foundation
import ZIPFoundation

extension Notebook {
    var resources: [String] {
        [file, originalFile, id.uuidString, id.uuidString + "-margin.txt", id.uuidString + "-text.json", id.uuidString + "-audio", id.uuidString + "-cards.json", id.uuidString + "-ocr.json"].compactMap { $0 }
    }
}
struct BackupManifest: Codable {
    var version = 1
    var notebooks: [Notebook]
    var sections: [String]
}
enum BackupError: LocalizedError {
    case invalid, limit
    var errorDescription: String? { self == .limit ? "النسخة كبيرة جدًا للاستعادة على هذا الجهاز." : "النسخة الاحتياطية غير صالحة أو ناقصة. لم تتغير مكتبتك." }
}
enum RestorePolicy: String, CaseIterable, Identifiable {
    case keepBoth = "حفظ النسختين", skipExisting = "تخطي الملفات الموجودة"
    var id: String { rawValue }
}
/// Archives contain only indexed resources. Restore stages and validates all bytes
/// before publishing the new index; existing resources are never overwritten.
enum LibraryBackup {
    static let maximumBytes = 2 * 1024 * 1024 * 1024
    static func validComponent(_ name: String) -> Bool {
        !name.isEmpty && name != "." && name != ".." && !name.contains("/") && !name.contains("\\")
    }
    static func export(root: URL, manifest: BackupManifest) throws -> URL {
        let fm = FileManager.default
        let staging = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let output = fm.temporaryDirectory.appendingPathComponent("Tayya-Backup-" + UUID().uuidString + ".zip")
        try fm.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: staging) }
        try JSONEncoder().encode(manifest).write(to: staging.appendingPathComponent("manifest.json"))
        for note in manifest.notebooks {
            for name in note.resources {
                guard validComponent(name) else { throw BackupError.invalid }
                let source = root.appendingPathComponent(name)
                if fm.fileExists(atPath: source.path), !fm.fileExists(atPath: staging.appendingPathComponent(name).path) {
                    try fm.copyItem(at: source, to: staging.appendingPathComponent(name))
                } else if name == note.file || name == note.originalFile { throw BackupError.invalid }
            }
        }
        try fm.zipItem(at: staging, to: output, shouldKeepParent: false)
        return output
    }
    static func unpack(_ source: URL, into staging: URL) throws -> BackupManifest {
        let archive = try Archive(url: source, accessMode: .read)
        let fm = FileManager.default
        try fm.createDirectory(at: staging, withIntermediateDirectories: true)
        var total: Int64 = 0
        var paths = Set<String>()
        for entry in archive {
            guard paths.insert(entry.path).inserted, paths.count <= 100000,
                  entry.type != .symlink, !entry.path.hasPrefix("/"), !entry.path.contains("\\"),
                  entry.path.split(separator: "/").allSatisfy({ $0 != ".." && $0 != "." }) else { throw BackupError.invalid }
            guard entry.uncompressedSize <= UInt64(maximumBytes) else { throw BackupError.limit }
            total += Int64(entry.uncompressedSize)
            guard total <= Int64(maximumBytes) else { throw BackupError.limit }
            let target = staging.appendingPathComponent(entry.path)
            if entry.type == .directory { try fm.createDirectory(at: target, withIntermediateDirectories: true); continue }
            try fm.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            guard fm.createFile(atPath: target.path, contents: nil) else { throw BackupError.invalid }
            let handle = try FileHandle(forWritingTo: target)
            var bytes: UInt64 = 0
            do {
                let crc = try archive.extract(entry) { data in
                    bytes += UInt64(data.count)
                    guard bytes <= UInt64(entry.uncompressedSize) else { throw BackupError.limit }
                    try handle.write(contentsOf: data)
                }
                try handle.close()
                guard crc == entry.checksum else { throw BackupError.invalid }
            } catch { try? handle.close(); throw error }
        }
        let manifest = try JSONDecoder().decode(BackupManifest.self, from: Data(contentsOf: staging.appendingPathComponent("manifest.json")))
        guard manifest.version == 1, Set(manifest.notebooks.map(\.id)).count == manifest.notebooks.count else { throw BackupError.invalid }
        for note in manifest.notebooks {
            guard note.resources.allSatisfy(validComponent), fm.fileExists(atPath: staging.appendingPathComponent(note.file).path) else { throw BackupError.invalid }
            if let original = note.originalFile, !fm.fileExists(atPath: staging.appendingPathComponent(original).path) { throw BackupError.invalid }
        }
        return manifest
    }
}
extension LibraryStore {
    func exportBackup() async throws -> URL {
        let manifest = BackupManifest(notebooks: notebooks, sections: sections)
        let directory = root
        return try await Task.detached(priority: .userInitiated) { try LibraryBackup.export(root: directory, manifest: manifest) }.value
    }
    @discardableResult func restoreBackup(_ source: URL, policy: RestorePolicy) async throws -> Int {
        let fm = FileManager.default
        let staging = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? fm.removeItem(at: staging) }
        let manifest = try await Task.detached(priority: .userInitiated) { try LibraryBackup.unpack(source, into: staging) }.value
        try Task.checkCancellation()
        var updated = notebooks
        var moved: [URL] = []
        let sectionURL = root.appendingPathComponent("sections.json")
        let previousSections = try? Data(contentsOf: sectionURL)
        var added = 0
        do {
            for var note in manifest.notebooks {
                let old = note
                let collision = updated.contains { $0.id == note.id }
                if collision && policy == .skipExisting { continue }
                if collision { note.id = UUID() }
                if collision { note.title += " (نسخة مستعادة)" }
                note.file = UUID().uuidString + "." + (old.file as NSString).pathExtension
                if let original = old.originalFile { note.originalFile = UUID().uuidString + "." + (original as NSString).pathExtension }
                for (oldName, newName) in zip(old.resources, note.resources) {
                    let src = staging.appendingPathComponent(oldName), dst = root.appendingPathComponent(newName)
                    if fm.fileExists(atPath: src.path) {
                        // Copy because multiple notebooks can refer to the same resource.
                        try fm.copyItem(at: src, to: dst); moved.append(dst)
                    }
                }
                updated.append(note); added += 1
            }
            let newSections = Array(Set(sections + manifest.sections + updated.map(\.section) + ["مكتبتي"])).sorted()
            try JSONEncoder().encode(newSections).write(to: sectionURL, options: .atomic)
            try persist(updated)
            sections = newSections; notebooks = updated
        } catch {
            for url in moved { try? fm.removeItem(at: url) }
            if let previousSections { try? previousSections.write(to: sectionURL, options: .atomic) }
            else { try? fm.removeItem(at: sectionURL) }
            throw error
        }
        return added
    }
}
