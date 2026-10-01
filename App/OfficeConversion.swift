import Foundation
import PDFKit

enum OfficeConversion {
    static var available: Bool {
        #if HASHIYA_NATIVE_OFFICE
        true
        #else
        false
        #endif
    }
    // One process-wide COKit instance, called on one serial queue. No engine
    // work or provider materialization is performed on the UI thread.
    private static let queue = DispatchQueue(label: "com.ahmadalawi.hashiya.office", qos: .userInitiated)

    static func convert(_ source: URL) async throws -> URL {
        #if HASHIYA_NATIVE_OFFICE
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                let folder = FileManager.default.temporaryDirectory.appendingPathComponent("hashiya-office-" + UUID().uuidString)
                do {
                    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                    let snapshot = try DocumentImport.prepare(source)
                    defer { snapshot.discard() }
                    let output = folder.appendingPathComponent("document.pdf")
                    if let error = HashiyaOfficeEngine.conversionError(source: snapshot.url, output: output) {
                        throw error
                    }
                    guard let document = PDFDocument(url: output), !document.isLocked, document.pageCount > 0 else {
                        throw DocumentImportError.damaged
                    }
                    continuation.resume(returning: output)
                } catch {
                    try? FileManager.default.removeItem(at: folder)
                    continuation.resume(throwing: error)
                }
            }
        }
        #else
        throw DocumentImportError.unsupported
        #endif
    }
}
