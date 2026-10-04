import Foundation
import ZIPFoundation

final class OfficeTextParser: NSObject, XMLParserDelegate {
    var text = ""
    var reading = false
    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String]) {
        reading = ["t", "v"].contains(name.split(separator: ":").last.map(String.init) ?? name)
    }
    func parser(_ parser: XMLParser, foundCharacters string: String) { if reading { text += string } }
    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) { if reading { text += " "; reading = false } }
}
enum OfficeSearch {
    static func text(in file: URL) throws -> String {
        guard ["pptx", "docx", "xlsx"].contains(file.pathExtension.lowercased()) else { return "" }
        let archive = try Archive(url: file, accessMode: .read)
        var result = "", total = 0
        for entry in archive {
            try Task.checkCancellation()
            let name = entry.path
            guard entry.type == .file, name.hasSuffix(".xml"),
                  name == "word/document.xml" || name == "xl/sharedStrings.xml" || (name.hasPrefix("ppt/slides/slide") && !name.contains("/_rels/")) else { continue }
            guard entry.uncompressedSize <= 8 * 1024 * 1024 else { throw DocumentImportError.tooLarge }
            var data = Data()
            let crc = try archive.extract(entry) { chunk in
                total += chunk.count
                guard total <= 32 * 1024 * 1024 else { throw DocumentImportError.tooLarge }
                data.append(chunk)
            }
            guard crc == entry.checksum else { throw DocumentImportError.damaged }
            let reader = OfficeTextParser(), parser = XMLParser(data: data)
            parser.shouldResolveExternalEntities = false; parser.delegate = reader
            guard parser.parse() else { throw DocumentImportError.damaged }
            result += reader.text + "\n"
        }
        return result
    }
}
