import SwiftUI

struct StudioWorkspace: View {
    @ObservedObject var session: StudioSession
    @ObservedObject var navigation: StudioNavigation
    @ObservedObject var documentInk: StudioCanvas
    @ObservedObject var marginInk: StudioCanvas
    let pdf: StudioPDFController
    @ObservedObject var draft: StudioDraft
    @State private var tool = "pen"
    @State private var inkTool = "pen"
    @State private var inkColor = 0x244C43
    @State private var inkWidth: CGFloat = 3
    @State private var focus = false
    @State private var sidebar = true
    @State private var bookmark = false
    @State private var fraction: CGFloat = 0.64
    @State private var dragOrigin: CGFloat?
    @State private var selectionExists = false
    @State private var narrowPane = false
    @FocusState private var notesFocused: Bool
    @ScaledMetric(relativeTo: .body) private var bodyScale: CGFloat = 17
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.verticalSizeClass) private var verticalClass
    @Environment(\.layoutDirection) private var direction
    @Environment(\.dynamicTypeSize) private var typeSize
    private var tablet: Bool { UIDevice.current.userInterfaceIdiom == .pad }
    private var marginOnly: Bool { navigation.scene == .margin }

    private var activeMargin: Bool {
        get { session.activeNotes }
        nonmutating set { session.activeNotes = newValue }
    }
    private var expandedPresentation: Bool { session.notesExpanded || typeSize.isAccessibilitySize || narrowPane }
    private var editingNotes: Bool {
        marginOnly || (tablet && session.marginOpen && !focus && (!expandedPresentation || !session.showingDocument) && (activeMargin || expandedPresentation))
    }
    private var notesAlignment: TextAlignment {
        if draft.state.textAlignment == 1 { return .center }
        return (draft.state.textAlignment == 0) == (direction == .rightToLeft) ? .leading : .trailing
    }
    private var contextTextStyle: StudioTextStyle {
        editingNotes ? StudioTextStyle(size: draft.state.textSize, color: draft.state.textColor, alignment: draft.state.textAlignment)
            : draft.state.documentTextStyles?[session.page] ?? pdf.textStyle(on: session.page)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            if !focus && !notesFocused { TayyaPageNavigator(session: session) { navigation.sheet = .pages } }
            GeometryReader { geo in
                Group {
                    if marginOnly {
                        marginPanel.padding(16)
                    } else if tablet {
                        tabletContent(size: geo.size)
                    } else {
                        documentPanel.padding(.horizontal, 12).padding(.vertical, 8)
                    }
                }.onChange(of: geo.size.width, initial: true) { _, width in
                    narrowPane = width < StudioMetrics.documentMinimum + StudioMetrics.notesMinimum + 3 * StudioMetrics.spacing
                }
            }
            if !focus && !notesFocused {
                StudioRecordingStrip(session: session, navigation: navigation)
                if tool == "pen" { inkRail }
                else if tool == "text" { textRail }
                else if tool == "select" { selectionRail }
                toolDock
            }
        }.background(StudioTheme.background)
            .onAppear {
                fraction = CGFloat(draft.state.split)
                if marginOnly { activeMargin = true }
                else if !session.marginOpen || (expandedPresentation && session.showingDocument) { activeMargin = false }
                else if expandedPresentation { activeMargin = true }
                currentCanvas.configure(tool: draft.state.currentPen.brush, color: draft.state.currentPen.color, width: CGFloat(draft.state.currentPen.width))
                syncInkToolbar()
                documentInk.onActivate = { activeMargin = false }
                marginInk.onActivate = { activeMargin = true }
                documentInk.onStroke = { session.markWriting(L("خط يد في المستند", "Document handwriting")) }
                marginInk.onStroke = { session.markWriting(L("خط يد في الملاحظات", "Notes handwriting")) }
                documentInk.onDrawingChange = { draft.state.documentInk = documentInk.view.drawing.dataRepresentation() }
                marginInk.onDrawingChange = { draft.state.marginInk = marginInk.view.drawing.dataRepresentation() }
                navigation.onColorPick = { value in
                    if tool == "text" { var style = contextTextStyle; style.color = value; setTextStyle(style) }
                    else { inkColor = value; updateInk() }
                }
            }
            .onChange(of: activeMargin) { _, _ in syncInkToolbar() }
            .onChange(of: editingNotes) { _, _ in syncInkToolbar() }
            .onChange(of: navigation.scene) { _, _ in activeMargin = marginOnly; syncInkToolbar() }
            .onDisappear {
                documentInk.onActivate = nil; marginInk.onActivate = nil
                documentInk.onStroke = nil; marginInk.onStroke = nil
                documentInk.onDrawingChange = nil; marginInk.onDrawingChange = nil
                navigation.onColorPick = nil
            }
            .onChange(of: session.marginOpen) { _, open in if !open { activeMargin = false } else { session.showingDocument = false } }
            .onChange(of: notesFocused) { _, focused in if focused { activeMargin = true } }
            .onChange(of: fraction) { _, value in draft.state.split = Double(value) }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.16), value: tool)
            .onChange(of: navigation.preset) { _, value in
                guard value > 0 else { return }
                let index = max(0, min(2, value - 1))
                let preset = draft.state.pens[index]
                inkColor = preset.color; inkWidth = CGFloat(preset.width); inkTool = preset.brush
                updateInk()
                navigation.preset = 0
            }
    }
    private var header: some View {
        HStack(spacing: 4) {
            TayyaIconButton(title: L("الرجوع للمكتبة", "Back to library"), symbol: "chevron.backward") { navigation.scene = .library }
            VStack(alignment: .leading, spacing: 2) {
                Text(marginOnly ? L("ملاحظات الصفحة \(session.page)", "Page \(session.page) notes") : L("مبادئ المحاسبة", "Accounting principles"))
                    .font(.subheadline.weight(.semibold)).lineLimit(verticalClass == .compact ? 1 : 2)
                StudioSaveStatus(draft: draft)
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
    @ViewBuilder private func tabletContent(size: CGSize) -> some View {
        let railWidth: CGFloat = sidebar && !focus && size.width > 1000 && !typeSize.isAccessibilitySize ? 132 : 0
        let available = size.width - railWidth - 2 * StudioMetrics.spacing - StudioMetrics.spacing
        let needsExpansion = typeSize.isAccessibilitySize || available < StudioMetrics.documentMinimum + StudioMetrics.notesMinimum
        if session.marginOpen && !focus && (needsExpansion || session.notesExpanded) {
            VStack(spacing: StudioMetrics.compact) {
                HStack {
                    Button { session.showingDocument.toggle(); activeMargin = !session.showingDocument } label: {
                        Label(session.showingDocument ? L("عرض الملاحظات", "Show Notes") : L("عرض المستند", "Show document"), systemImage: session.showingDocument ? "note.text" : "doc")
                            .font(.subheadline).padding(.horizontal, StudioMetrics.inset).frame(minHeight: StudioMetrics.touch)
                            .background(StudioTheme.selection, in: Capsule())
                    }.buttonStyle(.plain).accessibilityIdentifier(session.showingDocument ? "showNotes" : "showDocument")
                    Spacer(minLength: StudioMetrics.compact)
                    if !needsExpansion {
                        TayyaIconButton(title: L("العودة إلى التقسيم", "Return to split"), symbol: "rectangle.split.2x1") { session.notesExpanded = false; session.showingDocument = false }
                            .accessibilityIdentifier("notesLayout")
                    }
                }
                if session.showingDocument { documentPanel }
                else { marginPanel.onAppear { activeMargin = true } }
            }.padding(StudioMetrics.spacing)
        } else {
            HStack(spacing: 0) {
                if railWidth > 0 { thumbnails.frame(width: railWidth) }
                if session.marginOpen && !focus {
                    HStack(spacing: 0) {
                        documentPanel.frame(width: max(StudioMetrics.documentMinimum, min(available * fraction, available - StudioMetrics.notesMinimum)))
                        RoundedRectangle(cornerRadius: 3).fill(StudioTheme.divider).frame(width: 4, height: 68)
                            .frame(width: StudioMetrics.spacing).frame(maxHeight: .infinity).contentShape(Rectangle())
                            .gesture(DragGesture().onChanged { value in
                                if dragOrigin == nil { dragOrigin = fraction }
                                let delta = value.translation.width / max(1, available) * (direction == .rightToLeft ? -1 : 1)
                                fraction = min(0.7, max(0.45, (dragOrigin ?? fraction) + delta))
                            }.onEnded { _ in dragOrigin = nil })
                            .accessibilityLabel(L("حجم التقسيم", "Split size"))
                            .accessibilityAdjustableAction { fraction = min(0.7, max(0.45, fraction + ($0 == .increment ? 0.05 : -0.05))) }
                        marginPanel.frame(maxWidth: .infinity)
                    }.padding(StudioMetrics.spacing)
                } else { documentPanel.padding(StudioMetrics.spacing) }
            }
        }
    }
    private var documentPanel: some View {
        ZStack {
            StudioPDFView(page: session.page, controller: pdf)
            if tool == "pen" { StudioInkView(canvas: documentInk) }
        }.background(.white, in: RoundedRectangle(cornerRadius: StudioMetrics.compact))
            .clipShape(RoundedRectangle(cornerRadius: StudioMetrics.compact))
    }
    private var marginPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if typeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 4) {
                        marginHeading
                        HStack { marginPage; Spacer(); notesPanelActions }
                    }
                } else {
                    HStack { marginHeading; Spacer(); marginPage; notesPanelActions }
                }
                Divider()
                TextEditor(text: $draft.state.notes).font(.system(size: CGFloat(draft.state.textSize) * bodyScale / 17))
                    .foregroundStyle(draft.state.textColor == 0x244C43 ? StudioTheme.primary : Color(uiColor: StudioTheme.ui(draft.state.textColor)))
                    .multilineTextAlignment(notesAlignment)
                    .focused($notesFocused).scrollContentBackground(.hidden)
                    .frame(height: typeSize.isAccessibilitySize ? 300 : 180).accessibilityIdentifier("marginText")
                    .onChange(of: draft.state.notes) { _, text in session.markWriting(String(text.suffix(50))) }
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
                    StudioInkView(canvas: marginInk, editable: tool == "pen")
                }.frame(height: tablet ? 220 : 180)
                Label(L("مرتبط بالمستند · صفحة \(session.page)", "Linked to document · Page \(session.page)"), systemImage: "link")
                    .font(.caption2).foregroundStyle(StudioTheme.secondary)
            }
        }.studioCard()
    }
    private var thumbnails: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: StudioMetrics.inset) {
                    Text(L("الصفحات", "PAGES")).font(.caption.weight(.semibold)).foregroundStyle(StudioTheme.secondary)
                    ForEach(1...session.totalPages, id: \.self) { page in
                        Button { session.changePage(to: page) } label: {
                            StudioPageThumbnail(page: page, selected: session.page == page, store: pdf.thumbnails)
                        }.buttonStyle(.plain).accessibilityLabel(L("الصفحة \(page)", "Page \(page)"))
                            .accessibilityAddTraits(page == session.page ? .isSelected : []).id(page)
                    }
                }.padding(StudioMetrics.spacing)
            }.onAppear { proxy.scrollTo(session.page, anchor: .center) }
                .onChange(of: session.page) { _, page in proxy.scrollTo(page, anchor: .center) }
        }.background(StudioTheme.selection.opacity(0.35))
    }
    private var inkRail: some View {
        TayyaToolbar {
            if tablet && session.marginOpen && !marginOnly && !expandedPresentation {
                Button { activeMargin.toggle() } label: {
                    Label(activeMargin ? L("الملاحظات", "Notes") : L("المستند", "Document"), systemImage: activeMargin ? "note.text" : "doc")
                        .font(.caption).padding(.horizontal, 8).frame(minHeight: 44).background(StudioTheme.selection, in: RoundedRectangle(cornerRadius: 10))
                }.buttonStyle(.plain).accessibilityIdentifier("inkTarget").accessibilityValue(activeMargin ? "margin" : "document")
            }
            Menu {
                ForEach(["pen", "pencil", "highlighter"], id: \.self) { ink in
                    Button(ink == "pen" ? L("حبر", "Ink") : ink == "pencil" ? L("رصاص", "Pencil") : L("تظليل", "Highlight")) { inkTool = ink; updateInk() }
                }
            } label: {
                Image(systemName: inkTool == "highlighter" ? "highlighter" : inkTool == "pencil" ? "pencil" : "pencil.tip")
                    .font(.system(size: StudioMetrics.icon)).frame(width: StudioMetrics.touch, height: StudioMetrics.touch)
                    .background(StudioTheme.selection, in: RoundedRectangle(cornerRadius: StudioMetrics.controlRadius))
            }.accessibilityLabel(L("نوع القلم", "Pen type"))
            Button { navigation.sheet = .colors } label: {
                Circle().fill(Color(uiColor: StudioTheme.ui(inkColor))).frame(width: 22, height: 22).padding(11).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel(L("لون القلم", "Ink color")).accessibilityIdentifier("inkColor")
            Menu {
                ForEach([1.5, 3, 6, 12], id: \.self) { width in Button("\(width.formatted()) pt") { inkWidth = CGFloat(width); updateInk() } }
            } label: {
                Text("\(inkWidth, specifier: "%g")").font(.caption.monospacedDigit()).frame(minWidth: StudioMetrics.touch, minHeight: StudioMetrics.touch).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel(L("سماكة القلم", "Pen width"))
            TayyaIconButton(title: L("ممحاة", "Eraser"), symbol: "eraser", selected: inkTool == "eraser") { inkTool = "eraser"; updateInk() }
            TayyaIconButton(title: L("تراجع", "Undo"), symbol: "arrow.uturn.backward") { currentCanvas.view.undoManager?.undo() }
            TayyaIconButton(title: L("إعادة", "Redo"), symbol: "arrow.uturn.forward") { currentCanvas.view.undoManager?.redo() }
            TayyaIconButton(title: L("أقلامي المفضلة", "Favorite pens"), symbol: "star") { navigation.sheet = .pens }.accessibilityIdentifier("favoritePens")
        }
    }
    private var marginHeading: some View {
        Label(L("الملاحظات", "Notes"), systemImage: "note.text").font(.headline)
            .fixedSize(horizontal: true, vertical: true).accessibilityIdentifier("marginHeading")
    }
    private var marginPage: some View {
        Text(L("صفحة \(session.page)", "Page \(session.page)")).font(.caption).foregroundStyle(StudioTheme.secondary)
    }
    private var notesPanelActions: some View {
        HStack(spacing: 0) {
            if notesFocused {
                TayyaIconButton(title: L("إخفاء لوحة المفاتيح", "Dismiss keyboard"), symbol: "keyboard.chevron.compact.down") { notesFocused = false }
                    .accessibilityIdentifier("dismissKeyboard")
            }
            if tablet && !marginOnly && !expandedPresentation {
                TayyaIconButton(title: L("توسيع الملاحظات", "Expand Notes"), symbol: "arrow.up.left.and.arrow.down.right") { session.notesExpanded = true; session.showingDocument = false; activeMargin = true }
                    .accessibilityIdentifier("notesLayout")
            }
            TayyaIconButton(title: L("قوالب الورق", "Paper templates"), symbol: "ellipsis") { navigation.sheet = .templates }
        }
    }
    private var textRail: some View {
        TayyaToolbar {
            Menu {
                ForEach([14.0, 18, 24, 32], id: \.self) { size in Button("\(size.formatted()) pt") { var style = contextTextStyle; style.size = size; setTextStyle(style) } }
            } label: { Text("Aa \(Int(contextTextStyle.size))").font(.subheadline).frame(minWidth: StudioMetrics.touch, minHeight: StudioMetrics.touch) }
                .accessibilityLabel(L("حجم الخط", "Font size"))
            TayyaIconButton(title: L("لون النص", "Text color"), symbol: "paintpalette") { navigation.sheet = .colors }
            Menu {
                Button(L("يمين", "Right")) { var style = contextTextStyle; style.alignment = 0; setTextStyle(style) }
                Button(L("وسط", "Center")) { var style = contextTextStyle; style.alignment = 1; setTextStyle(style) }
                Button(L("يسار", "Left")) { var style = contextTextStyle; style.alignment = 2; setTextStyle(style) }
            } label: { Image(systemName: "text.alignright").frame(width: StudioMetrics.touch, height: StudioMetrics.touch) }
                .accessibilityLabel(L("محاذاة النص", "Text alignment"))
            Button {
                if editingNotes { notesFocused = true }
                else { navigation.sheet = .text }
            } label: {
                Label(L("تعديل النص", "Edit text"), systemImage: "square.and.pencil").font(.caption)
                    .fixedSize().frame(minHeight: StudioMetrics.touch).padding(.horizontal, StudioMetrics.compact)
            }.buttonStyle(.plain).accessibilityIdentifier("editText")
        }
    }
    private var selectionRail: some View {
        TayyaToolbar {
            Button {
                if editingNotes { UIPasteboard.general.string = draft.state.notes }
                else if let page = pdf.view.currentPage { pdf.view.currentSelection = page.selection(for: page.bounds(for: .cropBox)); selectionExists = true }
            } label: {
                Label(editingNotes ? L("نسخ نص الملاحظات", "Copy Notes text") : L("تحديد نص الصفحة", "Select page text"), systemImage: "selection.pin.in.out")
                    .font(.caption).fixedSize().frame(minHeight: StudioMetrics.touch)
            }.buttonStyle(.plain).accessibilityIdentifier("selectText")
            if !editingNotes {
            TayyaIconButton(title: L("نسخ", "Copy"), symbol: "doc.on.doc") { UIPasteboard.general.string = pdf.view.currentSelection?.string }.disabled(!selectionExists)
            TayyaIconButton(title: L("إلغاء التحديد", "Clear selection"), symbol: "xmark") { pdf.view.currentSelection = nil; selectionExists = false }
            }
        }
    }
    private var toolDock: some View {
        Group {
            if typeSize >= .accessibility3 {
                ScrollView(.horizontal, showsIndicators: true) {
                    HStack(spacing: StudioMetrics.compact) { toolButtons }.fixedSize(horizontal: true, vertical: false)
                }.accessibilityIdentifier("toolDockScroll")
            } else if typeSize.isAccessibilitySize && verticalClass != .compact {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: tablet ? 5 : 3), spacing: 8) { toolButtons }
            } else { HStack(spacing: 0) { toolButtons } }
        }.padding(.horizontal, 12).padding(.vertical, 8).background(StudioTheme.surface)
    }
    private var toolButtons: some View {
            ForEach(["pen", "text", "select", "margin", "pages"], id: \.self) { item in
                let titles = ["pen": L("قلم", "Pen"), "text": L("نص", "Text"), "select": L("تحديد", "Select"), "margin": L("الملاحظات", "Notes"), "pages": L("صفحات", "Pages")]
                let symbols = ["pen": "pencil.tip", "text": "textformat", "select": "lasso", "margin": "note.text", "pages": "square.grid.2x2"]
                Button { chooseTool(item) } label: {
                    VStack(spacing: 4) {
                        Image(systemName: symbols[item] ?? "pencil").font(.system(size: 19))
                        if verticalClass != .compact { Text(titles[item] ?? item).font(.caption2).fixedSize(horizontal: true, vertical: true) }
                    }.padding(.horizontal, 4).frame(maxWidth: .infinity, minHeight: verticalClass == .compact ? StudioMetrics.touch : 52)
                        .foregroundStyle((marginOnly && item == "margin") || tool == item ? StudioTheme.primary : StudioTheme.secondary)
                        .background((marginOnly && item == "margin") || tool == item ? StudioTheme.selection : Color.clear, in: RoundedRectangle(cornerRadius: 12))
                        .contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityIdentifier("tool-\(item)").accessibilityLabel(titles[item] ?? item)
            }
    }
    private var currentCanvas: StudioCanvas { editingNotes ? marginInk : documentInk }
    private func syncInkToolbar() { inkTool = currentCanvas.brush; inkColor = currentCanvas.color; inkWidth = currentCanvas.width }
    private func updateInk() {
        currentCanvas.configure(tool: inkTool, color: inkColor, width: inkWidth)
        draft.state.currentPen = StudioPenPreset(brush: inkTool, color: inkColor, width: Double(inkWidth))
    }
    private func setTextStyle(_ style: StudioTextStyle) {
        if editingNotes {
            draft.state.textSize = style.size
            draft.state.textColor = style.color
            draft.state.textAlignment = style.alignment
        } else {
            var styles = draft.state.documentTextStyles ?? [:]
            styles[session.page] = style
            draft.state.documentTextStyles = styles
            let text = pdf.text(on: session.page)
            if !text.isEmpty {
                pdf.updateText(text, size: style.size, color: style.color, alignment: style.alignment, page: session.page)
                draft.state.pdf = pdf.view.document?.dataRepresentation()
            }
        }
    }
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
