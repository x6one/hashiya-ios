import PDFKit
import PencilKit
import SwiftUI

/// Native PDF/ink access is captured on the main actor one page at a time.
/// Rasterization gets an independent PDFDocument on a serial worker.
@MainActor final class DocumentThumbnailStore: ObservableObject {
    @Published private(set) var revision = 0
    @Published private(set) var pageCount: Int
    @Published private(set) var error: String?
    let cacheCountLimit = 80
    let cacheByteLimit = 24 * 1024 * 1024
    private(set) var renderCount = 0
    private let cache = NSCache<NSString, UIImage>()
    private let renderer = DocumentThumbnailRenderer()
    private let inkFolder: URL
    private var pages: [PDFPage]
    private var tokens: [ObjectIdentifier: UUID]
    private var inFlight: [String: Task<UIImage?, Never>] = [:]

    init(document: PDFDocument, inkFolder: URL) {
        self.inkFolder = inkFolder
        pageCount = document.pageCount
        pages = (0..<document.pageCount).compactMap { document.page(at: $0) }
        tokens = Dictionary(uniqueKeysWithValues: pages.map { (ObjectIdentifier($0), UUID()) })
        cache.countLimit = cacheCountLimit; cache.totalCostLimit = cacheByteLimit
    }
    func imageKey(page: Int) -> String {
        guard page > 0, page <= pages.count, let token = tokens[ObjectIdentifier(pages[page - 1])] else { return "missing-\(page)" }
        return token.uuidString
    }
    /// Text/ink edits do not enumerate or serialize the rest of the PDF.
    func invalidate(page: Int) {
        guard page > 0, page <= pages.count else { return }
        cache.removeObject(forKey: imageKey(page: page) as NSString)
        tokens[ObjectIdentifier(pages[page - 1])] = UUID()
        revision += 1
    }
    /// Structural edits retain cached content for surviving page objects.
    /// A disk reload supplies new objects and naturally invalidates their keys.
    func synchronize(_ document: PDFDocument, changedPages: Set<Int> = []) {
        let replacement = (0..<document.pageCount).compactMap { document.page(at: $0) }
        let retained = Set(replacement.map(ObjectIdentifier.init))
        for (id, token) in tokens where !retained.contains(id) { cache.removeObject(forKey: token.uuidString as NSString) }
        tokens = tokens.filter { retained.contains($0.key) }
        for page in replacement where tokens[ObjectIdentifier(page)] == nil { tokens[ObjectIdentifier(page)] = UUID() }
        pages = replacement; pageCount = pages.count
        for page in changedPages { invalidate(page: page) }
        revision += 1
    }
    func image(page: Int) async -> UIImage? {
        guard page > 0, page <= pages.count else { return nil }
        let key = imageKey(page: page)
        if let image = cache.object(forKey: key as NSString) {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--test-production-content") { NSLog("TayyaThumbnail store=cache page=%d key=%@", page, key) }
            #endif
            return image
        }
        if let task = inFlight[key] {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--test-production-content") { NSLog("TayyaThumbnail store=join page=%d key=%@", page, key) }
            #endif
            return await task.value
        }
        let requested = pages[page - 1]
        // Copying into a new document must never remove a live PDFView page.
        guard let copy = requested.copy() as? PDFPage else { error = TayyaLocalized("تعذّر تحميل معاينة الصفحة."); return nil }
        let snapshot = PDFDocument(); snapshot.insert(copy, at: 0)
        guard let data = snapshot.dataRepresentation() else { error = TayyaLocalized("تعذّر تحميل معاينة الصفحة."); return nil }
        let inkURL = inkFolder.appendingPathComponent("\(page - 1).drawing")
        let task = Task { @MainActor () -> UIImage? in
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--test-production-content") { NSLog("TayyaThumbnail store=renderBegin page=%d key=%@", page, key) }
            #endif
            let result = await renderer.image(pdf: data, ink: inkURL)
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--test-production-content") { NSLog("TayyaThumbnail store=renderEnd page=%d key=%@ image=%d error=%d", page, key, result.image != nil, result.error != nil) }
            #endif
            inFlight.removeValue(forKey: key)
            guard let index = pages.firstIndex(where: { $0 === requested }), imageKey(page: index + 1) == key else { return nil }
            renderCount += 1
            if let message = result.error { error = message; return nil }
            guard let image = result.image else { return nil }
            let bytes = image.cgImage.map { $0.bytesPerRow * $0.height } ?? 240 * 340 * 4
            cache.setObject(image, forKey: key as NSString, cost: bytes)
            return image
        }
        inFlight[key] = task
        return await task.value
    }
}

private final class DocumentThumbnailRenderer: @unchecked Sendable {
    struct Result { var image: UIImage?; var error: String? }
    private let worker = DispatchQueue(label: "tayya.document.thumbnails", qos: .userInitiated)
    func image(pdf: Data, ink: URL) async -> Result {
        await withCheckedContinuation { continuation in
            worker.async {
                let result: Result = autoreleasepool {
                    do {
                        guard let page = PDFDocument(data: pdf)?.page(at: 0) else { throw CocoaError(.fileReadCorruptFile) }
                        let base = page.thumbnail(of: CGSize(width: 240, height: 340), for: .mediaBox)
                        guard FileManager.default.fileExists(atPath: ink.path) else { return Result(image: base) }
                        let drawing = try PKDrawing(data: Data(contentsOf: ink))
                        if drawing.strokes.isEmpty { return Result(image: base) }
                        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
                        let image = UIGraphicsImageRenderer(size: base.size, format: format).image { context in
                            UIColor.white.setFill(); context.fill(CGRect(origin: .zero, size: base.size))
                            base.draw(at: .zero)
                            let extent = CGRect(origin: .zero, size: page.bounds(for: .mediaBox).size)
                            drawing.image(from: extent, scale: 1).draw(in: CGRect(origin: .zero, size: base.size))
                        }
                        return Result(image: image)
                    } catch { return Result(error: error.localizedDescription) }
                }
                continuation.resume(returning: result)
            }
        }
    }
}

struct DocumentPageThumbnail: View {
    let number: Int
    var selected = false
    @ObservedObject var store: DocumentThumbnailStore
    @State private var image: UIImage?
    @State private var failed = false
    var body: some View {
        VStack(spacing: TayyaMetrics.compact) {
            ZStack {
                Color.white
                if let image {
                    Image(uiImage: image).resizable().scaledToFit()
                        .accessibilityLabel(String(format: TayyaLocalized("معاينة الصفحة %d"), number))
                        .accessibilityIdentifier("pagePreview-\(number)").accessibilityValue("rendered")
                } else if failed {
                    Image(systemName: "exclamationmark.triangle").foregroundStyle(TayyaTheme.destructive)
                        .accessibilityLabel(TayyaLocalized("تعذّر تحميل معاينة الصفحة."))
                } else { ProgressView() }
            }.aspectRatio(image.map { $0.size.width / max(1, $0.size.height) } ?? 0.71, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: TayyaMetrics.compact))
                .overlay {
                    RoundedRectangle(cornerRadius: TayyaMetrics.compact)
                        .strokeBorder(selected ? TayyaTheme.ink : TayyaTheme.separator, lineWidth: selected ? 2 : 0.5)
                }
            Text("\(number)").font(.caption.monospacedDigit())
                .foregroundStyle(selected ? TayyaTheme.ink : TayyaTheme.detail)
        }.task(id: store.imageKey(page: number)) {
            #if DEBUG
            let started = ProcessInfo.processInfo.systemUptime
            if ProcessInfo.processInfo.arguments.contains("--test-production-content") { NSLog("TayyaThumbnail view=begin page=%d time=%.6f cancelled=%d", number, started, Task.isCancelled) }
            #endif
            image = nil; failed = false
            let loaded = await store.image(page: number)
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--test-production-content") { NSLog("TayyaThumbnail view=end page=%d time=%.6f cancelled=%d image=%d", number, started, Task.isCancelled, loaded != nil) }
            #endif
            guard !Task.isCancelled else { return }
            image = loaded; failed = loaded == nil
        }
    }
}

struct DocumentPageSidebar: View {
    @ObservedObject var workspace: PDFWorkspace
    @ObservedObject var thumbnails: DocumentThumbnailStore
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: TayyaMetrics.spacing) {
                    ForEach(1...max(1, thumbnails.pageCount), id: \.self) { number in
                        Button { workspace.jump(number) } label: {
                            DocumentPageThumbnail(number: number, selected: workspace.page == number, store: thumbnails)
                        }.buttonStyle(.plain).id(number)
                            .accessibilityLabel(String(format: TayyaLocalized("صفحة %d"), number))
                            .accessibilityIdentifier("sidebarPage-\(number)")
                    }
                }.padding(TayyaMetrics.compact)
            }.background(TayyaTheme.mutedSurface)
                .onChange(of: workspace.page) { _, page in proxy.scrollTo(page, anchor: .center) }
        }.accessibilityIdentifier("documentPageSidebar")
    }
}
