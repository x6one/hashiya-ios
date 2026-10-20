import PDFKit
import PencilKit
import SwiftUI

enum StudioScene: String { case library, document, margin, audio, cards }
enum StudioSheet: String, Identifiable {
    case pages, share, colors, text, templates, pens, importDocument, trash, backup, newCard
    var id: String { rawValue }
}

struct StudioStudyCard: Identifiable {
    let id = UUID()
    let page: Int
    let question: String
    let answer: String
}

final class StudioNavigation: ObservableObject {
    @Published var scene: StudioScene
    @Published var sheet: StudioSheet?
    @Published var addNotebook = false
    @Published var color = 0x244C43
    var onColorPick: ((Int) -> Void)?
    @Published var paper = 0
    @Published var preset = 0
    @Published var savedText = ""
    @Published var cards = [
        StudioStudyCard(page: 7, question: L("ما المعادلة الأساسية للمحاسبة؟", "What is the fundamental accounting equation?"), answer: L("الأصول = الالتزامات + حقوق الملكية", "Assets = Liabilities + Equity")),
        StudioStudyCard(page: 7, question: L("ما المقصود بالأصول؟", "What are assets?"), answer: L("موارد تمتلكها المنشأة وتحقق منفعة مستقبلية.", "Resources controlled by an entity with future economic benefit.")),
        StudioStudyCard(page: 8, question: L("كيف يؤثر شراء أصل نقدًا؟", "What happens when an asset is bought for cash?"), answer: L("يتغير توزيع الأصول ويبقى مجموعها ثابتًا.", "The composition of assets changes while the total remains equal."))
    ]
    init() {
        let args = ProcessInfo.processInfo.arguments
        let value = args.firstIndex(of: "--scene").flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil }
        scene = StudioScene(rawValue: value ?? "library") ?? .library
    }
}

struct StudioRoot: View {
    @StateObject private var session = StudioSession()
    @StateObject private var navigation = StudioNavigation()
    @StateObject private var documentInk = StudioCanvas()
    @StateObject private var marginInk = StudioCanvas(margin: true)
    @StateObject private var pdf = StudioPDFController()
    @StateObject private var draft = StudioDraft()
    @State private var prepared = false
    @Environment(\.scenePhase) private var phase
    private var args: [String] { ProcessInfo.processInfo.arguments }
    private var english: Bool { args.contains("--english") }
    private var appearance: ColorScheme? { args.contains("--dark") ? .dark : args.contains("--light") ? .light : nil }
    var body: some View {
        content
            .foregroundStyle(StudioTheme.text).tint(StudioTheme.primary)
            .environment(\.layoutDirection, english ? .leftToRight : .rightToLeft)
            .environment(\.locale, Locale(identifier: english ? "en" : "ar"))
            .transformEnvironment(\.dynamicTypeSize) { if args.contains("--extra-large-type") { $0 = .accessibility5 } else if args.contains("--large-type") { $0 = .accessibility2 } }
            .preferredColorScheme(appearance)
            .sheet(item: $navigation.sheet) { sheet in
                StudioSheetView(sheet: sheet, session: session, navigation: navigation, pdf: pdf, draft: draft)
                    .environment(\.layoutDirection, english ? .leftToRight : .rightToLeft)
                    .preferredColorScheme(appearance)
                    .transformEnvironment(\.dynamicTypeSize) { if args.contains("--extra-large-type") { $0 = .accessibility5 } else if args.contains("--large-type") { $0 = .accessibility2 } }
            }
            .onAppear {
                guard !prepared else { return }
                prepared = true
                session.page = draft.state.page
                session.lastVisitedPage = draft.state.lastPage
                navigation.savedText = draft.state.text
                if let data = draft.state.pdf, let document = PDFDocument(data: data) { pdf.view.document = document; pdf.contentChanged() }
                if let drawing = try? PKDrawing(data: draft.state.documentInk) { documentInk.view.drawing = drawing }
                if let drawing = try? PKDrawing(data: draft.state.marginInk) { marginInk.view.drawing = drawing }
                pdf.onPageChange = { page in session.changePage(to: page) }
                session.marginOpen = UIDevice.current.userInterfaceIdiom == .pad
                session.title = L("محاضرة المحاسبة", "Accounting lecture")
                if navigation.scene == .audio {
                    session.recording = true
                    session.elapsed = 152
                    session.markers = [
                        StudioMarker(page: 7, time: 0, label: L("بداية المحاضرة", "Lecture begins"), kind: "page"),
                        StudioMarker(page: 7, time: 78, label: L("المعادلة الأساسية", "The fundamental equation"), kind: "writing"),
                        StudioMarker(page: 8, time: 138, label: L("مثال تطبيقي", "Worked example"), kind: "manual")
                    ]
                }
            }
            .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
                if !args.contains("--capture") { session.tick(seconds: 1) }
            }
            .onChange(of: session.page) { _, page in
                draft.state.page = page
                draft.state.lastPage = session.lastVisitedPage
            }
            .onChange(of: phase) { _, value in if value == .background { session.sceneBecameInactive() } }
    }
    @ViewBuilder private var content: some View {
        switch navigation.scene {
        case .library: StudioLibrary(session: session, navigation: navigation)
        case .document, .margin: StudioWorkspace(session: session, navigation: navigation, documentInk: documentInk, marginInk: marginInk, pdf: pdf, draft: draft)
        case .audio: StudioAudio(session: session, navigation: navigation)
        case .cards: StudioCards(navigation: navigation, session: session)
        }
    }
}
