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

    init(document: PDFDocument) {
        cache.countLimit = 80
        cache.totalCostLimit = 24 * 1024 * 1024
        data = document.dataRepresentation()
        pageCount = document.pageCount
    }
    func replaceDocument(_ document: PDFDocument) {
        data = document.dataRepresentation()
        pageCount = document.pageCount
        cache.removeAllObjects()
        revision += 1
    }
    @MainActor func image(page: Int) async -> UIImage? {
        guard page >= 1, page <= pageCount, let snapshot = data else { return nil }
        let version = revision
        let key = "\(version)-\(page)" as NSString
        if let cached = cache.object(forKey: key) { return cached }
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
        guard version == revision, let rendered else { return nil }
        cache.setObject(rendered, forKey: key, cost: (rendered.cgImage?.bytesPerRow ?? 960) * (rendered.cgImage?.height ?? 340))
        return rendered
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
        }.task(id: "\(store.revision)-\(page)") {
            image = nil
            let loaded = await store.image(page: page)
            if !Task.isCancelled { image = loaded }
        }
    }
}
