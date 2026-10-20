import PDFKit
import SwiftUI

/// PDFKit rendering uses a separate document on a serial worker, never the live PDFView document.
final class StudioThumbnailStore: ObservableObject {
    @Published private(set) var revision = 0
    @Published private(set) var pageCount = 0
    private var data: Data?
    private let cache = NSCache<NSString, UIImage>()
    private let worker = DispatchQueue(label: "TayyaStudio.preview-thumbnails", qos: .userInitiated)
    private var workerRevision = -1
    private var workerDocument: PDFDocument?
    private var pages = [PDFPage]()
    private var incarnations = [ObjectIdentifier: UUID]()
    private var inFlight = [String: Task<UIImage?, Never>]()

    init(document: PDFDocument) {
        cache.countLimit = 80
        cache.totalCostLimit = 24 * 1024 * 1024
        data = document.dataRepresentation()
        pageCount = document.pageCount
        pages = (0..<document.pageCount).compactMap { document.page(at: $0) }
        incarnations = Dictionary(uniqueKeysWithValues: pages.map { (ObjectIdentifier($0), UUID()) })
    }
    func replaceDocument(_ document: PDFDocument, changedPages: Set<Int>? = nil) {
        let replacement = (0..<document.pageCount).compactMap { document.page(at: $0) }
        let oldIDs = pages.map(ObjectIdentifier.init)
        let newIDs = replacement.map(ObjectIdentifier.init)
        for id in newIDs where incarnations[id] == nil { incarnations[id] = UUID() }
        let changed = changedPages ?? (oldIDs == newIDs ? Set(1...max(1, document.pageCount)) : [])
        for number in changed where number > 0 && number <= replacement.count {
            let id = ObjectIdentifier(replacement[number - 1])
            if let key = incarnations[id]?.uuidString { cache.removeObject(forKey: key as NSString) }
            incarnations[id] = UUID()
        }
        let retained = Set(newIDs)
        for page in pages where !retained.contains(ObjectIdentifier(page)) {
            let id = ObjectIdentifier(page)
            if let key = incarnations[id]?.uuidString { cache.removeObject(forKey: key as NSString) }
        }
        incarnations = incarnations.filter { retained.contains($0.key) }
        pages = replacement
        data = document.dataRepresentation()
        pageCount = document.pageCount
        revision += 1
    }
    func imageKey(page: Int) -> String {
        guard page > 0, page <= pages.count else { return "missing-\(page)" }
        let id = ObjectIdentifier(pages[page - 1])
        return incarnations[id]?.uuidString ?? "missing-\(page)"
    }
    @MainActor func image(page: Int) async -> UIImage? {
        guard page >= 1, page <= pageCount, let snapshot = data else { return nil }
        let version = revision
        let key = imageKey(page: page)
        let requestedPage = pages[page - 1]
        if let cached = cache.object(forKey: key as NSString) { return cached }
        if let task = inFlight[key] { return await task.value }
        let task = Task { @MainActor () -> UIImage? in
            let rendered: UIImage? = await withCheckedContinuation { continuation in
                worker.async {
                    if self.workerRevision != version {
                        self.workerDocument = PDFDocument(data: snapshot)
                        self.workerRevision = version
                    }
                    let image = self.workerDocument?.page(at: page - 1)?.thumbnail(of: CGSize(width: 240, height: 340), for: .cropBox)
                    continuation.resume(returning: image)
                }
            }
            inFlight.removeValue(forKey: key)
            guard let index = pages.firstIndex(where: { $0 === requestedPage }), imageKey(page: index + 1) == key, let rendered else { return nil }
            cache.setObject(rendered, forKey: key as NSString, cost: (rendered.cgImage?.bytesPerRow ?? 960) * (rendered.cgImage?.height ?? 340))
            return rendered
        }
        inFlight[key] = task
        return await task.value
    }
}

struct StudioPageThumbnail: View {
    let page: Int
    var selected = false
    @ObservedObject var store: StudioThumbnailStore
    @State private var image: UIImage?
    var body: some View {
        VStack(spacing: StudioMetrics.compact) {
            ZStack {
                Color.white
                if let image {
                    Image(uiImage: image).resizable().scaledToFit()
                        .accessibilityLabel(L("معاينة الصفحة \(page)", "Preview of page \(page)"))
                        .accessibilityIdentifier("pagePreview-\(page)").accessibilityValue("rendered")
                } else {
                    ProgressView().accessibilityLabel(L("تحميل معاينة الصفحة \(page)", "Loading page \(page) preview"))
                }
            }.aspectRatio(595.0 / 842, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: StudioMetrics.compact))
                .overlay { RoundedRectangle(cornerRadius: StudioMetrics.compact).stroke(selected ? StudioTheme.primary : StudioTheme.divider, lineWidth: selected ? 2 : 0.5) }
            Text("\(page)").font(.caption.monospacedDigit()).foregroundStyle(selected ? StudioTheme.primary : StudioTheme.secondary)
        }.task(id: store.imageKey(page: page)) {
            image = nil
            let loaded = await store.image(page: page)
            if !Task.isCancelled { image = loaded }
        }
    }
}
