import SwiftUI
import PencilKit

struct MarginPane: View {
    @ObservedObject var store: MarginPages
    @ObservedObject var editor: MarginEditorState
    let sourcePage: Int
    let expanded: Bool
    let toggleExpanded: () -> Void
    let jump: (Int) -> Void
    let inkSaved: (Int, UUID) -> Void
    let textSaved: (String, UUID) -> Void
    @StateObject private var canvasControl = MarginCanvasControl()
    @State private var showPages = false
    @State private var exported: URL?
    @State private var deletingPage: UUID?
    @State private var confirmMarginDeletion = false
    @FocusState private var textFocused: Bool
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        // Parent diagnostics retain the original boundary trace; content observes directly below.
        let handwriting = editor.handwriting
        let _ = traceMarginRender("body snapshot=\(handwriting)")
        GeometryReader { geometry in
            let _ = traceMarginRender("geometry snapshot=\(handwriting) live=\(editor.handwriting) size=\(geometry.size)")
            // The height offered by a portrait split can be smaller than landscape.
            let compactChrome = verticalSizeClass == .compact || geometry.size.height < 350
            MarginPaneContent(store: store, editor: editor, sourcePage: sourcePage,
                expanded: expanded, compactChrome: compactChrome, toggleExpanded: toggleExpanded,
                jump: jump, inkSaved: inkSaved, textSaved: textSaved, canvasControl: canvasControl,
                showPages: $showPages, exported: $exported, deletingPage: $deletingPage,
                confirmMarginDeletion: $confirmMarginDeletion, textFocused: $textFocused)
        }
        // Text and handwriting have distinct native editor hosts. Recreate
        // only this geometry subtree when switching modes; retained models
        // and page controls above it keep their identity.
        .id(editor.handwriting)
        .background(TayyaTheme.paper)
            .sheet(isPresented: $showPages) { MarginPageList(store: store, sourcePage: sourcePage, jump: jump) }
            .sheet(isPresented: Binding(get: { exported != nil }, set: { if !$0 { exported = nil } })) { if let exported { ShareDocument(url: exported) } }
            .alert("حفظ الحاشية", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
                Button("حاول الحفظ مجددًا") { _ = store.flush() }; Button("حسنًا", role: .cancel) { }
            } message: { Text(store.error ?? "") }
            .confirmationDialog("نقل صفحة الحاشية إلى المحذوفات؟", isPresented: $confirmMarginDeletion, titleVisibility: .visible) {
                Button("حذف صفحة الحاشية", role: .destructive) { if let id = deletingPage { _ = store.delete(id) }; deletingPage = nil; confirmMarginDeletion = false }
                Button("إلغاء", role: .cancel) { deletingPage = nil }
            } message: { Text("يمكنك استعادتها مع نصها وخط اليد من قائمة صفحات الحاشية.") }
            .onChange(of: editor.handwriting) { old, new in
                traceMarginRender("onChange old=\(old) new=\(new)")
                textFocused = false
            }
            .onDisappear { _ = store.flush() }
            .onChange(of: scenePhase) { _, phase in if phase != .active { _ = store.flush() } }
    }
    private func traceMarginRender(_ event: String) {
        #if DEBUG
        guard ProcessInfo.processInfo.arguments.contains("--test-margin-viewport") else { return }
        MarginRenderDiagnostics.record(event + "; editor=\(ObjectIdentifier(editor)); store=\(ObjectIdentifier(store)); pane=\(ObjectIdentifier(canvasControl)); focus=\(textFocused); main=\(Thread.isMainThread)", control: canvasControl)
        #endif
    }
}

// GeometryReader may retain its content when only the injected editor changes.
// Observe the retained models where the actual text/ink subtree is consumed.
private struct MarginPaneContent: View {
    @ObservedObject var store: MarginPages
    @ObservedObject var editor: MarginEditorState
    let sourcePage: Int
    let expanded: Bool
    let compactChrome: Bool
    let toggleExpanded: () -> Void
    let jump: (Int) -> Void
    let inkSaved: (Int, UUID) -> Void
    let textSaved: (String, UUID) -> Void
    let canvasControl: MarginCanvasControl
    @Binding var showPages: Bool
    @Binding var exported: URL?
    @Binding var deletingPage: UUID?
    @Binding var confirmMarginDeletion: Bool
    @FocusState.Binding var textFocused: Bool
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var body: some View {
        let handwriting = editor.handwriting
        let _ = traceMarginRender("content snapshot=\(handwriting) compact=\(compactChrome)")
        VStack(spacing: 0) {
            header(compactChrome: compactChrome)
            if let page = store.current {
                #if DEBUG
                let _ = traceMarginRender("page branch page=\(page.id) current=\(store.currentID?.uuidString ?? "missing") live=\(editor.handwriting)")
                #endif
                modeControls(compactChrome: compactChrome)
                if editor.handwriting {
                    #if DEBUG
                    let _ = traceMarginRender("toolbar branch live=\(editor.handwriting)")
                    #endif
                    inkControls
                }
                if editor.handwriting {
                    #if DEBUG
                    let _ = traceMarginRender("notebook branch page=\(page.id) live=\(editor.handwriting)")
                    #endif
                    MarginNotebook(page: page, drawing: editor.drawing, brush: editor.brush, color: editor.color, width: editor.width, control: canvasControl,
                                   saved: { ink in
                        store.saveInk(ink, page: page.id)
#if DEBUG
                        MarginCountTiming.record("store-save-returned", canvas: canvasControl.canvas,
                                                 pageID: page.id, detail: "saved=\(store.saved); inputCount=\(ink.strokes.count)")
#endif
                        if store.saved { inkSaved(ink.strokes.count, page.id) }
                    }, failed: { store.error = $0 })
                } else {
                    #if DEBUG
                    let _ = traceMarginRender("text branch page=\(page.id) live=\(editor.handwriting)")
                    #endif
                    TextEditor(text: Binding(get: { store.pages.first { $0.id == page.id }?.text ?? "" },
                                             set: { value in store.editText(value, page: page.id); if store.saved { textSaved(value, page.id) } }))
                        .font(.title3).padding(8).scrollContentBackground(.hidden)
                        .background(TayyaTheme.paper).accessibilityIdentifier("splitNotes").focused($textFocused)
                }
                if !textFocused && !compactChrome { footer(page) }
            } else {
                ContentUnavailableView("تعذّر فتح الحاشية", systemImage: "exclamationmark.doc", description: Text("لم يتم استبدال بياناتك. أغلق المستند وأعد فتحه."))
            }
        }
    }
    private func traceMarginRender(_ event: String) {
        #if DEBUG
        guard ProcessInfo.processInfo.arguments.contains("--test-margin-viewport") else { return }
        MarginRenderDiagnostics.record(event + "; editor=\(ObjectIdentifier(editor)); store=\(ObjectIdentifier(store)); pane=\(ObjectIdentifier(canvasControl)); focus=\(textFocused); main=\(Thread.isMainThread)", control: canvasControl)
        #endif
    }
    private func modeControls(compactChrome: Bool) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                MarginModeControl(handwriting: Binding(get: { editor.handwriting }, set: { value in
                    traceMarginRender("binding before requested=\(value) live=\(editor.handwriting)")
                    editor.handwriting = value
                    traceMarginRender("binding after live=\(editor.handwriting)")
                    textFocused = false
                }))
                .fixedSize(horizontal: true, vertical: true)
                if editor.handwriting {
                    Button { editor.drawing.toggle() } label: {
                        ViewThatFits(in: .horizontal) {
                            Label(editor.drawing ? "تحريك" : "كتابة", systemImage: editor.drawing ? "hand.draw" : "pencil.tip")
                                .fixedSize(horizontal: true, vertical: true)
                            Image(systemName: editor.drawing ? "hand.draw" : "pencil.tip")
                        }
                        .font(.subheadline.weight(.medium)).frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                    }.buttonStyle(.plain).foregroundStyle(TayyaTheme.ink)
                    .accessibilityLabel(editor.drawing ? "تحريك" : "كتابة").accessibilityIdentifier("marginPan")
                }
            }.padding(.horizontal, compactChrome ? 8 : 12)
                .padding(.vertical, compactChrome ? 2 : 6)
        }
    }
    private var inkControls: some View {
        InkToolbar(brush: $editor.brush, color: $editor.color, width: $editor.width, allowsWidthFit: true, action: canvasControl.action)
            .frame(minHeight: 44)
    }
    private func header(compactChrome: Bool) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            headerControls(compactChrome: compactChrome)
        }.background(TayyaTheme.surface).foregroundStyle(TayyaTheme.ink)
    }
    private func headerControls(compactChrome: Bool) -> some View {
        HStack(spacing: 6) {
            Button { store.move(-1) } label: {
                marginHeaderTarget("السابق في الحاشية", symbol: "chevron.right")
            }.disabled(store.position == 0).accessibilityIdentifier("previousMarginPage")
            Button { showPages = true } label: {
                VStack(spacing: 2) {
                    Text("الحاشية").font(.headline).foregroundStyle(TayyaTheme.text)
                    Text("\(store.position + 1) من \(store.pages.count)").font(.caption).monospacedDigit().foregroundStyle(TayyaTheme.detail)
                }.fixedSize(horizontal: true, vertical: true)
                    .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
            }.accessibilityIdentifier("marginPages").accessibilityValue("\(store.position + 1)/\(store.pages.count)")
            Button { store.move(1) } label: {
                marginHeaderTarget("التالي في الحاشية", symbol: "chevron.left")
            }.disabled(store.position + 1 >= store.pages.count).accessibilityIdentifier("nextMarginPage")
            Spacer(minLength: 0)
            Button { _ = store.add(linkedTo: sourcePage) } label: {
                marginHeaderTarget("إضافة صفحة حاشية", symbol: "plus")
            }.accessibilityIdentifier("addMarginPage")
            Button { toggleExpanded() } label: {
                marginHeaderTarget(expanded ? "العودة إلى المستند" : "تكبير الحاشية",
                    symbol: expanded ? "rectangle.split.2x1" : "arrow.up.left.and.arrow.down.right")
            }.accessibilityIdentifier("expandMargin")
            if compactChrome, let page = store.current {
                TayyaTheme.separator.frame(width: 1, height: 28).accessibilityHidden(true)
                if let linked = page.sourcePage {
                    Button { jump(linked) } label: {
                        Label("المستند · ص \(linked)", systemImage: "link")
                            .font(.caption).frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                    }
                }
                Button { do { exported = try store.export() } catch { store.error = error.localizedDescription } } label: {
                    marginHeaderTarget("تصدير", symbol: "square.and.arrow.up")
                }
                Button { deletingPage = page.id; confirmMarginDeletion = true } label: {
                    marginHeaderTarget("حذف", symbol: "trash")
                }.disabled(store.pages.count <= 1).accessibilityIdentifier("deleteMarginPage")
                Button { showPages = true } label: {
                    marginHeaderTarget("المحذوفات", symbol: "trash.circle")
                }.accessibilityIdentifier("deletedMarginPages")
                Text(store.saved ? "محفوظ" : "لم يُحفظ")
                    .font(.caption).foregroundStyle(store.saved ? TayyaTheme.ink : Color.red)
            }
        }.buttonStyle(.plain).padding(.horizontal, 8).background(TayyaTheme.surface)
    }
    private func marginHeaderTarget(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol).labelStyle(.iconOnly)
            .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
    }
    private func footer(_ page: MarginPage) -> some View {
        VStack(spacing: 0) {
            if verticalSizeClass != .compact { HStack {
                if let linked = page.sourcePage {
                    Button { jump(linked) } label: {
                        Label("المستند · ص \(linked)", systemImage: "link")
                            .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                    }.buttonStyle(.plain).foregroundStyle(TayyaTheme.ink)
                }
                else { Text("حاشية عامة").foregroundStyle(.secondary) }
                Spacer()
                Label(store.saved ? "محفوظ" : "لم يُحفظ", systemImage: store.saved ? "checkmark.circle" : "exclamationmark.circle").foregroundStyle(store.saved ? TayyaTheme.ink : Color.red)
            }.font(.caption).padding(.horizontal, 12).padding(.top, 4) }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    WorkspaceAction(title: "تصدير", symbol: "square.and.arrow.up") { do { exported = try store.export() } catch { store.error = error.localizedDescription } }
                    WorkspaceAction(title: "حذف", symbol: "trash") { deletingPage = page.id; confirmMarginDeletion = true }.disabled(store.pages.count <= 1).accessibilityIdentifier("deleteMarginPage")
                    WorkspaceAction(title: "المحذوفات", symbol: "trash.circle") { showPages = true }.accessibilityIdentifier("deletedMarginPages")
                }.padding(.horizontal, 8)
            }
        }.background(TayyaTheme.surface)
    }

}
// Read-only, bounded native diagnostics. This buffer is not observable and never
// writes view/model state or sends a publisher event. XCTest retrieves it through
// the public AX label getter, so app stdout transport is not required.
#if DEBUG
@MainActor enum MarginRenderDiagnostics {
    private static var events: [String] = []
    private static var sequence = 0
    private static weak var currentControl: MarginCanvasControl?
    static func record(_ event: String, control: MarginCanvasControl? = nil) {
        guard ProcessInfo.processInfo.arguments.contains("--test-margin-viewport") else { return }
        if let control { currentControl = control }
        sequence += 1
        events.append("\(sequence): " + event)
        if events.count > 80 { events.removeFirst(events.count - 80) }
    }
    static func recordCanvas(_ event: String, canvas: MarginCanvas) {
        guard ProcessInfo.processInfo.arguments.contains("--test-margin-viewport") else { return }
        record(event + "; " + canvasState(canvas))
    }
    private static func canvasState(_ canvas: MarginCanvas) -> String {
        "canvas=\(ObjectIdentifier(canvas)); window=\(canvas.window != nil); superview=\(canvas.superview != nil); bounds=\(canvas.bounds); windowFrame=\(canvas.convert(canvas.bounds, to: canvas.window)); hidden=\(canvas.isHidden); alpha=\(canvas.alpha); responder=\(canvas.isFirstResponder)"
    }
    private static func childSample(_ view: UIView, limit: Int) -> String {
        let children = view.subviews
        let sample = children.prefix(limit).map {
            "\(type(of: $0)) id=\(ObjectIdentifier($0)) window=\($0.window != nil) frame=\($0.frame)"
        }
        return "total=\(children.count) omitted=\(max(0, children.count - limit)) [" + sample.joined(separator: " | ") + "]"
    }
    static var labelSuffix: String {
        guard ProcessInfo.processInfo.arguments.contains("--test-margin-viewport") else { return "" }
        let live: String
        if let control = currentControl {
            if let canvas = control.canvas {
                var ancestors: [String] = []
                var next = canvas.superview
                while let view = next, ancestors.count < 8 {
                    ancestors.append("\(type(of: view)) id=\(ObjectIdentifier(view)) frame=\(view.frame) bounds=\(view.bounds) hidden=\(view.isHidden) alpha=\(view.alpha) clips=\(view.clipsToBounds); children=" + childSample(view, limit: 4))
                    next = view.superview
                }
                live = "control=\(ObjectIdentifier(control)); " + canvasState(canvas)
                    + "; children=" + childSample(canvas, limit: 4)
                    + "; siblings=" + (canvas.superview.map { childSample($0, limit: 6) } ?? "none")
                    + "; ancestors=[" + ancestors.joined(separator: " > ") + "]; ancestorsCapped=\(next != nil)"
            } else { live = "control=\(ObjectIdentifier(control)); canvas=nil" }
        } else { live = "control=nil; canvas=unknown" }
        let trace = events.joined(separator: " | ")
        let prefix = "; MarginNativeLive=[" + live + "]; totalEvents=\(sequence); retainedEvents=\(events.count); evictedEvents=\(sequence - events.count); ringCap=80; labelCap=24000"
        // Leave room for the static Arabic label and the explicit truncation marker.
        let budget = max(0, 23800 - prefix.count)
        return prefix + "; traceTruncated=\(trace.count > budget); MarginRenderTrace=[" + String(trace.prefix(budget)) + "]"
    }
}
#else
private enum MarginRenderDiagnostics {
    static func record(_ event: String) {}
    static var labelSuffix: String { "" }
}
#endif

#if DEBUG
private final class TracedMarginModeControl: UISegmentedControl {
    override var accessibilityLabel: String? {
        get { String(((super.accessibilityLabel ?? "") + MarginRenderDiagnostics.labelSuffix).prefix(24000)) }
        set { super.accessibilityLabel = newValue }
    }
}
#endif

// Explicit native valueChanged delivery writes the existing retained editor.
// The accessibility value reads the binding, rather than reporting UI selection.
private struct MarginModeControl: UIViewRepresentable {
    @Binding var handwriting: Bool
    private let titles = ["نص", "خط اليد"]

    func makeCoordinator() -> Coordinator { Coordinator(handwriting: $handwriting) }

    func makeUIView(context: Context) -> UISegmentedControl {
        let control: UISegmentedControl
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--test-margin-viewport") {
            control = TracedMarginModeControl(items: titles)
        } else { control = UISegmentedControl(items: titles) }
        #else
        control = UISegmentedControl(items: titles)
        #endif
        control.accessibilityIdentifier = "marginMode"
        control.accessibilityLabel = "طريقة تدوين الحاشية"
        control.semanticContentAttribute = .forceRightToLeft
        control.apportionsSegmentWidthsByContent = false
        control.selectedSegmentTintColor = UIColor(TayyaTheme.ink)
        control.addTarget(context.coordinator, action: #selector(Coordinator.modeChanged(_:)), for: .valueChanged)
        configure(control, context: context)
        return control
    }

    func updateUIView(_ control: UISegmentedControl, context: Context) {
        #if DEBUG
        MarginRenderDiagnostics.record("mode updateUIView enter control=\(ObjectIdentifier(control)); handwriting=\(handwriting)")
        #endif
        context.coordinator.handwriting = $handwriting
        configure(control, context: context)
        #if DEBUG
        MarginRenderDiagnostics.record("mode updateUIView return control=\(ObjectIdentifier(control)); handwriting=\(handwriting)")
        #endif
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UISegmentedControl, context: Context) -> CGSize? {
        let font = titleFont(context.environment.dynamicTypeSize)
        let maxTitleWidth = titles.map { ($0 as NSString).size(withAttributes: [.font: font]).width }.max() ?? 0
        #if DEBUG
        MarginRenderDiagnostics.record("mode sizeThatFits control=\(ObjectIdentifier(uiView)); handwriting=\(handwriting); proposalWidth=\(String(describing: proposal.width)); proposalHeight=\(String(describing: proposal.height)); fontLineHeight=\(font.lineHeight); maxTitleWidth=\(maxTitleWidth)")
        #endif
        return CGSize(width: ceil(max(44, maxTitleWidth + 24) * CGFloat(titles.count)),
                      height: ceil(max(44, font.lineHeight + 8)))
    }

    private func configure(_ control: UISegmentedControl, context: Context) {
        control.selectedSegmentIndex = handwriting ? 1 : 0
        control.accessibilityValue = handwriting ? "handwriting" : "text"
        let font = titleFont(context.environment.dynamicTypeSize)
        control.setTitleTextAttributes([.font: font, .foregroundColor: UIColor(TayyaTheme.text)], for: .normal)
        control.setTitleTextAttributes([.font: font, .foregroundColor: UIColor(TayyaTheme.paper)], for: .selected)
        #if DEBUG
        MarginRenderDiagnostics.record("mode configure before invalidate control=\(ObjectIdentifier(control)); handwriting=\(handwriting); frame=\(control.frame)")
        #endif
        control.invalidateIntrinsicContentSize()
        #if DEBUG
        MarginRenderDiagnostics.record("mode configure after invalidate control=\(ObjectIdentifier(control)); handwriting=\(handwriting); frame=\(control.frame)")
        #endif
    }

    private func titleFont(_ size: DynamicTypeSize) -> UIFont {
        let category: UIContentSizeCategory
        switch size {
        case .xSmall: category = .extraSmall
        case .small: category = .small
        case .medium: category = .medium
        case .large: category = .large
        case .xLarge: category = .extraLarge
        case .xxLarge: category = .extraExtraLarge
        case .xxxLarge: category = .extraExtraExtraLarge
        case .accessibility1: category = .accessibilityMedium
        case .accessibility2: category = .accessibilityLarge
        case .accessibility3: category = .accessibilityExtraLarge
        case .accessibility4: category = .accessibilityExtraExtraLarge
        case .accessibility5: category = .accessibilityExtraExtraExtraLarge
        @unknown default: category = .large
        }
        return UIFont.preferredFont(forTextStyle: .subheadline,
            compatibleWith: UITraitCollection(preferredContentSizeCategory: category))
    }

    final class Coordinator: NSObject {
        var handwriting: Binding<Bool>
        init(handwriting: Binding<Bool>) { self.handwriting = handwriting }
        @objc func modeChanged(_ control: UISegmentedControl) {
            handwriting.wrappedValue = control.selectedSegmentIndex == 1
            control.accessibilityValue = handwriting.wrappedValue ? "handwriting" : "text"
        }
    }
}

struct MarginPageList: View {
    @ObservedObject var store: MarginPages
    let sourcePage: Int
    let jump: (Int) -> Void
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                if let page = store.current {
                    Section("الصفحة الحالية") {
                        TextField("عنوان اختياري", text: Binding(get: { store.current?.title ?? "" }, set: { store.editTitle($0, page: page.id) }))
                        if let linked = page.sourcePage {
                            Button("الانتقال إلى المستند · ص \(linked)", systemImage: "doc.text") { jump(linked); dismiss() }
                        }
                        Button("ربط بصفحة المستند \(sourcePage)", systemImage: "link") { store.linkCurrent(to: sourcePage) }
                            .accessibilityIdentifier("linkMarginPage")
                        Button("فك ربط الصفحة", systemImage: "link.slash") { store.linkCurrent(to: nil) }
                            .disabled(page.sourcePage == nil).accessibilityIdentifier("unlinkMarginPage")
                    }
                }
                Section("صفحات الحاشية") {
                    ForEach(store.pages) { page in
                        Button {
                            if store.select(page.id) { dismiss() }
                        } label: {
                            HStack(spacing: 12) {
                                thumbnail(page)
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(page.title.isEmpty ? "الحاشية \((store.pages.firstIndex { $0.id == page.id } ?? 0) + 1)" : page.title).font(.headline)
                                    Text(page.sourcePage.map { "مرتبطة بصفحة \($0)" } ?? "حاشية عامة").font(.caption).foregroundStyle(.secondary)
                                    if !page.text.isEmpty { Text(page.text).lineLimit(2).font(.caption).foregroundStyle(.secondary) }
                                }
                                Spacer()
                                if page.id == store.currentID { Image(systemName: "checkmark.circle.fill").foregroundStyle(TayyaTheme.ink) }
                            }
                        }.foregroundStyle(.primary).swipeActions {
                            Button("حذف", role: .destructive) { _ = store.delete(page.id) }.disabled(store.pages.count <= 1)
                        }
                    }
                }
                if !store.deletedPages.isEmpty {
                    Section("صفحات محذوفة — قابلة للاستعادة") {
                        ForEach(store.deletedPages) { page in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(page.title.isEmpty ? "صفحة حاشية" : page.title)
                                    Text(page.text).font(.caption).lineLimit(2).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("استعادة", systemImage: "arrow.uturn.backward") { if store.restore(page.id) { dismiss() } }.accessibilityIdentifier("restoreMarginPage")
                            }
                        }
                    }
                }
            }.navigationTitle("صفحات الحاشية").toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("تم") { dismiss() } }
                ToolbarItem(placement: .primaryAction) { Button("صفحة جديدة", systemImage: "plus") { if store.add(linkedTo: sourcePage) { dismiss() } } }
            }
        }.environment(\.layoutDirection, .rightToLeft)
    }
    @ViewBuilder private func thumbnail(_ page: MarginPage) -> some View {
        if let drawing = try? PKDrawing(data: page.ink), !drawing.strokes.isEmpty {
            Image(uiImage: drawing.image(from: CGRect(x: 0, y: 0, width: page.width, height: page.height), scale: 0.15))
                .resizable().scaledToFit().frame(width: 48, height: 64).background(PaperColor.cream.uiColor.swiftUIColor)
        } else { Image(systemName: "doc.text").font(.title).frame(width: 48, height: 64).foregroundStyle(TayyaTheme.ink) }
    }
}
private extension UIColor { var swiftUIColor: Color { Color(uiColor: self) } }
