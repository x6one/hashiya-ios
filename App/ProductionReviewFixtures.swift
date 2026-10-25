#if DEBUG
import SwiftUI
import PDFKit
import PencilKit

/// Real files in an isolated review root, used only by production UI tests.
/// No recording fixture or Studio simulation is installed here.
enum ProductionReviewFixtures {
    static let title = "Tayya Study"
    @MainActor static func install(in library: LibraryStore) throws {
        _ = try library.installDemonstration()
        let source = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".pdf")
        defer { try? FileManager.default.removeItem(at: source) }
        try mixedPDF().write(to: source)
        try library.importPDF(source, title: title)
        guard let note = library.notebooks.first(where: { $0.title == title }) else { throw CocoaError(.fileReadCorruptFile) }
        library.change(note.id) { $0.favorite = true }
        let workspace = PDFWorkspace(note: note, root: library.root)
        try ink().dataRepresentation().write(to: workspace.storage.appendingPathComponent("3.drawing"))
        let notes = MarginPages(root: library.root, notebook: note.id)
        guard let first = notes.currentID else { throw CocoaError(.fileReadCorruptFile) }
        notes.editTitle("ملاحظات الدراسة", page: first)
        notes.editText("مراجعة المحاضرة\n\n• ميّز بين الأصول والالتزامات.\n• اكتب مثالًا لكل مفهوم.\n• راجع توازن المعادلة المحاسبية.\n\nالأصول = الالتزامات + حقوق الملكية\n\nسؤال للمراجعة\nكيف يؤثر شراء أصل نقدًا على إجمالي الأصول؟", page: first)
        notes.linkCurrent(to: 2)
        notes.saveInk(ink(), page: first)
        guard notes.add(linkedTo: 4), let second = notes.currentID else { throw CocoaError(.fileWriteUnknown) }
        notes.editTitle("متابعة الدراسة", page: second)
        notes.editText("تطبيق ما تعلّمته\n\nاكتب خطوات الحل، ثم قارن النتيجة بالمثال في الصفحة الرابعة.\n\nضع علامة عند الفكرة التي تريد مراجعتها لاحقًا.", page: second)
        guard notes.select(first), notes.saved, notes.error == nil else { throw CocoaError(.fileWriteUnknown) }
    }
    private static func mixedPDF() -> Data {
        let bounds = CGRect(x: 0, y: 0, width: 650, height: 900)
        return UIGraphicsPDFRenderer(bounds: bounds).pdfData { context in
            for number in 1...5 {
                context.beginPage(); UIColor.white.setFill(); context.cgContext.fill(bounds)
                if number < 5 {
                    let titles = ["مبادئ المحاسبة", "جدول الدراسة", "ملخص بصري", "مساحة التطبيق"]
                    let paragraph = NSMutableParagraphStyle(); paragraph.alignment = .right
                    (titles[number - 1] as NSString).draw(in: CGRect(x: 40, y: 45, width: 570, height: 60),
                        withAttributes: [.font: UIFont.boldSystemFont(ofSize: 30), .foregroundColor: UIColor(TayyaTheme.brandInk), .paragraphStyle: paragraph])
                }
                if number == 1 {
                    let text = "الفصل الأول • الأساسيات\n\nالمحاسبة لغة لتنظيم المعلومات المالية وفهمها. نبدأ بثلاثة مفاهيم: الأصول، والالتزامات، وحقوق الملكية.\n\nالأصول موارد تملكها المنشأة. والالتزامات مبالغ مستحقة عليها. أما حقوق الملكية فتمثل الفرق بينهما.\n\nالمعادلة الأساسية\nالأصول = الالتزامات + حقوق الملكية\n\nفكّر وطبّق\nاكتب مثالًا على أصل، ثم وضّح كيف يختلف عن المصروف. دوّن أسئلتك قبل الانتقال إلى الصفحة التالية."
                    let paragraph = NSMutableParagraphStyle(); paragraph.alignment = .right; paragraph.lineSpacing = 12
                    (text as NSString).draw(in: CGRect(x: 45, y: 140, width: 560, height: 640),
                        withAttributes: [.font: UIFont.systemFont(ofSize: 23), .foregroundColor: UIColor.darkGray, .paragraphStyle: paragraph])
                } else if number == 2 {
                    let path = UIBezierPath()
                    for row in 0...7 { path.move(to: CGPoint(x: 45, y: 150 + row * 60)); path.addLine(to: CGPoint(x: 605, y: 150 + row * 60)) }
                    for column in 0...4 { path.move(to: CGPoint(x: 45 + column * 140, y: 150)); path.addLine(to: CGPoint(x: 45 + column * 140, y: 570)) }
                    UIColor(TayyaTheme.brandInk).setStroke(); path.lineWidth = 2; path.stroke()
                    for row in 0..<7 { for column in 0..<4 {
                        ("\((row + 1) * (column + 1) * 125)" as NSString).draw(at: CGPoint(x: 65 + column * 140, y: 170 + row * 60),
                            withAttributes: [.font: UIFont.monospacedDigitSystemFont(ofSize: 20, weight: .regular)])
                    } }
                } else if number == 3 {
                    let picture = UIGraphicsImageRenderer(size: CGSize(width: 500, height: 420)).image { image in
                        UIColor(red: 0.91, green: 0.94, blue: 0.92, alpha: 1).setFill(); image.fill(CGRect(x: 0, y: 0, width: 500, height: 420))
                        UIColor(red: 0.77, green: 0.56, blue: 0.41, alpha: 1).setFill()
                        UIBezierPath(ovalIn: CGRect(x: 260, y: 50, width: 150, height: 150)).fill()
                        UIColor(TayyaTheme.brandInk).setFill()
                        let mountain = UIBezierPath(); mountain.move(to: CGPoint(x: 25, y: 380)); mountain.addLine(to: CGPoint(x: 205, y: 100)); mountain.addLine(to: CGPoint(x: 470, y: 380)); mountain.close(); mountain.fill()
                    }
                    picture.draw(in: CGRect(x: 55, y: 180, width: 540, height: 450))
                }
            }
        }
    }
    private static func ink() -> PKDrawing {
        let points = [CGPoint(x: 80, y: 150), CGPoint(x: 200, y: 220), CGPoint(x: 350, y: 140), CGPoint(x: 520, y: 230)]
            .enumerated().map { index, point in
                PKStrokePoint(location: point, timeOffset: Double(index) / 5, size: CGSize(width: 5, height: 5), opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
            }
        return PKDrawing(strokes: [PKStroke(ink: PKInk(.pen, color: UIColor(TayyaTheme.brandInk)), path: PKStrokePath(controlPoints: points, creationDate: Date(timeIntervalSince1970: 1_700_000_000)))])
    }
}
#endif
