import SwiftUI
import PDFKit

enum PaperColor: String, CaseIterable, Identifiable {
    case cream = "كريمي", white = "أبيض", mint = "أخضر هادئ"
    var id: String { rawValue }
    var uiColor: UIColor {
        switch self {
        case .cream: return UIColor(red: 1, green: 0.995, blue: 0.96, alpha: 1)
        case .white: return .white
        case .mint: return UIColor(red: 0.93, green: 0.98, blue: 0.94, alpha: 1)
        }
    }
}
enum PaperTemplate: String, CaseIterable, Identifiable {
    case ruled = "مسطّر", grid = "مربعات", dots = "نقاط", lecture = "ملخص محاضرة", weekly = "خطة أسبوعية"
    var id: String { rawValue }
    func render(color: PaperColor) -> Data {
        let bounds = CGRect(x: 0, y: 0, width: 650, height: 900)
        return UIGraphicsPDFRenderer(bounds: bounds).pdfData { context in
            context.beginPage()
            color.uiColor.setFill(); context.cgContext.fill(bounds)
            let cg = context.cgContext
            UIColor.systemGray3.setStroke(); UIColor.systemGray3.setFill(); cg.setLineWidth(0.5)
            func line(_ a: CGPoint, _ b: CGPoint) { cg.move(to: a); cg.addLine(to: b); cg.strokePath() }
            func label(_ text: String, _ rect: CGRect) {
                let style = NSMutableParagraphStyle(); style.alignment = .right
                (text as NSString).draw(in: rect, withAttributes: [.font: UIFont.systemFont(ofSize: 18), .foregroundColor: UIColor.darkGray, .paragraphStyle: style])
            }
            switch self {
            case .ruled, .grid:
                for y in stride(from: 70, through: 850, by: 30) { line(CGPoint(x: 40, y: CGFloat(y)), CGPoint(x: 610, y: CGFloat(y))) }
                if self == .grid { for x in stride(from: 40, through: 610, by: 30) { line(CGPoint(x: CGFloat(x), y: 70), CGPoint(x: CGFloat(x), y: 850)) } }
            case .dots:
                for y in stride(from: 70, through: 850, by: 25) { for x in stride(from: 40, through: 610, by: 25) { cg.fillEllipse(in: CGRect(x: CGFloat(x), y: CGFloat(y), width: 2, height: 2)) } }
            case .lecture:
                label("عنوان المحاضرة:                       التاريخ:", CGRect(x: 40, y: 30, width: 570, height: 40))
                cg.stroke(CGRect(x: 40, y: 90, width: 570, height: 590)); line(CGPoint(x: 450, y: 90), CGPoint(x: 450, y: 680))
                label("الأفكار الرئيسة", CGRect(x: 460, y: 100, width: 140, height: 30))
                label("الملاحظات والتفاصيل", CGRect(x: 60, y: 100, width: 370, height: 30))
                cg.stroke(CGRect(x: 40, y: 710, width: 570, height: 140)); label("الخلاصة والأسئلة", CGRect(x: 60, y: 720, width: 530, height: 30))
            case .weekly:
                label("خطة الأسبوع:                         الهدف:", CGRect(x: 40, y: 30, width: 570, height: 40))
                for (index, day) in ["السبت", "الأحد", "الاثنين", "الثلاثاء", "الأربعاء", "الخميس", "الجمعة"].enumerated() {
                    let y = 90 + index * 108
                    cg.stroke(CGRect(x: 40, y: CGFloat(y), width: 570, height: 100)); label(day, CGRect(x: 450, y: CGFloat(y + 8), width: 140, height: 28))
                }
            }
        }
    }
}
struct CreateNotebookScreen: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: LibraryStore
    let section: String?
    @State private var title = "دفتر جديد"
    @State private var template: PaperTemplate = .ruled
    @State private var color: PaperColor = .cream
    var body: some View {
        NavigationStack {
            Form {
                TextField("الاسم", text: $title)
                Picker("قالب الورق", selection: $template) { ForEach(PaperTemplate.allCases) { Text($0.rawValue).tag($0) } }
                Picker("لون الورق", selection: $color) { ForEach(PaperColor.allCases) { Text($0.rawValue).tag($0) } }
            }.navigationTitle("دفتر جديد").toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("إلغاء") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("إنشاء") {
                    store.create(title.trimmingCharacters(in: .whitespacesAndNewlines), section: section, template: template, color: color)
                    if store.error == nil { dismiss() }
                }.disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
            }
        }.environment(\.layoutDirection, .rightToLeft)
    }
}
