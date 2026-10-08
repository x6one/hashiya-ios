import SwiftUI
import PDFKit
import PencilKit

/// An explicit, local demonstration available in Release as well as Debug.
/// Installation publishes the library only after every sample is ready.
extension LibraryStore {
    @discardableResult func installDemonstration() throws -> Notebook {
        let manifestURL = root.appendingPathComponent("demonstration.json")
        let previous: [UUID]
        if FileManager.default.fileExists(atPath: manifestURL.path) {
            previous = try JSONDecoder().decode([UUID].self, from: Data(contentsOf: manifestURL))
        } else { previous = [] }
        let existing = previous.compactMap { id in notebooks.first { $0.id == id && !$0.trashed } }
        if existing.count == 3, let guide = existing.first { return guide }

        guard let office = Bundle.main.url(forResource: "office-demo", withExtension: "pptx") else {
            throw CocoaError(.fileNoSuchFile)
        }
        let guide = Notebook(title: "ابدأ هنا — دليل طَيّة", file: UUID().uuidString + ".pdf", section: "مكتبتي")
        let writing = Notebook(title: "دفتر التجربة — اكتب بحرية", file: UUID().uuidString + ".pdf", section: "مكتبتي")
        let presentation = Notebook(title: "عرض تقديمي للتجربة", file: UUID().uuidString + ".pptx", section: "مكتبتي")
        let samples = [guide, writing, presentation]
        var created: [URL] = []
        do {
            for note in samples {
                let destination = root.appendingPathComponent(note.file)
                created.append(destination)
                if note.id == guide.id { try Self.demonstrationGuide().write(to: destination, options: .atomic) }
                else if note.id == writing.id {
                    let document = PDFDocument()
                    for template in [PaperTemplate.ruled, .dots, .lecture] {
                        guard let page = PDFDocument(data: template.render(color: .cream))?.page(at: 0) else { throw CocoaError(.fileReadCorruptFile) }
                        document.insert(page, at: document.pageCount)
                    }
                    guard let data = document.dataRepresentation() else { throw CocoaError(.fileWriteUnknown) }
                    try data.write(to: destination, options: .atomic)
                } else { try FileManager.default.copyItem(at: office, to: destination) }
                let margins = MarginPages(root: root, notebook: note.id)
                created.append(margins.folder)
                guard margins.error == nil, let first = margins.currentID else { throw CocoaError(.fileWriteUnknown) }
                margins.editTitle("ملاحظتي الأولى", page: first)
                margins.editText("هذه ملاحظة تجريبية قابلة للتعديل. اختر خط اليد للكتابة بالقلم أو الإصبع. استخدم + لإضافة صفحة حاشية، والأسهم للتنقل دون فقد كتابتك.", page: first)
                margins.linkCurrent(to: 1)
                let points = [CGPoint(x: 70, y: 110), CGPoint(x: 200, y: 150), CGPoint(x: 340, y: 100), CGPoint(x: 480, y: 145)].enumerated().map { index, point in
                    PKStrokePoint(location: point, timeOffset: Double(index) * 0.1, size: CGSize(width: 4, height: 4), opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
                }
                margins.saveInk(PKDrawing(strokes: [PKStroke(ink: PKInk(.pen, color: UIColor(TayyaTheme.brandInk)), path: PKStrokePath(controlPoints: points, creationDate: Date()))]), page: first)
                guard margins.add(linkedTo: 2), let second = margins.currentID else { throw CocoaError(.fileWriteUnknown) }
                margins.editTitle("متابعة الملاحظات", page: second)
                margins.editText("صفحة مستقلة مرتبطة بصفحة المستند الثانية. افتح خيارات الحاشية لتسمية الصفحات أو تصدير كل الملاحظات إلى PDF.", page: second)
                guard margins.saved, margins.error == nil, margins.select(first) else { throw CocoaError(.fileWriteUnknown) }
            }
            // If publishing fails, restore the old manifest and retire only new samples.
            try JSONEncoder().encode(samples.map(\.id)).write(to: manifestURL, options: .atomic)
            do { try persist(samples + notebooks) }
            catch {
                if previous.isEmpty { try? FileManager.default.removeItem(at: manifestURL) }
                else { try? JSONEncoder().encode(previous).write(to: manifestURL, options: .atomic) }
                throw error
            }
            notebooks = samples + notebooks
            return guide
        } catch {
            for url in created { try? FileManager.default.removeItem(at: url) }
            throw error
        }
    }

    private static func demonstrationGuide() -> Data {
        let bounds = CGRect(x: 0, y: 0, width: 650, height: 900)
        let lessons = [
            ("أهلًا بك في طَيّة", "هذه مكتبة تجريبية محلية، ولا تحتاج إلى حساب أو اتصال بالإنترنت.\n\nهذا الدليل ملف PDF من ثلاث صفحات يمكنك القراءة والكتابة عليه. بجانبه دفتر جاهز وعرض تقديمي لتجربة ملفات Office. كل الملفات التجريبية قابلة للتعديل والنقل للمحذوفات.\n\nاستخدم الأسهم أعلى المستند للانتقال إلى الصفحة التالية، أو أدخل رقم الصفحة. اختر القلم لتكتب فوق الصفحة، وAa لإضافة نص. يمكنك تصدير المستند مع تعليقاتك من قائمة الخيارات."),
            ("صفحات الحاشية وخط اليد", "افتح الحاشية من قائمة المستند. توجد ملاحظتان جاهزتان؛ اختر نص أو خط اليد للتجربة.\n\nأسهم الحاشية تنقل بين ملاحظاتك، وعلامة + تضيف صفحة مستقلة. أسهم المستند تتصفح PDF دون تغيير صفحة الحاشية.\n\nاسحب الفاصل لتغيير حجم مساحة الكتابة، أو وسّع الحاشية إلى ملء الشاشة. كتابتك تبقى محفوظة عند تدوير الجهاز أو تغيير المساحة.\n\nفي وضع الكتابة، حرّك الورقة بإصبعين؛ وفي وضع التحريك استخدم إصبعًا واحدًا. أزرار ملاءمة العرض والصفحة تعيد إظهار الورقة كاملة أو بحجم مريح."),
            ("جرّب بقية الأدوات", "ارجع إلى المكتبة واختر دفتر جديد لإنشاء أوراق مسطّرة أو منقّطة أو قالب محاضرة.\n\nزر استيراد يفتح تطبيق الملفات: اختر PDF أو مستند Office من جهازك. جرّب العرض التقديمي الجاهز من المكتبة، ثم تحويله إلى PDF للكتابة عليه. قد يختلف تنسيق الخطوط، ولا تنتقل حركة الشرائح أو الفيديو إلى PDF.\n\nيمكنك البحث في النصوص والحواشي، وتنظيم الأقسام والمفضلة، وإنشاء بطاقات مراجعة. التسجيل الصوتي اختياري ويطلب إذن الميكروفون عند تشغيله فقط.\n\nالنسخ الاحتياطي والتصدير متاحان من المكتبة. لا تحتوي ملفات التجربة على بيانات شخصية.")
        ]
        return UIGraphicsPDFRenderer(bounds: bounds).pdfData { context in
            for (index, lesson) in lessons.enumerated() {
                context.beginPage(); PaperColor.cream.uiColor.setFill(); context.cgContext.fill(bounds)
                let style = NSMutableParagraphStyle(); style.alignment = .right; style.baseWritingDirection = .rightToLeft; style.lineSpacing = 10
                (lesson.0 as NSString).draw(in: CGRect(x: 45, y: 55, width: 560, height: 65), withAttributes: [.font: UIFont.systemFont(ofSize: 30, weight: .semibold), .foregroundColor: UIColor(TayyaTheme.brandInk), .paragraphStyle: style])
                // Lay out every glyph, reducing the font only when necessary.
                // An ASCII end marker also makes PDF text extraction verifiable
                // without depending on PDFKit's Arabic ligature/RTL ordering.
                let body = lesson.1 + "\n\nTayya Demo"
                var fontSize: CGFloat = 21
                while true {
                    let storage = NSTextStorage(string: body, attributes: [.font: UIFont.systemFont(ofSize: fontSize), .foregroundColor: UIColor.darkGray, .paragraphStyle: style])
                    let layout = NSLayoutManager(); storage.addLayoutManager(layout)
                    let container = NSTextContainer(size: CGSize(width: 560, height: 670)); container.lineFragmentPadding = 0
                    layout.addTextContainer(container)
                    let range = layout.glyphRange(for: container)
                    if NSMaxRange(range) == layout.numberOfGlyphs {
                        layout.drawGlyphs(forGlyphRange: range, at: CGPoint(x: 45, y: 145))
                        break
                    }
                    fontSize -= 1
                }
                ("\(index + 1) / 3 — مكتبة تجريبية" as NSString).draw(in: CGRect(x: 45, y: 845, width: 560, height: 30), withAttributes: [.font: UIFont.systemFont(ofSize: 14), .foregroundColor: UIColor.darkGray, .paragraphStyle: style])
            }
        }
    }
}
