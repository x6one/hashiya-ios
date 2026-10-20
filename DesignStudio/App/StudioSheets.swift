import SwiftUI

struct StudioSheetView: View {
    let sheet: StudioSheet
    @ObservedObject var session: StudioSession
    @ObservedObject var navigation: StudioNavigation
    @State private var text = ""
    @State private var answer = ""
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) { contents }
                    .padding(24).frame(maxWidth: 720).frame(maxWidth: .infinity)
            }.background(StudioTheme.background)
                .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L("تم", "Done")) { dismiss() } } }
        }.foregroundStyle(StudioTheme.text).tint(StudioTheme.primary)
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
                else { session.markWriting(text); navigation.savedText = text }
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
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 88))], spacing: 16) {
            ForEach(1...24, id: \.self) { page in
                Button { session.changePage(to: page); dismiss() } label: {
                    VStack(spacing: 12) { Image(systemName: "doc").font(.largeTitle); Text("\(page)").font(.caption) }
                        .frame(maxWidth: .infinity, minHeight: 120)
                        .background(page == session.page ? StudioTheme.selection : StudioTheme.surface, in: RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(.plain)
            }
        }
    }
    private var colors: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 16) {
            ForEach([0x244C43, 0xA14F2B, 0x68458A, 0x2D6382, 0x282C2B, 0xAA3333], id: \.self) { color in
                Button { navigation.color = color; dismiss() } label: {
                    Circle().fill(Color(uiColor: StudioTheme.ui(color))).frame(width: 44, height: 44).padding(8)
                }.buttonStyle(.plain).accessibilityLabel(String(format: "#%06X", color))
            }
        }
    }
    private var pens: some View {
        ForEach(0..<3) { index in
            Button { navigation.preset = index + 1; dismiss() } label: {
                HStack(spacing: 16) {
                    Image(systemName: index == 2 ? "highlighter" : "pencil.tip").font(.title2)
                    VStack(alignment: .leading, spacing: 6) {
                        Text([L("قلم الدراسة", "Study pen"), L("قلم العناوين", "Heading pen"), L("قلم التمييز", "Highlighter")][index]).font(.headline)
                        Text(["3 pt", "6 pt", "12 pt"][index]).font(.caption).foregroundStyle(StudioTheme.secondary)
                    }
                    Spacer()
                    Circle().fill(Color(uiColor: StudioTheme.ui([0x244C43, 0xA14F2B, 0xD8AF47][index]))).frame(width: 24, height: 24)
                    Image(systemName: "star.fill").foregroundStyle(StudioTheme.copper)
                }.frame(minHeight: 56).studioCard()
            }.buttonStyle(.plain)
        }
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
