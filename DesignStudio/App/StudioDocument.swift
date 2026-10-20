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
        return PDFDocument(data: data) ?? PDFDocument()
    }

    private static func draw(_ text: String, x: CGFloat, y: CGFloat, width: CGFloat, size: CGFloat, color: Int = 0x282C2B, bold: Bool = false) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = L("ar", "en") == "ar" ? .right : .left
        paragraph.baseWritingDirection = L("ar", "en") == "ar" ? .rightToLeft : .leftToRight
        paragraph.lineSpacing = 9
        (text as NSString).draw(in: CGRect(x: x, y: y, width: width, height: 110), withAttributes: [
            .font: UIFont.systemFont(ofSize: size, weight: bold ? .semibold : .regular),
            .foregroundColor: StudioTheme.ui(color), .paragraphStyle: paragraph
        ])
    }
}

struct StudioPDFView: UIViewRepresentable {
    let page: Int
    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.document = StudioPDF.make()
        view.autoScales = true
        view.displayMode = .singlePage
        view.displayDirection = .vertical
        view.backgroundColor = .clear
        view.pageShadowsEnabled = false
        view.accessibilityIdentifier = "nativeStudyPDF"
        return view
    }
    func updateUIView(_ view: PDFView, context: Context) {
        guard let document = view.document, let target = document.page(at: page - 1), view.currentPage !== target else { return }
        view.go(to: target)
    }
}

final class StudioCanvas: ObservableObject {
    let view = PKCanvasView()
    init(margin: Bool = false) {
        view.backgroundColor = .clear
        view.isOpaque = false
        view.drawingPolicy = .anyInput
        view.tool = PKInkingTool(.pen, color: StudioTheme.ui(0x244C43), width: 3)
        if margin {
            let points = (0...28).map { index in
                PKStrokePoint(location: CGPoint(x: 28 + Double(index) * 8, y: 65 + sin(Double(index) / 5) * 9), timeOffset: Double(index) / 20, size: CGSize(width: 2.5, height: 2.5), opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
            }
            view.drawing = PKDrawing(strokes: [PKStroke(ink: PKInk(.pen, color: StudioTheme.ui(0x416B5D)), path: PKStrokePath(controlPoints: points, creationDate: Date(timeIntervalSince1970: 0)))])
        }
    }
    func configure(tool: String, color: Int, width: CGFloat) {
        if tool == "eraser" { view.tool = PKEraserTool(.vector) }
        else { view.tool = PKInkingTool(tool == "pencil" ? .pencil : tool == "highlighter" ? .marker : .pen, color: StudioTheme.ui(color), width: width) }
    }
}

struct StudioInkView: UIViewRepresentable {
    let canvas: StudioCanvas
    var editable = true
    func makeUIView(context: Context) -> PKCanvasView { canvas.view }
    func updateUIView(_ view: PKCanvasView, context: Context) { view.isUserInteractionEnabled = editable }
}
