import SwiftUI
import UniformTypeIdentifiers

struct LibraryScreen: View {
    var allowsInitialWelcome: Bool = true
    @EnvironmentObject private var store: LibraryStore
    @State private var importing = false
    @State private var creating = false
    @State private var title = "دفتر جديد"
    @State private var query = ""
    @State private var showTrash = false
    @State private var section: String? = "مكتبتي"
    @State private var moving: Notebook?
    @State private var renaming: Notebook?
    @State private var showNotebookRename = false
    @State private var deleting: Notebook?
    @State private var confirmNotebookDeletion = false
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.tayyaReduceMotion) private var reduceMotion
    @State private var favorites = false
    @State private var backup = false
    @State private var destination: LibraryDestination = .library
    @State private var sectionName = ""
    @AppStorage("tayya.library.lastOpenedNotebook") private var lastOpenedNotebook = ""
    @State private var hits: [SearchHit] = []
    @State private var searching = false
    @State private var route: SearchHit?
    @State private var importMessage: String?
    @State private var importingFile = false
    @State private var demonstration: Notebook?
    @AppStorage("tayya.welcomeSeen") private var welcomeSeen = false
    @State private var welcome = false
    // Session-only UI gating keeps external intake/status ahead of onboarding.
    @State private var receivedExternalFile = false
    private var filtered: [Notebook] {
        store.visibleNotebooks(section: section, trash: showTrash, favorites: favorites)
    }
    var body: some View {
        NavigationStack { libraryPresentation }
            .tint(TayyaTheme.ink).environment(\.layoutDirection, .rightToLeft)
            // Files owns localization. Its host is outside the forced Arabic
            // content layout, with a single native presentation lifecycle.
            .sheet(isPresented: $importing) {
                DocumentPicker { urls in
                    importing = false
                    finishPicking(urls)
                }.ignoresSafeArea()
            }
    }
    private var libraryPresentation: some View {
        libraryNavigation
            .onAppear { presentInitialWelcomeIfNeeded() }
            .onChange(of: allowsInitialWelcome) { _, allowed in
                if allowed { presentInitialWelcomeIfNeeded() }
            }
            .sheet(isPresented: $welcome) {
                WelcomeScreen(start: { welcomeSeen = true; welcome = false }, demonstrate: {
                    do { demonstration = try store.installDemonstration(); welcomeSeen = true; welcome = false }
                    catch { store.error = error.localizedDescription }
                }, error: store.error)
            }
            .safeAreaInset(edge: .bottom) {
                if let importMessage {
                    Text(importMessage).font(.callout).padding(12).frame(maxWidth: .infinity)
                        .background(.regularMaterial).accessibilityIdentifier("importStatus")
                }
            }
            .onOpenURL { url in
                receivedExternalFile = true
                welcome = false
                importing = false
                finishPicking([url])
            }
            .onChange(of: store.sections) { _, sections in
                if let section, !sections.contains(section) { self.section = "مكتبتي" }
            }
            .sheet(isPresented: $creating) { CreateNotebookScreen(store: store, section: section) }
            .sheet(isPresented: $backup) { BackupScreen(store: store) }
            .navigationDestination(item: $route) { hit in NotebookScreen(id: hit.notebook, store: store, initialPage: hit.page) }
            .navigationDestination(item: $demonstration) { note in NotebookScreen(id: note.id, store: store).onAppear { lastOpenedNotebook = note.id.uuidString } }
            .task(id: query) {
                guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { hits = []; searching = false; return }
                searching = true
                do {
                    try await Task.sleep(for: .milliseconds(250))
                    let notes = store.notebooks, root = store.root, term = query
                    let results = try await Task.detached(priority: .userInitiated) { try LibrarySearch.find(term, notes: notes, root: root) }.value
                    try Task.checkCancellation()
                    hits = results; searching = false
                } catch { if !Task.isCancelled { searching = false; store.error = error.localizedDescription } }
            }
            .alert("تسمية الملف", isPresented: $showNotebookRename) {
                TextField("الاسم", text: $title).accessibilityIdentifier("renameNotebookTitle")
                Button("حفظ") { if let note = renaming, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { store.change(note.id) { $0.title = title } }; renaming = nil; showNotebookRename = false }
                Button("إلغاء", role: .cancel) { renaming = nil }
            }
            .confirmationDialog("حذف الملف وتعليقاته وتسجيلاته نهائيًا؟", isPresented: $confirmNotebookDeletion, titleVisibility: .visible) {
                Button("حذف نهائي", role: .destructive) { if let note = deleting { store.permanentlyDelete(note) }; deleting = nil; confirmNotebookDeletion = false }
                Button("إلغاء", role: .cancel) { deleting = nil }
            }
            .sheet(item: $moving) { note in
                NavigationStack { List(store.sections, id: \.self) { name in Button(name) { store.change(note.id) { $0.section = name }; moving = nil } }.navigationTitle("نقل إلى قسم").toolbar { Button("إلغاء") { moving = nil } } }.environment(\.layoutDirection, .rightToLeft)
            }
            .alert("تعذّر إكمال العملية", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) { Button("حسناً") { store.error = nil } } message: { Text(store.error ?? "") }
    }
    private func presentInitialWelcomeIfNeeded() {
        guard allowsInitialWelcome, !receivedExternalFile, !welcomeSeen, store.notebooks.isEmpty,
              !importing, !importingFile else { return }
        welcome = true
    }
    private var libraryNavigation: some View {
        HStack(spacing: 0) {
            if sizeClass == .regular {
                librarySidebar.frame(width: dynamicTypeSize.isAccessibilitySize ? 280 : 220)
                Rectangle().fill(TayyaTheme.separator).frame(width: 1)
            }
            Group {
                switch destination {
                case .library: libraryContent
                case .sections: sectionsContent
                case .review: LibraryReviewDestination(library: store)
                case .settings: settingsContent
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(TayyaTheme.paper)
        .foregroundStyle(TayyaTheme.text)
        .navigationTitle(destination == .library ? libraryTitle : destination.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(TayyaTheme.paper, for: .navigationBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if sizeClass != .regular { destinationBar }
        }
        .toolbar {
            if destination == .sections {
                ToolbarItem(placement: .confirmationAction) {
                    Button("تم") { selectDestination(.library) }
                }
            }
        }
    }
    private var libraryTitle: String {
        showTrash ? "المحذوفات" : favorites ? "المفضلة" : section == "مكتبتي" ? "مكتبتك" : section ?? "كل الملفات"
    }
    private var recentNotebook: Notebook? {
        filtered.first { $0.id.uuidString == lastOpenedNotebook }
    }
    private func selectDestination(_ value: LibraryDestination) {
        destination = value
        query = ""
        if value == .library { showTrash = false }
    }
    private var destinationBar: some View {
        HStack(spacing: 0) {
            ForEach(LibraryDestination.allCases) { item in
                Button { selectDestination(item) } label: {
                    VStack(spacing: 4) {
                        Image(systemName: item.symbol).font(.system(size: 18, weight: .medium))
                        Text(item.title).font(.caption.weight(destination == item ? .semibold : .regular))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .foregroundStyle(destination == item ? TayyaTheme.ink : TayyaTheme.detail)
                    .background(destination == item ? TayyaTheme.selection : Color.clear, in: RoundedRectangle(cornerRadius: 10))
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: destination == item)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(item.accessibilityID)
                .accessibilityAddTraits(destination == item ? .isSelected : [])
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(TayyaTheme.surface)
        .overlay(alignment: .top) { Rectangle().fill(TayyaTheme.separator).frame(height: 0.5) }
    }
    private var libraryContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TayyaMetrics.section) {
                libraryHeading
                if !showTrash {
                    libraryActions
                    if let note = recentNotebook, query.isEmpty {
                        NavigationLink {
                            NotebookScreen(id: note.id, store: store).onAppear { lastOpenedNotebook = note.id.uuidString }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "book.closed").font(.title3)
                                    .frame(width: 44, height: 44)
                                    .background(TayyaTheme.surface, in: RoundedRectangle(cornerRadius: 10))
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("تابع القراءة").font(.caption).foregroundStyle(TayyaTheme.detail)
                                    Text(note.title).font(.subheadline.weight(.semibold))
                                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.left").font(.caption)
                            }.padding(12).background(TayyaTheme.selection, in: RoundedRectangle(cornerRadius: 14))
                        }.buttonStyle(LibraryPressStyle()).accessibilityIdentifier("continueNotebook")
                    }
                    libraryFilters
                }
                HStack {
                    Text(showTrash ? "يمكنك استعادة الملفات المحذوفة." : "\(filtered.count) ملف").font(.caption).foregroundStyle(TayyaTheme.detail)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    Button(showTrash ? "المكتبة" : "المحذوفات", systemImage: showTrash ? "books.vertical" : "trash") {
                        showTrash.toggle(); favorites = false
                    }.font(.caption).frame(minHeight: 44).accessibilityIdentifier("libraryTrash")
                }
                if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    if searching { ProgressView("جارٍ البحث في الملفات…") }
                    else if hits.isEmpty { ContentUnavailableView.search(text: query) }
                    ForEach(hits) { hit in
                        Button { route = hit; lastOpenedNotebook = hit.notebook.uuidString } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(hit.title).font(.headline).foregroundStyle(TayyaTheme.text)
                                if let page = hit.page { Text("صفحة \(page)").font(.caption).foregroundStyle(TayyaTheme.copper) }
                                Text(hit.snippet).font(.subheadline).foregroundStyle(TayyaTheme.detail)
                                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 3)
                            }.frame(maxWidth: .infinity, alignment: .leading).padding().background(TayyaTheme.surface, in: RoundedRectangle(cornerRadius: 12))
                        }.buttonStyle(LibraryPressStyle())
                    }
                } else {
                    if filtered.isEmpty {
                        ContentUnavailableView(showTrash ? "لا توجد ملفات محذوفة" : "لا توجد ملفات هنا", systemImage: showTrash ? "trash" : "books.vertical", description: Text(showTrash ? "ستظهر هنا الملفات التي تنقلها للمحذوفات." : "استورد ملفًا أو أنشئ دفترًا جديدًا."))
                    }
                    LazyVGrid(columns: gridColumns, alignment: .leading, spacing: 16) {
                        ForEach(filtered) { note in notebookCard(note) }
                    }
                }
            }.padding(sizeClass == .regular ? TayyaMetrics.section : TayyaMetrics.spacing)
                .frame(maxWidth: 1060).frame(maxWidth: .infinity)
        }.searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "ابحث في دفاترك")
    }
    private var gridColumns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize { return [GridItem(.flexible())] }
        return sizeClass == .regular ? [GridItem(.adaptive(minimum: 180, maximum: 250), spacing: 16)] : [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    }
    private var libraryHeading: some View {
        VStack(alignment: .leading, spacing: TayyaMetrics.compact) {
            TayyaBrand()
            Text(libraryTitle).font(.largeTitle.weight(.bold)).foregroundStyle(TayyaTheme.text)
                .fixedSize(horizontal: false, vertical: true)
            if !showTrash {
                Text("مساحة للقراءة والكتابة").font(.subheadline).foregroundStyle(TayyaTheme.detail)
            }
        }.accessibilityElement(children: .combine).accessibilityAddTraits(.isHeader)
    }
    private var libraryActions: some View {
        let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(spacing: 10))
        return layout {
            Button { creating = true } label: {
                Label("دفتر جديد", systemImage: "plus").frame(maxWidth: .infinity, minHeight: 44)
                    .fixedSize(horizontal: false, vertical: true)
            }.buttonStyle(TayyaPrimaryButtonStyle()).accessibilityIdentifier("createNotebook")
            Button { importing = true } label: {
                Label("استيراد ملف", systemImage: "square.and.arrow.down").frame(maxWidth: .infinity, minHeight: 44)
                    .fixedSize(horizontal: false, vertical: true)
            }.buttonStyle(.bordered).accessibilityIdentifier("importDocument").disabled(importingFile)
        }.font(.subheadline.weight(.semibold))
    }
    private var libraryFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterButton("المكتبة", selected: section == "مكتبتي" && !favorites) { section = "مكتبتي"; favorites = false }
                    .accessibilityIdentifier("libraryRoot")
                filterButton("كل الملفات", selected: section == nil && !favorites) { section = nil; favorites = false }
                filterButton("المفضلة", selected: favorites) { favorites = true; section = nil }
                ForEach(store.sections.filter { $0 != "مكتبتي" }, id: \.self) { name in
                    filterButton(name, selected: section == name && !favorites) { section = name; favorites = false }
                }
            }
        }
    }
    private func filterButton(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(title, action: action).font(.subheadline.weight(selected ? .semibold : .regular))
            .fixedSize(horizontal: true, vertical: true)
            .padding(.horizontal, TayyaMetrics.spacing).frame(minHeight: TayyaMetrics.touch)
            .background(selected ? TayyaTheme.selection : TayyaTheme.surface, in: Capsule())
            .buttonStyle(.plain).foregroundStyle(selected ? TayyaTheme.ink : TayyaTheme.detail)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: selected)
            .accessibilityAddTraits(selected ? .isSelected : [])
    }
    private var librarySidebar: some View {
        List {
            Section("طَيّة") {
                ForEach(LibraryDestination.allCases) { item in
                    Button { selectDestination(item) } label: {
                        Label(item.title, systemImage: item.symbol)
                            .font(.body.weight(destination == item ? .semibold : .regular))
                            .frame(minHeight: 44, alignment: .leading)
                            .foregroundStyle(destination == item ? TayyaTheme.ink : TayyaTheme.detail)
                    }
                        .accessibilityIdentifier(item.accessibilityID)
                        .listRowBackground(destination == item ? TayyaTheme.selection : Color.clear)
                        .accessibilityAddTraits(destination == item ? .isSelected : [])
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: destination == item)
                }
            }
            Section("ملفاتك") {
                Button("المكتبة", systemImage: "books.vertical") { selectDestination(.library); section = "مكتبتي"; favorites = false }.accessibilityIdentifier("libraryRootSidebar")
                Button("كل الملفات", systemImage: "square.grid.2x2") { selectDestination(.library); section = nil; favorites = false }
                Button("المفضلة", systemImage: "star") { selectDestination(.library); favorites = true; section = nil }
                ForEach(store.sections.filter { $0 != "مكتبتي" }, id: \.self) { name in
                    Button(name, systemImage: "folder") { selectDestination(.library); favorites = false; section = name }
                }
            }
            Section {
                Button("المحذوفات", systemImage: "trash") { destination = .library; showTrash = true; favorites = false; query = "" }.accessibilityIdentifier("sidebarTrash")
                Button("النسخ الاحتياطي", systemImage: "externaldrive") { backup = true }
            }
        }.listStyle(.sidebar).scrollContentBackground(.hidden)
            .environment(\.defaultMinListRowHeight, 44)
            .background(TayyaTheme.mutedSurface.opacity(0.5))
    }
    private var sectionsContent: some View {
        List {
            Section("قسم جديد") {
                HStack {
                    TextField("اسم القسم", text: $sectionName).accessibilityIdentifier("sectionName")
                    Button("إضافة") { store.addSection(sectionName); sectionName = "" }
                        .frame(minWidth: 44, minHeight: 44)
                        .accessibilityIdentifier("addSection").disabled(sectionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            Section {
                ForEach(store.sections, id: \.self) { name in
                    HStack {
                        Button { selectDestination(.library); section = name; favorites = false } label: {
                            HStack {
                                Label(name, systemImage: "folder")
                                Spacer()
                                Text("\(store.notebooks.filter { !$0.trashed && $0.section == name }.count)").foregroundStyle(.secondary)
                            }.frame(minHeight: 44)
                        }.buttonStyle(.borderless).accessibilityIdentifier("chooseSection-" + name)
                        if name != "مكتبتي" {
                            Button("حذف", role: .destructive) { store.deleteSection(name) }
                                .frame(minWidth: 44, minHeight: 44)
                                .buttonStyle(.borderless).accessibilityIdentifier("deleteSection-" + name)
                        }
                    }
                }
            } footer: { Text("حذف القسم ينقل ملفاته إلى مكتبتي.") }
        }.scrollContentBackground(.hidden).environment(\.defaultMinListRowHeight, 44)
    }
    private var settingsContent: some View {
        List {
            Section("ملفاتك") {
                Button("النسخ الاحتياطي والاستعادة", systemImage: "externaldrive") { backup = true }.accessibilityIdentifier("libraryBackup")
                Button("المحذوفات", systemImage: "trash") { destination = .library; showTrash = true; favorites = false; query = "" }.accessibilityIdentifier("settingsTrash")
            }
            Section("ابدأ مع طَيّة") {
                Button("جرّب ملفات جاهزة", systemImage: "play.rectangle") {
                    do { demonstration = try store.installDemonstration() }
                    catch { store.error = error.localizedDescription }
                }.accessibilityIdentifier("openDemonstration")
                Button("دليل البداية", systemImage: "questionmark.circle") { welcome = true }
            }
            Section("عن طَيّة") {
                Text("ملفاتك وكتابتك وتسجيلاتك محفوظة على جهازك.").font(.subheadline).foregroundStyle(TayyaTheme.detail)
                Text("By Ahmad Al-awi").font(.footnote).foregroundStyle(TayyaTheme.detail)
            }
        }.scrollContentBackground(.hidden).environment(\.defaultMinListRowHeight, 44)
    }
    private func notebookCard(_ note: Notebook) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            NavigationLink {
                NotebookScreen(id: note.id, store: store).onAppear { lastOpenedNotebook = note.id.uuidString }
            } label: {
                VStack(alignment: .leading, spacing: 12) {
                    notebookCover(note)
                    VStack(alignment: .leading, spacing: 8) {
                        if dynamicTypeSize.isAccessibilitySize {
                            Text(note.title).font(.subheadline.weight(.semibold))
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            Text(note.title).font(.subheadline.weight(.semibold))
                                .lineLimit(2, reservesSpace: true)
                        }
                        notebookMetadata(note)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.padding(12).contentShape(Rectangle())
            }.buttonStyle(LibraryPressStyle()).foregroundStyle(TayyaTheme.text).disabled(showTrash).accessibilityIdentifier("openNotebook-" + note.title)
            Rectangle().fill(TayyaTheme.separator).frame(height: 0.5)
            if showTrash {
                VStack(spacing: 0) {
                    Button("استعادة") { store.change(note.id) { $0.trashed = false } }
                        .frame(maxWidth: .infinity, minHeight: 44).accessibilityIdentifier("restoreNotebook-" + note.title)
                    Button("حذف نهائي", role: .destructive) { deleting = note; confirmNotebookDeletion = true }
                        .frame(maxWidth: .infinity, minHeight: 44).accessibilityIdentifier("eraseNotebook-" + note.title)
                }.font(.caption.weight(.medium)).buttonStyle(.borderless)
            } else {
                Menu {
                    Button("تسمية", systemImage: "pencil") { title = note.title; renaming = note; showNotebookRename = true }.accessibilityIdentifier("renameNotebook-" + note.title)
                    Button("نقل إلى قسم", systemImage: "folder") { moving = note }.accessibilityIdentifier("moveNotebook-" + note.title)
                    Button(note.favorite ? "إلغاء المفضلة" : "إضافة للمفضلة", systemImage: note.favorite ? "star.slash" : "star") { store.change(note.id) { $0.favorite.toggle() } }
                    Button("نقل للمحذوفات", systemImage: "trash", role: .destructive) { store.change(note.id) { $0.trashed = true } }.accessibilityIdentifier("trashNotebook-" + note.title)
                } label: {
                    Label("تنظيم الملف", systemImage: "folder.badge.gearshape").font(.caption.weight(.medium))
                        .frame(maxWidth: .infinity, minHeight: 44).padding(.horizontal, 8)
                        .fixedSize(horizontal: false, vertical: true)
                }.accessibilityIdentifier("notebookActions-" + note.title)
            }
        }
        .background(TayyaTheme.surface, in: RoundedRectangle(cornerRadius: TayyaMetrics.cardRadius))
        .overlay { RoundedRectangle(cornerRadius: TayyaMetrics.cardRadius).strokeBorder(TayyaTheme.separator, lineWidth: 0.5) }
    }
    private func notebookCover(_ note: Notebook) -> some View {
        let color = NotebookCoverStyle.color(for: note.id)
        return LibraryThumbnail(url: store.root.appendingPathComponent(note.file))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(TayyaTheme.surface, in: RoundedRectangle(cornerRadius: 3))
            .padding(.leading, 18).padding(.trailing, 12).padding(.vertical, 12)
            .frame(height: dynamicTypeSize.isAccessibilitySize ? 180 : 148)
            .background(color, in: RoundedRectangle(cornerRadius: 9))
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 1).fill(Color.black.opacity(0.18))
                    .frame(width: 3).padding(.vertical, 8).padding(.leading, 6)
                    .accessibilityHidden(true).allowsHitTesting(false)
            }
            .overlay(alignment: .topTrailing) {
                FoldedPageCorner(size: 18, color: TayyaTheme.copper)
            }
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .accessibilityHidden(true)
    }
    private func notebookMetadata(_ note: Notebook) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 5)) : AnyLayout(HStackLayout(spacing: 5))
        return layout {
            HStack(spacing: 4) {
                Text((note.file as NSString).pathExtension.uppercased())
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(TayyaTheme.mutedSurface, in: RoundedRectangle(cornerRadius: 4))
                    .fixedSize()
                if note.favorite {
                    Image(systemName: "star.fill").foregroundStyle(TayyaTheme.copper)
                        .accessibilityLabel("المفضلة")
                }
            }
            Text(note.section).lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }.font(.caption).foregroundStyle(TayyaTheme.detail)
    }
    private func finishPicking(_ urls: [URL]) {
        guard !importingFile, !urls.isEmpty else { return }
        importingFile = true
        importMessage = "جارٍ استيراد الملف…"
        Task { @MainActor in
            defer { importingFile = false }
            var imported = 0
            var failures: [String] = []
            let importSection = section
            for url in urls {
                do {
                    try await store.importDocumentAsync(url, section: importSection)
                    DocumentPicker.discardIncomingCopy(url)
                    imported += 1
                }
                catch { failures.append(url.lastPathComponent + ": " + error.localizedDescription) }
            }
            if imported > 0 { destination = .library; showTrash = false; favorites = false; query = "" }
            if failures.isEmpty {
                importMessage = urls.count == 1 ? "تم استيراد " + urls[0].deletingPathExtension().lastPathComponent : "تم استيراد \(imported) ملفات"
            } else {
                importMessage = (imported > 0 ? "تم استيراد \(imported). " : "") + "لم يتم الاستيراد: " + failures.joined(separator: "\n")
            }

        }
    }

}

/// Feedback belongs to library chrome; it never animates reader or ink geometry.
private struct LibraryPressStyle: ButtonStyle {
    @Environment(\.tayyaReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.78 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
