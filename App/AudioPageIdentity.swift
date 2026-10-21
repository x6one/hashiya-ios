import Foundation

/// An additive sidecar in the existing backed-up audio folder. Legacy page
/// numbers remain readable; new markers retain identity when pages are removed.
struct AudioPageIdentityStore {
    struct PendingAppend: Codable { var baseCount: Int; var id: UUID }
    struct Index: Codable {
        var version = 1
        var pages: [UUID]
        var pendingAppend: PendingAppend?
    }
    let folder: URL
    var url: URL { folder.appendingPathComponent("page-identities.json") }

    func identities(pageCount: Int, create: Bool = false) throws -> [UUID]? {
        guard pageCount > 0 else { throw PageRemovalError.invalid }
        guard FileManager.default.fileExists(atPath: url.path) else {
            guard create else { return nil }
            let pages = (0..<pageCount).map { _ in UUID() }
            try write(Index(pages: pages))
            return pages
        }
        let index = try JSONDecoder().decode(Index.self, from: Data(contentsOf: url))
        guard index.version == 1, !index.pages.isEmpty,
              Set(index.pages).count == index.pages.count else { throw PageRemovalError.invalid }
        var pages = index.pages
        if let pending = index.pendingAppend {
            guard pending.baseCount == pages.count, !pages.contains(pending.id) else { throw PageRemovalError.invalid }
            if pageCount == pending.baseCount + 1 { pages.append(pending.id) }
            else if pageCount != pending.baseCount { throw PageRemovalError.invalid }
        }
        guard pages.count == pageCount else { throw PageRemovalError.invalid }
        return pages
    }
    func pageID(number: Int, pageCount: Int) throws -> UUID {
        guard number > 0, number <= pageCount,
              let pages = try identities(pageCount: pageCount, create: true) else { throw PageRemovalError.invalid }
        return pages[number - 1]
    }
    /// Persist intent BEFORE the PDF atomic write. Either the old or new PDF
    /// count resolves to the same existing identities after a process failure.
    func prepareAppend(pageCount: Int) throws {
        guard let pages = try identities(pageCount: pageCount) else { return }
        try write(Index(pages: pages, pendingAppend: PendingAppend(baseCount: pageCount, id: UUID())))
    }
    /// Called only on the staged copy inside DocumentPageRemoval's transaction.
    func remove(number: Int, originalCount: Int) throws {
        guard number > 0, number <= originalCount else { throw PageRemovalError.invalid }
        guard var pages = try identities(pageCount: originalCount) else { return }
        pages.remove(at: number - 1)
        try write(Index(pages: pages))
    }
    private func write(_ index: Index) throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try JSONEncoder().encode(index).write(to: url, options: .atomic)
    }
}
