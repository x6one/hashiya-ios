import Foundation
import PDFKit
import Vision
import UIKit

struct SearchHit: Identifiable, Hashable {
    let notebook: UUID
    let title: String
    let page: Int?
    let snippet: String
    var id: String { notebook.uuidString + "-" + String(page ?? -1) + "-" + snippet }
}
struct OCRPage: Codable { let page: Int; let text: String }
enum LibrarySearch {
    static func find(_ query: String, notes: [Notebook], root: URL) throws -> [SearchHit] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        var hits: [SearchHit] = []
        for note in notes where !note.trashed {
            try Task.checkCancellation()
            if note.title.localizedCaseInsensitiveContains(query) { hits.append(SearchHit(notebook: note.id, title: note.title, page: nil, snippet: note.section)) }
            let file = root.appendingPathComponent(note.file)
            let doc = file.pathExtension.lowercased() == "pdf" ? PDFDocument(url: file) : nil
            if doc == nil, let content = try? OfficeSearch.text(in: file), let range = content.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) {
                let start = content.index(range.lowerBound, offsetBy: -45, limitedBy: content.startIndex) ?? content.startIndex
                let end = content.index(range.upperBound, offsetBy: 100, limitedBy: content.endIndex) ?? content.endIndex
                hits.append(SearchHit(notebook: note.id, title: note.title, page: nil, snippet: String(content[start..<end])))
            }
            let texts = (try? JSONDecoder().decode([PageText].self, from: Data(contentsOf: root.appendingPathComponent(note.id.uuidString + "-text.json")))) ?? []
            let ocr = (try? JSONDecoder().decode([OCRPage].self, from: Data(contentsOf: root.appendingPathComponent(note.id.uuidString + "-ocr.json")))) ?? []
            for index in 0..<(doc?.pageCount ?? 0) {
                try Task.checkCancellation()
                let content = [doc?.page(at: index)?.string ?? "", texts.filter { $0.page == index }.map(\.text).joined(separator: "\n"), ocr.filter { $0.page == index }.map(\.text).joined(separator: "\n")].joined(separator: "\n")
                if let range = content.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) {
                    let start = content.index(range.lowerBound, offsetBy: -45, limitedBy: content.startIndex) ?? content.startIndex
                    let end = content.index(range.upperBound, offsetBy: 100, limitedBy: content.endIndex) ?? content.endIndex
                    hits.append(SearchHit(notebook: note.id, title: note.title, page: index + 1, snippet: String(content[start..<end])))
                }
            }
            if let margin = try? String(contentsOf: root.appendingPathComponent(note.id.uuidString + "-margin.txt"), encoding: .utf8), margin.localizedCaseInsensitiveContains(query) {
                hits.append(SearchHit(notebook: note.id, title: note.title, page: nil, snippet: "الحاشية: " + String(margin.prefix(160))))
            }
        }
        return hits
    }
    /// Vision language support is queried on the actual OS, never assumed.
    static func recognize(file: URL, cache: URL, language: String) throws -> Int {
        let request = VNRecognizeTextRequest(); request.recognitionLevel = .accurate
        let supported = try request.supportedRecognitionLanguages()
        guard let selected = supported.first(where: { $0 == language || $0.hasPrefix(language + "-") }) else {
            throw NSError(domain: "TayyaOCR", code: 1, userInfo: [NSLocalizedDescriptionKey: "التعرف على هذه اللغة غير مدعوم على إصدار جهازك. لم يتم إرسال أي بيانات لخدمة خارجية."])
        }
        request.recognitionLanguages = [selected]; request.usesLanguageCorrection = true
        guard let document = PDFDocument(url: file) else { throw DocumentImportError.damaged }
        var pages: [OCRPage] = []
        for index in 0..<document.pageCount {
            try Task.checkCancellation()
            guard let page = document.page(at: index), (page.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            let image = page.thumbnail(of: CGSize(width: 1600, height: 2200), for: .mediaBox)
            guard let cgImage = image.cgImage else { continue }
            try VNImageRequestHandler(cgImage: cgImage).perform([request])
            let text = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
            pages.append(OCRPage(page: index, text: text))
        }
        try JSONEncoder().encode(pages).write(to: cache, options: .atomic)
        return pages.count
    }
}
