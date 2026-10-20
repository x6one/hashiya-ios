import SwiftUI

struct StudioSheetView: View {
    let sheet: StudioSheet
    @ObservedObject var session: StudioSession
    @ObservedObject var navigation: StudioNavigation
    let pdf: StudioPDFController
    @ObservedObject var draft: StudioDraft
    @State private var text = ""
    @State private var answer = ""
    @State private var pageNumber = ""
    @State private var textPage = 7
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    contents
                    if sheet == .pens || sheet == .text { StudioSaveStatus(draft: draft, identifier: "sheetSaveStatus") }
                }
                    .padding(24).frame(maxWidth: 720).frame(maxWidth: .infinity)
            }.background(StudioTheme.background)
                .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L("تم", "Done")) { dismiss() } } }
        }.foregroundStyle(StudioTheme.text).tint(StudioTheme.primary)
            .onAppear { if sheet == .text { textPage = session.page; text = pdf.text(on: textPage) } }
    }
    private var title: String {
        switch sheet {
        case .pages: return L("الصفحات", "Pages")
        case .share: return L("تصدير ومشاركة", "Export and share")
        case .colors: return L("ألوان الحبر", "Ink colors")
        case .text: return L("ملاحظة نصية", "Text note")
        case .templates: return L("قوالب الورق", "Paper templates")
        case .pens: return L("أقلامي المفضلة", "Favorite pens")
        case .importDocument: return L("استيراد ملف", "Import document")
        case .trash: return L("المحذوفات", "Recently deleted")
        case .backup: return L("النسخ الاحتياطية", "Backups")
        case .newCard: return L("بطاقة جديدة", "New card")
        }
    }
    @ViewBuilder private var contents: some View {
        switch sheet {
        case .pages: pages
        case .colors: colors
        case .pens: pens
        case .templates: templates
        case .share:
            ShareLink(item: L("الأصول = الالتزامات + حقوق الملكية", "Assets = Liabilities + Equity")) {
                Label(L("مشاركة المقتطف", "Share excerpt"), systemImage: "square.and.arrow.up").frame(minHeight: 44)
            }
            Text(L("توزيع مقترح للتصدير: PDF والتسجيلات والنسخ الاحتياطية.", "Proposed export placement: PDF, recordings and backups."))
                .font(.caption).foregroundStyle(StudioTheme.secondary)
        case .text, .newCard:
            TextField(sheet == .newCard ? L("السؤال", "Question") : L("اكتب فكرتك", "Write your idea"), text: $text, axis: .vertical)
                .lineLimit(4...10).studioCard()
            if sheet == .newCard {
                TextField(L("الإجابة", "Answer"), text: $answer, axis: .vertical).lineLimit(3...8).studioCard()
            }
            TayyaPrimaryButton(title: L("حفظ", "Save"), symbol: "checkmark") {
                if sheet == .newCard { navigation.cards.append(StudioStudyCard(page: session.page, question: text, answer: answer)) }
                else {
                    let style = draft.state.documentTextStyles?[textPage] ?? pdf.textStyle(on: textPage)
                    pdf.updateText(text, size: style.size, color: style.color, alignment: style.alignment, page: textPage)
                    draft.state.text = text
                    draft.state.pdf = pdf.view.document?.dataRepresentation()
                    session.markWriting(text)
                    navigation.savedText = text
                }
                dismiss()
            }.disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (sheet == .newCard && answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
        case .trash:
            TayyaEmptyState(title: L("لا توجد ملفات محذوفة", "No deleted documents"), message: L("تظهر الملفات هنا قبل حذفها نهائيًا.", "Deleted documents appear here before permanent removal."))
        case .backup:
            TayyaEmptyState(title: L("نسخك الاحتياطية", "Your backups"), message: L("النسخ والاستعادة في مكان واحد.", "Backup and restore belong together."))
        case .importDocument:
            TayyaEmptyState(title: L("PDF وملفات Office", "PDF and Office files"), message: L("تُفتح نافذة الملفات الأصلية عند دمج التصميم المعتمد.", "Opens the native Files picker after design integration."))
        }
    }
    private var pages: some View {
        VStack(alignment: .leading, spacing: StudioMetrics.spacing) {
            HStack(spacing: StudioMetrics.compact) {
                TextField(L("رقم الصفحة", "Page number"), text: $pageNumber)
                    .keyboardType(.numberPad).textFieldStyle(.roundedBorder).frame(minHeight: StudioMetrics.touch)
                    .accessibilityIdentifier("pageNumberInput")
                Button {
                    NSLog("%@", "StudioPage jump scalars=\(pageNumber.unicodeScalars.prefix(16).map { $0.value })")
                    if session.jump(to: pageNumber) { dismiss() }
                } label: {
                    Text(L("انتقال", "Go")).frame(minWidth: StudioMetrics.touch, minHeight: StudioMetrics.touch).contentShape(Rectangle())
                }.buttonStyle(.plain)
                    .accessibilityIdentifier("jumpToPage")
            }
            if let last = session.lastVisitedPage {
                Button { session.changePage(to: last); dismiss() } label: {
                    Label(L("آخر صفحة زرتها: \(last)", "Last visited page: \(last)"), systemImage: "arrow.uturn.backward")
                        .font(.subheadline).frame(minHeight: StudioMetrics.touch)
                }.accessibilityIdentifier("lastVisitedPage")
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 88))], spacing: StudioMetrics.spacing) {
                ForEach(0..<pdf.thumbnails.pageCount, id: \.self) { index in
                    let page = index + 1
                    Button { session.changePage(to: page); dismiss() } label: {
                        StudioPageThumbnail(page: page, selected: page == session.page, store: pdf.thumbnails)
                            .padding(StudioMetrics.compact).contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityElement(children: .contain).accessibilityAddTraits(.isButton)
                        .accessibilityIdentifier("pickPage-\(page)")
                        .accessibilityLabel(L("الصفحة \(page)", "Page \(page)"))
                        .accessibilityAddTraits(page == session.page ? .isSelected : [])
                }
            }
        }
    }
    private var colors: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 16) {
            ForEach([0x244C43, 0xA14F2B, 0x68458A, 0x2D6382, 0x282C2B, 0xAA3333], id: \.self) { color in
                Button { navigation.color = color; navigation.onColorPick?(color); dismiss() } label: {
                    Circle().fill(Color(uiColor: StudioTheme.ui(color))).frame(width: 44, height: 44).padding(8)
                }.buttonStyle(.plain).accessibilityLabel(String(format: "#%06X", color))
            }
        }
    }
    @ViewBuilder private var pens: some View {
        ForEach(0..<3) { index in
            HStack(spacing: StudioMetrics.inset) {
                let pen = draft.state.pens[index]
                Button { navigation.preset = index + 1; dismiss() } label: {
                    HStack(spacing: StudioMetrics.inset) {
                        Image(systemName: pen.brush == "highlighter" ? "highlighter" : pen.brush == "pencil" ? "pencil" : "pencil.tip")
                            .font(.title2).foregroundStyle(Color(uiColor: StudioTheme.ui(pen.color)))
                        VStack(alignment: .leading, spacing: StudioMetrics.unit) {
                            Text(L("قلم \(index + 1)", "Pen \(index + 1)")).font(.headline)
                            Text(String(format: "#%06X · %g pt", pen.color, pen.width)).font(.caption).foregroundStyle(StudioTheme.secondary)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }.frame(minHeight: 56).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityIdentifier("usePen-\(index + 1)").accessibilityValue(pen.description)
                TayyaIconButton(title: L("حفظ الإعداد الحالي في القلم \(index + 1)", "Save current settings to pen \(index + 1)"), symbol: "square.and.arrow.down") {
                    draft.savePen(at: index, pen: draft.state.currentPen)
                }.accessibilityIdentifier("savePen-\(index + 1)")
            }.studioCard()
        }
        Text(L("اختر اللون والنوع والسماكة، ثم احفظ الإعداد في أي من الأقلام الثلاثة. محفوظة في مساحة المعاينة فقط.", "Choose color, type and width, then save to any of the three slots. Stored only in this preview's sandbox."))
            .font(.caption).foregroundStyle(StudioTheme.secondary).fixedSize(horizontal: false, vertical: true)
    }
    private var templates: some View {
        ForEach(0..<4) { index in
            let titles = [L("مسطر", "Ruled"), L("مربعات", "Grid"), L("نقاط", "Dots"), L("فارغ", "Blank")]
            Button { navigation.paper = index; dismiss() } label: {
                HStack { Text(titles[index]); Spacer(); if navigation.paper == index { Image(systemName: "checkmark") } }
                    .frame(minHeight: 44).studioCard()
            }.buttonStyle(.plain)
        }
    }
}
