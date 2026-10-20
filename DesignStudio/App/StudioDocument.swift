import PDFKit
import PencilKit
import SwiftUI

enum StudioPDF {
    static func make() -> PDFDocument {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842))
        let data = renderer.pdfData { context in
            for page in 1...24 {
                context.beginPage()
                UIColor.white.setFill()
                context.cgContext.fill(CGRect(x: 0, y: 0, width: 595, height: 842))
                if (2...5).contains(page) {
                    drawReviewPage(page, context: context.cgContext)
                    continue
                }
                draw(L("مساحة المعرفة · المحاسبة المالية", "STUDY NOTES · FINANCIAL ACCOUNTING"), x: 48, y: 40, width: 499, size: 10, color: 0x69756B)
                draw(L("مبادئ المحاسبة", "Accounting principles"), x: 48, y: 88, width: 499, size: 27, bold: true)
                draw(L("الفصل الثالث · فهم المعادلة المحاسبية", "CHAPTER THREE · THE ACCOUNTING EQUATION"), x: 48, y: 137, width: 499, size: 12, color: 0x69756B)
                draw(L("تساعدنا المحاسبة على فهم الموارد المتاحة وكيفية استخدامها. تبدأ قراءة القوائم المالية من العلاقة بين الأصول والالتزامات وحقوق الملكية.", "Accounting helps us understand available resources and how they are used. Reading financial statements begins with the relationship between assets, liabilities and equity."), x: 48, y: 189, width: 499, size: 17)
                StudioTheme.ui(0xE9EFEA).setFill()
                UIBezierPath(roundedRect: CGRect(x: 48, y: 290, width: 499, height: 64), cornerRadius: 8).fill()
                draw(L("الأصول = الالتزامات + حقوق الملكية", "Assets = Liabilities + Equity"), x: 60, y: 308, width: 475, size: 19, bold: true)
                draw(L("من الفكرة إلى التطبيق", "From principle to practice"), x: 48, y: 388, width: 499, size: 20, bold: true)
                draw(L("عند شراء أصل جديد، نسجّل أثره على طرفي المعادلة. إذا زادت الموارد بمبلغ معين، يجب أن يظهر مصدر هذا التمويل بوضوح في السجلات.", "When a new asset is acquired, we record its effect on both sides of the equation. An increase in resources must have a corresponding source of funding in the records."), x: 48, y: 429, width: 499, size: 17)
                draw(L("مثال توضيحي لتوزيع الموارد", "An illustration of resource allocation"), x: 48, y: 535, width: 499, size: 13, color: 0x69756B)
                for index in 0..<5 {
                    let height = CGFloat([63, 96, 81, 132, 153][index])
                    StudioTheme.ui(index == 4 ? 0xC48F68 : 0x416B5D).setFill()
                    UIBezierPath(roundedRect: CGRect(x: 104 + CGFloat(index) * 81, y: 736 - height, width: 43, height: height), cornerRadius: 3).fill()
                }
                draw(L("طَيّة · ملاحظات للدراسة", "TAYYA · STUDY NOTES"), x: 48, y: 790, width: 360, size: 10, color: 0x69756B)
                draw("\(page)", x: 485, y: 790, width: 60, size: 10, color: 0x69756B)
            }
        }
        let document = PDFDocument(data: data) ?? PDFDocument()
        if let page = document.page(at: 3) {
            let annotation = PDFAnnotation(bounds: CGRect(x: 48, y: 270, width: 499, height: 240), forType: .ink, withProperties: nil)
            annotation.color = StudioTheme.ui(0x244C43)
            annotation.border = PDFBorder()
            annotation.border?.lineWidth = 4
            let path = UIBezierPath()
            path.move(to: CGPoint(x: 30, y: 80))
            path.addCurve(to: CGPoint(x: 440, y: 140), controlPoint1: CGPoint(x: 160, y: 240), controlPoint2: CGPoint(x: 280, y: 10))
            annotation.add(path)
            page.addAnnotation(annotation)
        }
        return document
    }

    private static func drawReviewPage(_ page: Int, context: CGContext) {
        if page == 2 {
            draw(L("ميزان المراجعة", "Trial balance"), x: 48, y: 60, width: 499, size: 27, bold: true)
            let rows = [L("الحساب         مدين         دائن", "Account             Debit             Credit"),
                        L("النقدية         ١٢٠٠٠         —", "Cash                 12,000               —"),
                        L("المعدات         ٨٠٠٠         —", "Equipment        8,000               —"),
                        L("رأس المال         —         ٢٠٠٠٠", "Capital                   —           20,000")]
            for (index, row) in rows.enumerated() {
                let y = CGFloat(160 + index * 82)
                StudioTheme.ui(index == 0 ? 0xE9EFEA : 0xF8F7F3).setFill()
                context.fill(CGRect(x: 48, y: y, width: 499, height: 80))
                draw(row, x: 60, y: y + 20, width: 475, size: 18, bold: index == 0)
                StudioTheme.ui(0xC48F68).setStroke()
                context.stroke(CGRect(x: 48, y: y, width: 499, height: 80))
            }
        } else if page == 3 {
            draw(L("صورة توضيحية", "Illustration"), x: 48, y: 60, width: 499, size: 27, bold: true)
            // An actual embedded raster image, not a thumbnail placeholder.
            let illustration = UIGraphicsImageRenderer(size: CGSize(width: 480, height: 340)).image { image in
                StudioTheme.ui(0xE9EFEA).setFill(); image.fill(CGRect(x: 0, y: 0, width: 480, height: 340))
                StudioTheme.ui(0xC48F68).setFill(); UIBezierPath(ovalIn: CGRect(x: 320, y: 30, width: 88, height: 88)).fill()
                StudioTheme.ui(0x416B5D).setFill()
                let mountain = UIBezierPath()
                mountain.move(to: CGPoint(x: 0, y: 340)); mountain.addLine(to: CGPoint(x: 150, y: 80))
                mountain.addLine(to: CGPoint(x: 300, y: 250)); mountain.addLine(to: CGPoint(x: 390, y: 140))
                mountain.addLine(to: CGPoint(x: 480, y: 340)); mountain.close(); mountain.fill()
            }
            illustration.draw(in: CGRect(x: 48, y: 180, width: 499, height: 354))
        } else if page == 4 {
            draw(L("مراجعة بالقلم", "Handwritten review"), x: 48, y: 60, width: 499, size: 27, bold: true)
            draw(L("تعليق حبر أصلي داخل PDF", "A native PDF ink annotation"), x: 48, y: 130, width: 499, size: 18)
        }
        draw("\(page)", x: 485, y: 790, width: 60, size: 10, color: 0x69756B)
    }

    private static func draw(_ text: String, x: CGFloat, y: CGFloat, width: CGFloat, size: CGFloat, color: Int = 0x282C2B, bold: Bool = false) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = L("ar", "en") == "ar" ? .right : .left
        paragraph.baseWritingDirection = L("ar", "en") == "ar" ? .rightToLeft : .leftToRight
        paragraph.lineSpacing = 9
        (text as NSString).draw(in: CGRect(x: x, y: y, width: width, height: 110), withAttributes: [
            // The system Arabic variable face separates dots into glyphs in
            // generated PDF text maps. The stable guide uses these public
            // document faces, which retain complete Arabic letter mappings.
            .font: UIFont(name: bold ? "Arial-BoldMT" : "ArialMT", size: size)
                ?? UIFont.systemFont(ofSize: size, weight: bold ? .semibold : .regular),
            .foregroundColor: StudioTheme.ui(color), .paragraphStyle: paragraph
        ])
    }
}

final class StudioPDFController: ObservableObject {
    var onPageChange: ((Int) -> Void)?
    private var pageObserver: NSObjectProtocol?
    lazy var thumbnails = StudioThumbnailStore(document: view.document ?? PDFDocument())
    func contentChanged(page: Int? = nil) {
        if let document = view.document { thumbnails.replaceDocument(document, changedPages: page.map { Set([$0]) }) }
    }
    func text(on number: Int) -> String {
        view.document?.page(at: number - 1)?.annotations.first { $0.type == "FreeText" }?.contents ?? ""
    }
    func textStyle(on number: Int) -> StudioTextStyle {
        var style = StudioTextStyle()
        guard let annotation = view.document?.page(at: number - 1)?.annotations.first(where: { $0.type == "FreeText" }) else { return style }
        style.size = Double(annotation.font?.pointSize ?? 18)
        style.alignment = annotation.alignment == .center ? 1 : annotation.alignment == .left ? 2 : 0
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        if annotation.fontColor?.getRed(&red, green: &green, blue: &blue, alpha: &alpha) == true {
            style.color = Int((red * 255).rounded()) << 16 | Int((green * 255).rounded()) << 8 | Int((blue * 255).rounded())
        }
        return style
    }
    func updateText(_ text: String, size: Double, color: Int, alignment: Int, page number: Int) {
        guard let page = view.document?.page(at: number - 1), !text.isEmpty else { return }
        let annotation = page.annotations.first { $0.type == "FreeText" }
            ?? PDFAnnotation(bounds: CGRect(x: 60, y: 480, width: 460, height: 110), forType: .freeText, withProperties: nil)
        annotation.contents = text
        annotation.font = UIFont.systemFont(ofSize: size)
        annotation.fontColor = StudioTheme.ui(color)
        annotation.color = .clear
        annotation.alignment = alignment == 1 ? .center : alignment == 2 ? .left : .right
        if !page.annotations.contains(where: { $0 === annotation }) { page.addAnnotation(annotation) }
        contentChanged(page: number)
    }
    lazy var view: PDFView = {
        let view = StudioReadingPDFView()
        view.document = StudioPDF.make()
        view.autoScales = true
        view.displayMode = .singlePage
        view.displayDirection = .vertical
        view.backgroundColor = .clear
        view.pageShadowsEnabled = false
        view.accessibilityIdentifier = "nativeStudyPDF"
        pageObserver = NotificationCenter.default.addObserver(forName: .PDFViewPageChanged, object: view, queue: .main) { [weak self, weak view] _ in
            guard let view, let document = view.document, let page = view.currentPage else { return }
            self?.onPageChange?(document.index(for: page) + 1)
        }
        return view
    }()
    deinit { if let pageObserver { NotificationCenter.default.removeObserver(pageObserver) } }
}

/// Preserve the reading destination and scale as chrome or Notes changes the viewport.
final class StudioReadingPDFView: PDFView {
    private var previousSize = CGSize.zero
    private var pending: (page: PDFPage, point: CGPoint, scale: CGFloat)?
    private var restoring = false
    private var readingPoint: CGPoint { CGPoint(x: bounds.midX, y: bounds.minY + 1) }
    private var scroll: UIScrollView? {
        var ancestor = documentView?.superview
        while let view = ancestor, !(view is UIScrollView), view !== self { ancestor = view.superview }
        return ancestor as? UIScrollView
    }
    // Capture-before-resize / scroll-displacement mechanism from the proven
    // production ResizingPDFView; never navigate to a page during layout.
    override var frame: CGRect { willSet { if newValue.size != frame.size { capture() } } }
    override var bounds: CGRect { willSet { if newValue.size != bounds.size { capture() } } }
    private func capture() {
        guard !restoring, pending == nil, bounds.width > 0, bounds.height > 0,
              let page = page(for: readingPoint, nearest: true) else { return }
        pending = (page, convert(readingPoint, to: page), scaleFactor)
    }
    func navigate(to page: PDFPage) { pending = nil; go(to: page) }
    override func layoutSubviews() {
        guard !restoring else { super.layoutSubviews(); return }
        let resized = previousSize != bounds.size
        previousSize = bounds.size
        let anchor = pending
        pending = nil
        restoring = true
        defer { restoring = false }
        super.layoutSubviews()
        guard resized, bounds.width > 0, bounds.height > 0, let anchor, anchor.scale > 0,
              let document, document.index(for: anchor.page) < document.pageCount else { return }
        autoScales = false
        scaleFactor = anchor.scale
        layoutDocumentView()
        guard let scroll else { return }
        let moved = convert(anchor.point, from: anchor.page)
        let proposed = CGPoint(x: scroll.contentOffset.x + moved.x - readingPoint.x,
                               y: scroll.contentOffset.y + moved.y - readingPoint.y)
        let inset = scroll.adjustedContentInset
        let minX = -inset.left, minY = -inset.top
        let maxX = max(minX, scroll.contentSize.width - scroll.bounds.width + inset.right)
        let maxY = max(minY, scroll.contentSize.height - scroll.bounds.height + inset.bottom)
        scroll.setContentOffset(CGPoint(x: min(maxX, max(minX, proposed.x)), y: min(maxY, max(minY, proposed.y))), animated: false)
    }
}

struct StudioPDFView: UIViewRepresentable {
    let page: Int
    let controller: StudioPDFController
    func makeUIView(context: Context) -> PDFView { controller.view }
    func updateUIView(_ view: PDFView, context: Context) {
        guard let document = view.document, let target = document.page(at: page - 1), view.currentPage !== target else { return }
        if let reading = view as? StudioReadingPDFView { reading.navigate(to: target) }
        else { view.go(to: target) }
    }
}

final class StudioCanvas: NSObject, ObservableObject, PKCanvasViewDelegate {
    let view = PKCanvasView()
    var onActivate: (() -> Void)?
    var onStroke: (() -> Void)?
    var onDrawingChange: (() -> Void)?
    private(set) var brush = "pen"
    private(set) var color = 0x244C43
    private(set) var width: CGFloat = 3
    private var previousCount = 0
    init(margin: Bool = false) {
        super.init()
        view.backgroundColor = .clear
        view.isOpaque = false
        view.drawingPolicy = .anyInput
        view.tool = PKInkingTool(.pen, color: StudioTheme.ui(0x244C43), width: 3)
        view.accessibilityIdentifier = margin ? "marginCanvas" : "documentCanvas"
        view.isAccessibilityElement = true
        view.accessibilityLabel = margin ? L("سطح رسم الملاحظات", "Notes drawing canvas") : L("سطح رسم المستند", "Document drawing canvas")
        if margin {
            let points = (0...28).map { index in
                PKStrokePoint(location: CGPoint(x: 28 + Double(index) * 8, y: 65 + sin(Double(index) / 5) * 9), timeOffset: Double(index) / 20, size: CGSize(width: 2.5, height: 2.5), opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
            }
            view.drawing = PKDrawing(strokes: [PKStroke(ink: PKInk(.pen, color: StudioTheme.ui(0x416B5D)), path: PKStrokePath(controlPoints: points, creationDate: Date(timeIntervalSince1970: 0)))])
        }
        previousCount = view.drawing.strokes.count
        view.accessibilityValue = String(previousCount)
        view.delegate = self
    }
    func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) { NSLog("%@", "StudioCanvas begin \(view.accessibilityIdentifier ?? "unknown") count=\(view.drawing.strokes.count)"); onActivate?() }
    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        let count = canvasView.drawing.strokes.count
        NSLog("%@", "StudioCanvas changed \(view.accessibilityIdentifier ?? "unknown") previous=\(previousCount) count=\(count) callback=\(onStroke != nil)")
        if count > previousCount { onStroke?() }
        previousCount = count
        onDrawingChange?()
        view.accessibilityValue = String(count)
    }
    func configure(tool: String, color: Int, width: CGFloat) {
        brush = tool; self.color = color; self.width = width
        if tool == "eraser" { view.tool = PKEraserTool(.vector) }
        else { view.tool = PKInkingTool(tool == "pencil" ? .pencil : tool == "highlighter" ? .marker : .pen, color: StudioTheme.ui(color), width: width) }
    }
}

struct StudioInkView: UIViewRepresentable {
    let canvas: StudioCanvas
    var editable = true
    func makeUIView(context: Context) -> PKCanvasView { canvas.view }
    func updateUIView(_ view: PKCanvasView, context: Context) { if view.isUserInteractionEnabled != editable { view.isUserInteractionEnabled = editable } }
}
