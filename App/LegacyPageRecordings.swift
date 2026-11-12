import Foundation

/// Existing page folders remain in place; new recordings use the linked folder.
struct LegacyPageRecordings: Identifiable {
    let page: Int
    let folder: URL
    var id: String { folder.path }

    static func folders(in root: URL) -> [LegacyPageRecordings] {
        let manager = FileManager.default
        guard let entries = try? manager.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey]) else { return [] }
        return entries.compactMap { folder in
            guard let page = Int(folder.lastPathComponent), page > 0,
                  (try? folder.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true,
                  let clips = try? manager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil),
                  clips.contains(where: { $0.pathExtension.lowercased() == "m4a" }) else { return nil }
            return LegacyPageRecordings(page: page, folder: folder)
        }.sorted { $0.page < $1.page }
    }
}
