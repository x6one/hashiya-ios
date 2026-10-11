import SwiftUI
import PDFKit
import UIKit

/// A cover is read on a serial worker, never while SwiftUI evaluates a body.
/// The bounded memory cache changes key whenever the underlying PDF changes.
private final class LibraryThumbnailCache: @unchecked Sendable {
    static let shared = LibraryThumbnailCache()
    private let images = NSCache<NSString, UIImage>()
    private let queue = DispatchQueue(label: "tayya.library.thumbnails", qos: .utility)
    private init() {
        images.countLimit = 60
        images.totalCostLimit = 24 * 1024 * 1024
    }
    func image(for url: URL) async -> UIImage? {
        await withCheckedContinuation { continuation in
            queue.async {
                let result: UIImage? = autoreleasepool {
                    guard url.pathExtension.lowercased() == "pdf",
                          let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) else { return nil }
                    let modified = (attributes[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
                    let size = (attributes[.size] as? NSNumber)?.uint64Value ?? 0
                    let key = "\(url.path)|\(modified)|\(size)" as NSString
                    if let cached = self.images.object(forKey: key) { return cached }
                    guard let document = PDFDocument(url: url), let page = document.page(at: 0) else { return nil }
                    let cover = page.thumbnail(of: CGSize(width: 320, height: 420), for: .mediaBox)
                    let cost = cover.cgImage.map { $0.bytesPerRow * $0.height } ?? 320 * 420 * 4
                    self.images.setObject(cover, forKey: key, cost: cost)
                    return cover
                }
                continuation.resume(returning: result)
            }
        }
    }
}

struct LibraryThumbnail: View {
    let url: URL
    @State private var cover: UIImage?
    var body: some View {
        Group {
            if let cover {
                Image(uiImage: cover).resizable().scaledToFit().padding(6)
            } else {
                VStack(spacing: 5) {
                    Image(systemName: url.pathExtension.lowercased() == "pdf" ? "doc.richtext" : "doc.text")
                        .font(.system(size: 27, weight: .light))
                    Text(url.pathExtension.uppercased()).font(.caption2)
                }.foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .accessibilityHidden(true)
        .task(id: url) {
            let image = await LibraryThumbnailCache.shared.image(for: url)
            guard !Task.isCancelled else { return }
            cover = image
        }
    }
}
