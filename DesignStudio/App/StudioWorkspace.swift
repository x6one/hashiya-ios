import SwiftUI

struct StudioWorkspace: View {
    @ObservedObject var session: StudioSession
    @ObservedObject var navigation: StudioNavigation
    @ObservedObject var documentInk: StudioCanvas
    @ObservedObject var marginInk: StudioCanvas
    let pdf: StudioPDFController
    @State private var tool = "pen"
    @State private var inkTool = "pen"
    @State private var inkColor = 0x244C43
    @State private var inkWidth: CGFloat = 3
    @State private var focus = false
    @State private var sidebar = true
    @State private var bookmark = false
    @State private var fraction: CGFloat = 0.64
    @State private var dragOrigin: CGFloat?
    @State private var activeMargin = false
    @State private var noteText = L("ملاحظات مهمة\n\n• التركيز على طرفي المعادلة.\n• مراجعة المثال قبل المحاضرة القادمة.", "Key ideas\n\n• Watch both sides of the equation.\n• Review the example before the next lecture.")
    @Environment(\.layoutDirection) private var direction
    private var tablet: Bool { UIDevice.current.userInterfaceIdiom == .pad }
    private var marginOnly: Bool { navigation.scene == .margin }

    var body: some View {
        VStack(spacing: 0) {
            header
            if !focus { TayyaPageNavigator(session: session) { navigation.sheet = .pages } }
            GeometryReader { geo in
                if marginOnly {
                    marginPanel.padding(16)
                } else if tablet {
                    tabletContent(size: geo.size)
                } else {
                    documentPanel.padding(.horizontal, 12).padding(.vertical, 8)
                }
            }
            if !focus {
                StudioRecordingStrip(session: session, navigation: navigation)
                if tool == "pen" || marginOnly { inkRail }
                toolDock
            }
        }.background(StudioTheme.background).accessibilityIdentifier("workspaceScene")
            .onAppear {
                activeMargin = marginOnly
                syncInkToolbar()
                documentInk.onActivate = { activeMargin = false }
                marginInk.onActivate = { activeMargin = true }
                documentInk.onStroke = { session.markWriting(L("خط يد في المستند", "Document handwriting")) }
                marginInk.onStroke = { session.markWriting(L("خط يد في الحاشية", "Margin handwriting")) }
            }
            .onChange(of: activeMargin) { _, _ in syncInkToolbar() }
            .onChange(of: navigation.scene) { _, _ in activeMargin = marginOnly; syncInkToolbar() }
            .onDisappear {
                documentInk.onActivate = nil; marginInk.onActivate = nil
                documentInk.onStroke = nil; marginInk.onStroke = nil
            }
            .onChange(of: navigation.color) { _, value in inkColor = value; updateInk() }
            .onChange(of: navigation.preset) { _, value in
                let index = max(0, min(2, value - 1))
                inkColor = [0x244C43, 0xA14F2B, 0xD8AF47][index]
                inkWidth = [3, 6, 12][index]
                inkTool = index == 2 ? "highlighter" : "pen"
                updateInk()
            }
    }
    private var header: some View {
        HStack(spacing: 4) {
            TayyaIconButton(title: L("الرجوع للمكتبة", "Back to library"), symbol: "chevron.backward") { navigation.scene = .library }
            VStack(alignment: .leading, spacing: 2) {
                Text(marginOnly ? L("حاشية الصفحة \(session.page)", "Page \(session.page) margin") : L("مبادئ المحاسبة", "Accounting principles"))
                    .font(.subheadline.weight(.semibold)).lineLimit(2)
                if tablet { Text(L("الفصل الثالث · مساحة الدراسة", "Chapter three · Study workspace")).font(.caption2).foregroundStyle(StudioTheme.secondary) }
            }.frame(maxWidth: .infinity, alignment: .leading)
            if tablet && !focus {
                TayyaIconButton(title: L("إظهار المصغرات", "Toggle thumbnails"), symbol: "sidebar.leading", selected: sidebar) { sidebar.toggle() }
            }
            if !focus {
                TayyaIconButton(title: L("علامة مرجعية", "Bookmark"), symbol: bookmark ? "bookmark.fill" : "bookmark", selected: bookmark) { bookmark.toggle() }
                    .accessibilityIdentifier("bookmarkAction")
                TayyaIconButton(title: L("مشاركة وتصدير", "Share and export"), symbol: "square.and.arrow.up") { navigation.sheet = .share }
            }
            TayyaIconButton(title: focus ? L("إظهار الأدوات", "Show tools") : L("وضع التركيز", "Focus mode"), symbol: focus ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right", selected: focus) { focus.toggle() }
                .accessibilityIdentifier("focusToggle").accessibilityValue(focus ? "focused" : "standard")
        }.padding(.horizontal, 12).padding(.vertical, 8).background(StudioTheme.surface)
    }
    private func tabletContent(size: CGSize) -> some View {
        HStack(spacing: 0) {
            if sidebar && !focus && size.width > 1000 { thumbnails.frame(width: 132) }
            if session.marginOpen && !focus {
                HStack(spacing: 0) {
                    documentPanel.frame(width: max(280, (size.width - (sidebar && size.width > 1000 ? 132 : 0)) * fraction - 8))
                    RoundedRectangle(cornerRadius: 3).fill(StudioTheme.divider).frame(width: 4, height: 68)
                        .frame(width: 16).frame(maxHeight: .infinity).contentShape(Rectangle())
                        .gesture(DragGesture().onChanged { value in
                            if dragOrigin == nil { dragOrigin = fraction }
                            let delta = value.translation.width / size.width * (direction == .rightToLeft ? -1 : 1)
                            fraction = min(0.7, max(0.45, (dragOrigin ?? fraction) + delta))
                        }.onEnded { _ in dragOrigin = nil })
                        .accessibilityLabel(L("حجم التقسيم", "Split size"))
                        .accessibilityAdjustableAction { fraction = min(0.7, max(0.45, fraction + ($0 == .increment ? 0.05 : -0.05))) }
                    marginPanel.frame(maxWidth: .infinity)
                }.padding(16)
            } else { documentPanel.padding(16) }
        }
    }
    private var documentPanel: some View {
        ZStack {
            StudioPDFView(page: session.page, controller: pdf)
            if tool == "pen" { StudioInkView(canvas: documentInk) }
            if !navigation.savedText.isEmpty {
                VStack { Spacer(); Text(navigation.savedText).font(.body).foregroundStyle(.black).padding(12).background(.white.opacity(0.9)); Spacer() }
                    .allowsHitTesting(false)
            }
        }.background(.white, in: RoundedRectangle(cornerRadius: 8))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(alignment: .topLeading) {
                if tool == "text" {
                    Button(L("إضافة ملاحظة نصية", "Add text note")) { navigation.sheet = .text }
                        .font(.caption).padding(12).background(StudioTheme.selection, in: Capsule()).padding(12)
                }
            }
    }
    private var marginPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(L("الحاشية", "Margin"), systemImage: "note.text").font(.headline)
                    Spacer()
                    Text(L("صفحة \(session.page)", "Page \(session.page)")).font(.caption).foregroundStyle(StudioTheme.secondary)
                    TayyaIconButton(title: L("قوالب الورق", "Paper templates"), symbol: "ellipsis") { navigation.sheet = .templates }
                }
                Divider()
                TextEditor(text: $noteText).font(.body).scrollContentBackground(.hidden)
                    .frame(minHeight: 140, maxHeight: 200).accessibilityIdentifier("marginText")
                    .onChange(of: noteText) { _, text in session.markWriting(String(text.suffix(50))) }
                Text(L("الأصول = الالتزامات + حقوق الملكية", "Assets = Liabilities + Equity"))
                    .font(.callout.weight(.medium)).padding(12).frame(maxWidth: .infinity)
                    .background(StudioTheme.selection, in: RoundedRectangle(cornerRadius: 8))
                ZStack {
                    Canvas { context, size in
                        for y in stride(from: CGFloat(24), to: navigation.paper == 3 ? 0 : size.height, by: 32) {
                            var line = Path(); line.move(to: CGPoint(x: 0, y: y)); line.addLine(to: CGPoint(x: size.width, y: y))
                            if navigation.paper == 2 {
                                for x in stride(from: CGFloat(16), to: size.width, by: 24) {
                                    context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 2, height: 2)), with: .color(StudioTheme.divider))
                                }
                            } else { context.stroke(line, with: .color(StudioTheme.divider.opacity(0.55)), lineWidth: 0.5) }
                        }
                        if navigation.paper == 1 {
                            for x in stride(from: CGFloat(16), to: size.width, by: 32) {
                                var line = Path(); line.move(to: CGPoint(x: x, y: 0)); line.addLine(to: CGPoint(x: x, y: size.height))
                                context.stroke(line, with: .color(StudioTheme.divider.opacity(0.55)), lineWidth: 0.5)
                            }
                        }
                    }.accessibilityHidden(true)
                    StudioInkView(canvas: marginInk)
                }.frame(height: tablet ? 220 : 180)
                Label(L("مرتبط بالمستند · صفحة \(session.page)", "Linked to document · Page \(session.page)"), systemImage: "link")
                    .font(.caption2).foregroundStyle(StudioTheme.secondary)
            }
        }.studioCard().accessibilityIdentifier("marginPanel")
    }
    private var thumbnails: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text(L("الصفحات", "PAGES")).font(.caption.weight(.semibold)).foregroundStyle(StudioTheme.secondary)
                ForEach(5...10, id: \.self) { page in
                    Button { session.changePage(to: page) } label: {
                        VStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 7) {
                                RoundedRectangle(cornerRadius: 2).fill(StudioTheme.primary.opacity(0.6)).frame(width: 40, height: 4)
                                ForEach(0..<7) { _ in Rectangle().fill(StudioTheme.divider).frame(height: 2) }
                                HStack(alignment: .bottom, spacing: 4) {
                                    ForEach(0..<4) { i in Rectangle().fill(StudioTheme.copper.opacity(0.65)).frame(width: 10, height: CGFloat(12 + i * 6)) }
                                }.padding(.top, 6)
                            }.padding(12).frame(width: 92, height: 130).background(StudioTheme.surface, in: RoundedRectangle(cornerRadius: 8))
                                .overlay { RoundedRectangle(cornerRadius: 8).stroke(page == session.page ? StudioTheme.primary : Color.clear, lineWidth: 2) }
                            Text("\(page)").font(.caption).foregroundStyle(page == session.page ? StudioTheme.primary : StudioTheme.secondary)
                        }
                    }.buttonStyle(.plain).accessibilityLabel(L("الصفحة \(page)", "Page \(page)"))
                }
            }.padding(16)
        }.background(StudioTheme.selection.opacity(0.35))
    }
    private var inkRail: some View {
        TayyaToolbar {
            if tablet && session.marginOpen && !marginOnly {
                Button { activeMargin.toggle() } label: {
                    Label(activeMargin ? L("الحاشية", "Margin") : L("المستند", "Document"), systemImage: activeMargin ? "note.text" : "doc")
                        .font(.caption).padding(.horizontal, 8).frame(minHeight: 44).background(StudioTheme.selection, in: RoundedRectangle(cornerRadius: 10))
                }.buttonStyle(.plain).accessibilityIdentifier("inkTarget").accessibilityValue(activeMargin ? "margin" : "document")
            }
            ForEach(["pen", "pencil", "highlighter", "eraser"], id: \.self) { ink in
                let symbols = ["pen": "pencil.tip", "pencil": "pencil", "highlighter": "highlighter", "eraser": "eraser"]
                let titles = ["pen": L("حبر", "Ink"), "pencil": L("رصاص", "Pencil"), "highlighter": L("تظليل", "Highlight"), "eraser": L("ممحاة", "Eraser")]
                TayyaIconButton(title: titles[ink] ?? ink, symbol: symbols[ink] ?? "pencil", selected: inkTool == ink) { inkTool = ink; updateInk() }
            }
            Divider().frame(height: 24)
            Button { navigation.sheet = .colors } label: {
                Circle().fill(Color(uiColor: StudioTheme.ui(inkColor))).frame(width: 22, height: 22).padding(11)
            }.buttonStyle(.plain).accessibilityLabel(L("لون القلم", "Ink color")).accessibilityIdentifier("inkColor")
            Button { inkWidth = inkWidth == 3 ? 6 : inkWidth == 6 ? 1.5 : 3; updateInk() } label: {
                Text("\(inkWidth, specifier: "%g")").font(.subheadline).frame(width: 44, height: 44)
            }.buttonStyle(.plain).accessibilityLabel(L("سماكة القلم", "Pen width"))
            TayyaIconButton(title: L("تراجع", "Undo"), symbol: "arrow.uturn.backward") { currentCanvas.view.undoManager?.undo() }
            TayyaIconButton(title: L("إعادة", "Redo"), symbol: "arrow.uturn.forward") { currentCanvas.view.undoManager?.redo() }
            TayyaIconButton(title: L("أقلامي المفضلة", "Favorite pens"), symbol: "star") { navigation.sheet = .pens }
        }
    }
    private var toolDock: some View {
        HStack(spacing: 0) {
            ForEach(["pen", "text", "select", "margin", "pages"], id: \.self) { item in
                let titles = ["pen": L("قلم", "Pen"), "text": L("نص", "Text"), "select": L("تحديد", "Select"), "margin": L("حاشية", "Margin"), "pages": L("صفحات", "Pages")]
                let symbols = ["pen": "pencil.tip", "text": "textformat", "select": "lasso", "margin": "note.text", "pages": "square.grid.2x2"]
                Button { chooseTool(item) } label: {
                    VStack(spacing: 4) {
                        Image(systemName: symbols[item] ?? "pencil").font(.system(size: 19))
                        Text(titles[item] ?? item).font(.caption2).fixedSize(horizontal: false, vertical: true)
                    }.padding(.horizontal, 4).frame(maxWidth: .infinity, minHeight: 52)
                        .foregroundStyle((marginOnly && item == "margin") || tool == item ? StudioTheme.primary : StudioTheme.secondary)
                        .background((marginOnly && item == "margin") || tool == item ? StudioTheme.selection : Color.clear, in: RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(.plain).accessibilityIdentifier("tool-\(item)")
            }
        }.padding(.horizontal, 12).padding(.vertical, 8).background(StudioTheme.surface)
    }
    private var currentCanvas: StudioCanvas { marginOnly || (tablet && session.marginOpen && activeMargin) ? marginInk : documentInk }
    private func syncInkToolbar() { inkTool = currentCanvas.brush; inkColor = currentCanvas.color; inkWidth = currentCanvas.width }
    private func updateInk() { currentCanvas.configure(tool: inkTool, color: inkColor, width: inkWidth) }
    private func chooseTool(_ item: String) {
        switch item {
        case "margin":
            if tablet && !marginOnly { session.marginOpen.toggle() }
            else { navigation.scene = marginOnly ? .document : .margin }
        case "pages": navigation.sheet = .pages
        default: tool = item
        }
    }
}
