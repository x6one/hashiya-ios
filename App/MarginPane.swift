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
    @FocusState private var textFocused: Bool
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        VStack(spacing: 0) {
            header
            if let page = store.current {
                if verticalSizeClass == .compact && editor.handwriting {
                    HStack(spacing: 0) { modeControls.frame(width: 195); inkControls }
                } else {
                    modeControls
                    if editor.handwriting { inkControls }
                }
                if editor.handwriting {
                    MarginNotebook(page: page, drawing: editor.drawing, brush: editor.brush, color: editor.color, width: editor.width, control: canvasControl,
                                   saved: { ink in
                        store.saveInk(ink, page: page.id)
                        if store.saved { inkSaved(ink.strokes.count, page.id) }
                    }, failed: { store.error = $0 })
                    .clipped()
                } else {
                    TextEditor(text: Binding(get: { store.pages.first { $0.id == page.id }?.text ?? "" },
                                             set: { value in store.editText(value, page: page.id); if store.saved { textSaved(value, page.id) } }))
                        .font(.system(size: 20)).padding(8).scrollContentBackground(.hidden)
                        .background(TayyaTheme.surface).accessibilityIdentifier("splitNotes").focused($textFocused)
                }
                if !textFocused { footer(page) }
            } else {
                ContentUnavailableView("تعذّر فتح الحاشية", systemImage: "exclamationmark.doc", description: Text("لم يتم استبدال بياناتك. أغلق المستند وأعد فتحه."))
            }
        }.background(TayyaTheme.paper)
            .sheet(isPresented: $showPages) { MarginPageList(store: store, sourcePage: sourcePage, jump: jump) }
            .sheet(isPresented: Binding(get: { exported != nil }, set: { if !$0 { exported = nil } })) { if let exported { ShareDocument(url: exported) } }
            .alert("حفظ الحاشية", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
                Button("حاول الحفظ مجددًا") { _ = store.flush() }; Button("حسنًا", role: .cancel) { }
            } message: { Text(store.error ?? "") }
            .confirmationDialog("نقل صفحة الحاشية إلى المحذوفات؟", isPresented: Binding(get: { deletingPage != nil }, set: { if !$0 { deletingPage = nil } }), titleVisibility: .visible) {
                Button("حذف صفحة الحاشية", role: .destructive) { if let id = deletingPage { _ = store.delete(id) }; deletingPage = nil }
            } message: { Text("يمكنك استعادتها مع نصها وخط اليد من قائمة صفحات الحاشية.") }
            .onChange(of: editor.handwriting) { _, _ in textFocused = false }
            .onDisappear { _ = store.flush() }
            .onChange(of: scenePhase) { _, phase in if phase != .active { _ = store.flush() } }
    }
    private var modeControls: some View {
        HStack(spacing: 8) {
            Picker("طريقة تدوين الحاشية", selection: $editor.handwriting) { Text("نص").tag(false); Text("خط اليد").tag(true) }
                .pickerStyle(.segmented).accessibilityIdentifier("marginMode")
            if editor.handwriting {
                Button(editor.drawing ? "تحريك" : "كتابة", systemImage: editor.drawing ? "hand.draw" : "pencil.tip") { editor.drawing.toggle() }
                    .font(.subheadline).accessibilityIdentifier("marginPan")
            }
        }.padding(.horizontal, 12).padding(.vertical, 6)
    }
    private var inkControls: some View {
        InkToolbar(brush: $editor.brush, color: $editor.color, width: $editor.width, allowsWidthFit: true, action: canvasControl.action)
    }
    private var header: some View {
        HStack(spacing: 6) {
            Button("السابق في الحاشية", systemImage: "chevron.right") { store.move(-1) }
                .labelStyle(.iconOnly).frame(minWidth: 40, minHeight: 44).disabled(store.position == 0).accessibilityIdentifier("previousMarginPage")
            Button { showPages = true } label: {
                VStack(spacing: 2) {
                    Text("الحاشية").font(.headline)
                    Text("\(store.position + 1) من \(store.pages.count)").font(.caption).monospacedDigit()
                }
            }.accessibilityIdentifier("marginPages").accessibilityValue("\(store.position + 1)/\(store.pages.count)")
            Button("التالي في الحاشية", systemImage: "chevron.left") { store.move(1) }
                .labelStyle(.iconOnly).frame(minWidth: 40, minHeight: 44).disabled(store.position + 1 >= store.pages.count).accessibilityIdentifier("nextMarginPage")
            Spacer(minLength: 0)
            Button("إضافة صفحة حاشية", systemImage: "plus") { _ = store.add(linkedTo: sourcePage) }
                .labelStyle(.iconOnly).frame(minWidth: 40, minHeight: 44).accessibilityIdentifier("addMarginPage")
            Button(expanded ? "العودة إلى المستند" : "تكبير الحاشية", systemImage: expanded ? "rectangle.split.2x1" : "arrow.up.left.and.arrow.down.right") { toggleExpanded() }
                .labelStyle(.iconOnly).frame(minWidth: 40, minHeight: 44).accessibilityIdentifier("expandMargin")
        }.padding(.horizontal, 8).background(TayyaTheme.surface)
    }
    private func footer(_ page: MarginPage) -> some View {
        VStack(spacing: 0) {
            if verticalSizeClass != .compact { HStack {
                if let linked = page.sourcePage { Button("المستند · ص \(linked)", systemImage: "link") { jump(linked) } }
                else { Text("حاشية عامة").foregroundStyle(.secondary) }
                Spacer()
                Label(store.saved ? "محفوظ" : "لم يُحفظ", systemImage: store.saved ? "checkmark.circle" : "exclamationmark.circle").foregroundStyle(store.saved ? TayyaTheme.ink : Color.red)
            }.font(.caption).padding(.horizontal, 12).padding(.top, 4) }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    WorkspaceAction(title: "ربط الصفحة", symbol: "link") { store.linkCurrent(to: sourcePage) }
                    WorkspaceAction(title: "فك الربط", symbol: "link.badge.plus") { store.linkCurrent(to: nil) }.disabled(page.sourcePage == nil)
                    WorkspaceAction(title: "تصدير", symbol: "square.and.arrow.up") { do { exported = try store.export() } catch { store.error = error.localizedDescription } }
                    WorkspaceAction(title: "حذف", symbol: "trash") { deletingPage = page.id }.disabled(store.pages.count <= 1).accessibilityIdentifier("deleteMarginPage")
                    WorkspaceAction(title: "المحذوفات", symbol: "trash.circle") { showPages = true }.accessibilityIdentifier("deletedMarginPages")
                }.padding(.horizontal, 8)
            }
        }.background(TayyaTheme.surface)
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
                    Section("عنوان الصفحة الحالية") {
                        TextField("عنوان اختياري", text: Binding(get: { store.current?.title ?? "" }, set: { store.editTitle($0, page: page.id) }))
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
