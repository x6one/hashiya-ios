import UniformTypeIdentifiers

/// Shared system types for the native SwiftUI file importer.
enum DocumentPicker {
    // Ask Files for the system types of the supported extensions themselves.
    // Composite Office types must not depend on a broad data/content filter.
    static let contentTypes: [UTType] = ["pdf", "pptx", "docx", "xlsx", "ppt", "doc", "xls"]
        .compactMap { UTType(filenameExtension: $0) }
}
