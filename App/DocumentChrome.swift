import SwiftUI
import PDFKit

enum TayyaEditingTarget: String { case document, notes }

/// Presentation only: all tools bind to the retained production editor owners.
struct DocumentChrome: View {
    @ObservedObject var localization = TayyaLocalization.shared
    @ObservedObject var workspace: PDFWorkspace
    @ObservedObject var margins: MarginPages
    @ObservedObject var editor: MarginEditorState
    let notesControl: MarginCanvasControl
    @Binding var target: TayyaEditingTarget
    let notesVisible: Bool
    let notesExpanded: Bool
    let chooseNotes: () -> Void
    let openPages: () -> Void
    let dismissPageKeyboard: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.verticalSizeClass) private var verticalClass
    @State private var selectingPDFText = false
    @State private var lastNotesBrush: InkBrush = .pen

    private var editsNotes: Bool { target == .notes && notesVisible }
    private var saveState: PDFWorkspace.SaveState {
        if workspace.saveState == .failed || margins.error != nil || !margins.saved { return .failed }
        return workspace.saveState
    }
    private var tool: PDFWorkspace.Tool {
        if editsNotes { return editor.handwriting ? (editor.brush == .selection ? .lasso : .ink) : .text }
        return selectingPDFText ? .lasso : workspace.tool
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                if notesVisible {
                    Menu {
                        Button("المستند", systemImage: "doc.text") { target = .document }
                        Button("الملاحظات", systemImage: "note.text") { target = .notes }
                    } label: {
                        Image(systemName: editsNotes ? "note.text" : "doc.text")
                            .font(.system(size: TayyaMetrics.icon))
                            .frame(width: TayyaMetrics.touch, height: TayyaMetrics.touch)
                    }.accessibilityLabel("موضع الكتابة").accessibilityIdentifier("inkTarget")
                        .accessibilityValue(editsNotes ? "notes" : "document")
                }
                contextualRail
                Image(systemName: saveState == .failed ? "exclamationmark.circle" : saveState == .saving ? "arrow.triangle.2.circlepath" : "checkmark.circle")
                    .font(.system(size: 13))
                    .foregroundStyle(saveState == .failed ? TayyaTheme.destructive : TayyaTheme.detail)
                    .frame(width: 24, height: TayyaMetrics.touch)
                    .accessibilityLabel(TayyaLocalized(saveState == .failed ? "لم يُحفظ" : saveState == .saving ? "جارٍ الحفظ" : "محفوظ على الجهاز"))
                    .accessibilityValue(saveState.rawValue)
                    .accessibilityIdentifier("saveStatus")
            }
            .frame(height: TayyaMetrics.touch)
            .accessibilityElement(children: .contain).accessibilityIdentifier("studioContextRail")
            .background(TayyaTheme.surface)
            .overlay(alignment: .top) { TayyaTheme.separator.frame(height: 0.5) }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: TayyaMetrics.unit) {
                    coreButton("قلم", symbol: "pencil.tip", selected: tool == .ink) {
                        dismissPageKeyboard(); selectingPDFText = false
                        if editsNotes {
                            editor.handwriting = true; editor.drawing = true
                            if editor.brush == .selection { editor.brush = lastNotesBrush }
                        } else { workspace.tool = workspace.tool == .ink ? .read : .ink }
                    }.accessibilityIdentifier("inkTool").accessibilityValue(String(workspace.inkStrokeCount))
                    coreButton("نص", symbol: "textformat", selected: tool == .text) {
                        dismissPageKeyboard(); selectingPDFText = false
                        if editsNotes { editor.handwriting = false }
                        else { workspace.tool = .text }
                    }.accessibilityIdentifier("textTool")
                    coreButton("تحديد", symbol: "lasso", selected: tool == .lasso) {
                        dismissPageKeyboard(); selectingPDFText = false
                        if editsNotes {
                            if editor.brush != .selection { lastNotesBrush = editor.brush }
                            editor.handwriting = true; editor.drawing = true; editor.brush = .selection
                        }
                        else { workspace.tool = .lasso }
                    }.accessibilityIdentifier("selectTool")
                    coreButton("الملاحظات", symbol: "note.text", selected: notesVisible, action: chooseNotes)
                        .accessibilityIdentifier("openMargin")
                    coreButton("صفحات", symbol: "square.grid.2x2", selected: false, action: openPages)
                        .accessibilityIdentifier("documentPages")
                }.padding(.horizontal, TayyaMetrics.inset).padding(.vertical, TayyaMetrics.unit)
            }
            .frame(height: typeSize >= .accessibility3 || verticalClass == .compact ? 52 : 60)
            .accessibilityIdentifier("studioToolDock").background(TayyaTheme.surface)
        }
        .onChange(of: editor.handwriting) { _, _ in if notesVisible { target = .notes } }
    }

    @ViewBuilder private var contextualRail: some View {
        switch tool {
        case .ink:
            if editsNotes {
                InkToolbar(brush: $editor.brush, color: $editor.color, width: $editor.width,
                           allowsWidthFit: true, compact: true, action: notesControl.action)
            } else {
                InkToolbar(brush: $workspace.brush, color: $workspace.inkColor, width: $workspace.inkWidth,
                           compact: true) { action in
                    if action == "fit" { workspace.fit() } else { workspace.inkAction?(action) }
                }
            }
        case .text:
            TayyaToolbar {
                if editsNotes {
                    WorkspaceToolHint(text: "اكتب في الملاحظات. تُحفظ تغييراتك على الجهاز.")
                } else {
                    TayyaIconButton(title: "تنسيق النص", symbol: "textformat.size") {
                        workspace.editing = workspace.texts.first { $0.page == workspace.page - 1 }
                            ?? PageText(page: workspace.page - 1, x: 40, y: 80)
                    }.accessibilityIdentifier("editText")
                    WorkspaceToolHint(text: "المس الصفحة لإضافة نص، واضغط مرتين على نصك لتعديله.")
                }
            }
        case .lasso:
            TayyaToolbar {
                if editsNotes {
                    WorkspaceToolHint(text: "حدّد الكتابة بالقلم لتحريكها أو نسخها.")
                    TayyaIconButton(title: "تراجع", symbol: "arrow.uturn.backward") { notesControl.action("undo") }
                    TayyaIconButton(title: "إعادة", symbol: "arrow.uturn.forward") { notesControl.action("redo") }
                } else {
                    Menu {
                        Button("تحديد نص الصفحة") {
                            workspace.tool = .read; selectingPDFText = true
                            if let page = workspace.document.page(at: workspace.page - 1) {
                                workspace.view?.currentSelection = page.selection(for: page.bounds(for: .cropBox))
                            }
                        }
                        Button("تحديد الكتابة بالقلم") { selectingPDFText = false; workspace.tool = .lasso }
                    } label: { Image(systemName: "selection.pin.in.out").frame(width: 44, height: 44) }
                        .accessibilityLabel("نوع التحديد").accessibilityIdentifier("selectText")
                    if selectingPDFText {
                        TayyaIconButton(title: "نسخ", symbol: "doc.on.doc") { UIPasteboard.general.string = workspace.view?.currentSelection?.string }
                        TayyaIconButton(title: "إلغاء التحديد", symbol: "xmark") { workspace.view?.currentSelection = nil }
                    } else {
                        ForEach([("يسار", "left", "arrow.left"), ("يمين", "right", "arrow.right"), ("أعلى", "up", "arrow.up"), ("أسفل", "down", "arrow.down"), ("تكبير", "grow", "arrow.up.left.and.arrow.down.right"), ("تصغير", "shrink", "arrow.down.right.and.arrow.up.left"), ("نسخ", "copy", "doc.on.doc"), ("لصق", "paste", "doc.on.clipboard")], id: \.1) { title, action, symbol in
                            TayyaIconButton(title: title, symbol: symbol) { workspace.inkAction?(action) }
                                .accessibilityIdentifier("selectionAction-" + action)
                        }
                    }
                }
            }
        case .read:
            WorkspaceToolHint(text: "اختر أداة للكتابة أو واصل القراءة")
                .padding(.horizontal, TayyaMetrics.inset)
        }
    }

    private func coreButton(_ title: String, symbol: String, selected: Bool, action: @escaping () -> Void) -> some View {
        WorkspaceAction(title: title, symbol: symbol, selected: selected, action: action)
    }
}

/// Large reading fonts belong in a readable panel, outside the fixed tool rail.
private struct WorkspaceToolHint: View {
    let text: String
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var showing = false
    var body: some View {
        Button { showing = true } label: {
            HStack(spacing: TayyaMetrics.compact) {
                Image(systemName: "info.circle").font(.system(size: TayyaMetrics.icon))
                    .frame(width: TayyaMetrics.touch, height: TayyaMetrics.touch)
                if !typeSize.isAccessibilitySize {
                    Text(TayyaLocalized(text)).font(.caption).lineLimit(1)
                }
                Spacer(minLength: 0)
            }.frame(minWidth: TayyaMetrics.touch, minHeight: TayyaMetrics.touch)
                .contentShape(Rectangle()).foregroundStyle(TayyaTheme.detail)
        }.buttonStyle(.plain).frame(minWidth: TayyaMetrics.touch, minHeight: TayyaMetrics.touch)
            .accessibilityLabel(TayyaLocalized(text)).accessibilityIdentifier("workspaceToolHelp")
            .sheet(isPresented: $showing) {
                NavigationStack {
                    ScrollView { Text(TayyaLocalized(text)).font(.body).frame(maxWidth: .infinity, alignment: .leading).padding(TayyaMetrics.section) }
                        .background(TayyaTheme.paper).navigationTitle(TayyaLocalized("أدوات الدراسة"))
                        .toolbar { Button(TayyaLocalized("تم")) { showing = false }.frame(minWidth: 44, minHeight: 44) }
                }.presentationDetents(typeSize.isAccessibilitySize ? [.large] : [.medium, .large])
            }
    }
}
