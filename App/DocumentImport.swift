import Foundation
import PDFKit
import ZIPFoundation

/// A validated snapshot. No provider URL escapes its coordinated read.
struct ImportedDocument: Sendable {
    let url: URL
    let title: String

    func discard() { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
}

enum DocumentImport {
    static func prepare(_ source: URL) throws -> ImportedDocument {
        let granted = source.startAccessingSecurityScopedResource()
        defer { if granted { source.stopAccessingSecurityScopedResource() } }
        let ext = source.pathExtension.lowercased()
        guard ["pdf", "pptx", "docx", "xlsx", "ppt", "doc", "xls"].contains(ext) else {
            throw DocumentImportError.unsupported
        }
        let fm = FileManager.default
        let folder = fm.temporaryDirectory.appendingPathComponent("hashiya-import-" + UUID().uuidString)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        let snapshot = ImportedDocument(url: folder.appendingPathComponent("document." + ext),
                                        title: source.deletingPathExtension().lastPathComponent)
        do {
            var coordinationError: NSError?
            var copyError: Error?
            NSFileCoordinator().coordinate(readingItemAt: source, options: [], error: &coordinationError) { readable in
                do {
                    let size = try readable.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
                    guard size.isRegularFile == true, let bytes = size.fileSize, bytes > 0 else {
                        throw DocumentImportError.damaged
                    }
                    guard bytes <= 128 * 1024 * 1024 else { throw DocumentImportError.tooLarge }
                    try fm.copyItem(at: readable, to: snapshot.url)
                } catch { copyError = error }
            }
            if let coordinationError { throw coordinationError }
            if let copyError { throw copyError }
            try validate(snapshot.url)
            return snapshot
        } catch {
            snapshot.discard()
            throw error
        }
    }

    private static func validate(_ url: URL) throws {
        let ext = url.pathExtension.lowercased()
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size > 0 else { throw DocumentImportError.damaged }
        guard size <= 128 * 1024 * 1024 else { throw DocumentImportError.tooLarge }
        if ext == "pdf" {
            guard let pdf = PDFDocument(url: url), !pdf.isLocked, pdf.pageCount > 0 else {
                throw DocumentImportError.damaged
            }
        } else if let required = ["pptx": "ppt/presentation.xml", "docx": "word/document.xml",
                                  "xlsx": "xl/workbook.xml"][ext] {
            let archive = try Archive(url: url, accessMode: .read)
            guard archive["[Content_Types].xml"] != nil, archive[required] != nil else {
                throw DocumentImportError.damaged
            }
        }
    }
}
