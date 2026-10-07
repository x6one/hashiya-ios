import SwiftUI
import UniformTypeIdentifiers

struct LibraryScreen: View {
    @EnvironmentObject private var store: LibraryStore
    @State private var importing = false
    @State private var creating = false
    @State private var title = "دفتر جديد"
    @State private var query = ""
    @State private var showTrash = false
    @State private var section: String?
    @State private var moving: Notebook?
    @State private var renaming: Notebook?
    @State private var deleting: Notebook?
    @State private var managing = false
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var favorites = false
    @State private var backup = false
    @State private var reviewing = false
    @State private var hits: [SearchHit] = []
    @State private var searching = false
    @State private var route: SearchHit?
    @State private var importMessage: String?
    @State private var importingFile = false
    @State private var demonstration: Notebook?
    private var filtered: [Notebook] {
        store.notebooks.filter { $0.trashed == showTrash && (section == nil || showTrash || $0.section == section) && (!favorites || $0.favorite) }
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
            .safeAreaInset(edge: .bottom) {
                if let importMessage {
                    Text(importMessage).font(.callout).padding(12).frame(maxWidth: .infinity)
                        .background(.regularMaterial).accessibilityIdentifier("importStatus")
                }
            }
            .onOpenURL { url in importing = false; finishPicking([url]) }
            .onChange(of: store.sections) { _, sections in
                if let section, !sections.contains(section) { self.section = nil }
            }
            .sheet(isPresented: $creating) { CreateNotebookScreen(store: store, section: section) }
            .sheet(isPresented: $reviewing) { LibraryCardsScreen(library: store) }
            .sheet(isPresented: $backup) { BackupScreen(store: store) }
            .navigationDestination(item: $route) { hit in NotebookScreen(id: hit.notebook, store: store, initialPage: hit.page) }
            .navigationDestination(item: $demonstration) { note in NotebookScreen(id: note.id, store: store) }
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
            .alert("تسمية الملف", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
                TextField("الاسم", text: $title)
                Button("حفظ") { if let note = renaming, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { store.change(note.id) { $0.title = title } }; renaming = nil }
                Button("إلغاء", role: .cancel) { renaming = nil }
            }
            .confirmationDialog("حذف الملف وتعليقاته وتسجيلاته نهائيًا؟", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
                Button("حذف نهائي", role: .destructive) { if let note = deleting { store.permanentlyDelete(note) }; deleting = nil }
            }
            .sheet(item: $moving) { note in
                NavigationStack { List(store.sections, id: \.self) { name in Button(name) { store.change(note.id) { $0.section = name }; moving = nil } }.navigationTitle("نقل إلى قسم").toolbar { Button("إلغاء") { moving = nil } } }.environment(\.layoutDirection, .rightToLeft)
            }
            .sheet(isPresented: $managing) { SectionsScreen().environmentObject(store) }
            .alert("تعذّر إكمال العملية", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) { Button("حسناً") { store.error = nil } } message: { Text(store.error ?? "") }
    }
    private var libraryNavigation: some View {
        HStack(spacing: 0) {
            if sizeClass == .regular { librarySidebar.frame(width: 220); Divider() }
            libraryContent
        }
        .background(TayyaTheme.paper)
            .navigationTitle("طَيّة").searchable(text: $query, prompt: "ابحث في دفاترك")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button("استيراد", systemImage: "square.and.arrow.down") { importing = true }
                        .accessibilityIdentifier("importDocument").disabled(importingFile)
                    Button("دفتر جديد", systemImage: "plus") { title = "دفتر جديد"; creating = true }
                        .accessibilityIdentifier("createNotebook")



                }
            }
    }
    private var libraryContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(showTrash ? "المحذوفات" : "صفحاتك، بطريقتك.").font(.title.weight(.semibold)).foregroundStyle(TayyaTheme.ink)
                    Text(showTrash ? "استعد ملفاتك أو احذفها نهائيًا." : "اقرأ، دوّن، واترك أثر فكرتك.").foregroundStyle(.secondary)
                }.padding(.vertical, 18)
                if !showTrash {
                    Button {
                        do { demonstration = try store.installDemonstration() }
                        catch { store.error = error.localizedDescription }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "play.rectangle").font(.title2)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("جرّب طَيّة بملفات جاهزة").font(.headline)
                                Text("دليل PDF ودفتر وحواشٍ وعرض تقديمي — دون حساب").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.left")
                        }.frame(maxWidth: .infinity, alignment: .leading).padding(16)
                            .background(TayyaTheme.surface, in: RoundedRectangle(cornerRadius: 14))
                    }.buttonStyle(.plain).foregroundStyle(TayyaTheme.ink).accessibilityIdentifier("openDemonstration")
                }
                if sizeClass != .regular {
                    HStack {
                        Button("الأقسام", systemImage: "folder") { managing = true }.accessibilityIdentifier("librarySections")
                        Spacer()
                        Button(showTrash ? "المكتبة" : "المحذوفات", systemImage: showTrash ? "books.vertical" : "trash") { showTrash.toggle(); favorites = false }
                            .accessibilityIdentifier("libraryTrash")
                    }.buttonStyle(.bordered).frame(minHeight: 44)
                    HStack {
                        Button("بطاقات المراجعة", systemImage: "rectangle.stack") { reviewing = true }
                        Spacer()
                        Button("نسخ احتياطي", systemImage: "externaldrive") { backup = true }
                    }.font(.subheadline).frame(minHeight: 44)
                }
                if !showTrash {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            Button("الكل") { section = nil; favorites = false }.buttonStyle(.bordered)
                            Button("المفضلة", systemImage: "star") { favorites.toggle(); section = nil }.buttonStyle(.bordered)
                            ForEach(store.sections, id: \.self) { name in
                                Button(name) { section = name; favorites = false }.buttonStyle(.bordered).tint(section == name ? TayyaTheme.ink : TayyaTheme.ink.opacity(0.55))
                            }
                        }
                    }
                }
                if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    if searching { ProgressView("جارٍ البحث في الملفات…") }
                    else if hits.isEmpty { ContentUnavailableView.search(text: query) }
                    ForEach(hits) { hit in
                        Button { route = hit } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(hit.title).font(.headline)
                                if let page = hit.page { Text("صفحة \(page)").font(.caption) }
                                Text(hit.snippet).font(.subheadline).lineLimit(3)
                            }.frame(maxWidth: .infinity, alignment: .leading).padding().background(TayyaTheme.surface, in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                } else {
                if filtered.isEmpty { ContentUnavailableView("لا توجد ملفات هنا", systemImage: "books.vertical", description: Text("استورد ملفًا أو أنشئ دفترًا جديدًا.")) }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 18)], spacing: 18) {
                    ForEach(filtered) { note in
                        notebookCard(note)
                    }
                }
                }
                Text("By Ahmad Al-awi").font(.footnote).foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.top, 24)
            }.padding(24)
        }
    }
    private var librarySidebar: some View {
        List {
            Button("كل الملفات", systemImage: "books.vertical") { showTrash = false; favorites = false; section = nil }
            Button("المفضلة", systemImage: "star") { showTrash = false; favorites = true; section = nil }
            Section("الأقسام") {
                ForEach(store.sections, id: \.self) { name in Button(name, systemImage: "folder") { showTrash = false; favorites = false; section = name } }
                Button("إدارة الأقسام", systemImage: "folder.badge.gearshape") { managing = true }.accessibilityIdentifier("librarySections")
            }
            Button("المحذوفات", systemImage: "trash") { showTrash = true; favorites = false; section = nil }.accessibilityIdentifier("libraryTrash")
            Button("بطاقات المراجعة", systemImage: "rectangle.stack") { reviewing = true }
            Button("النسخ الاحتياطي", systemImage: "externaldrive") { backup = true }
        }.listStyle(.sidebar)
    }
    private func notebookCard(_ note: Notebook) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            NavigationLink {
                NotebookScreen(id: note.id, store: store)
            } label: {
                VStack(alignment: .leading, spacing: 14) {
                    HStack { Image(systemName: note.file.lowercased().hasSuffix(".pdf") ? "doc.richtext" : "doc.text").font(.system(size: 30, weight: .light)); Spacer(); if note.favorite { Image(systemName: "star.fill").foregroundStyle(TayyaTheme.fold).font(.caption) } }.padding(.bottom, 10)
                    Text(note.title).font(.title3.weight(.medium)).lineLimit(2)
                    Text(note.section + " · " + (note.file as NSString).pathExtension.uppercased()).font(.caption).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, minHeight: 140, alignment: .leading).padding(22)
            }.disabled(showTrash)
            Divider()
            HStack {
                if showTrash {
                    Button("استعادة") { store.change(note.id) { $0.trashed = false } }
                    Spacer()
                    Button("حذف نهائي", role: .destructive) { deleting = note }
                } else {
                    Button("نقل") { moving = note }.frame(minHeight: 44)
                    Spacer()
                    Menu {
                        Button("تسمية") { title = note.title; renaming = note }
                        Button(note.favorite ? "إلغاء المفضلة" : "للمفضلة") { store.change(note.id) { $0.favorite.toggle() } }
                        Button("نقل للمحذوفات", role: .destructive) { store.change(note.id) { $0.trashed = true } }
                    } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44) }.accessibilityLabel("خيارات " + note.title)
                }
            }.font(.subheadline).padding(.horizontal, 20).padding(.vertical, 10)
        }.background(TayyaTheme.surface, in: RoundedRectangle(cornerRadius: 18)).overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(TayyaTheme.ink.opacity(0.08)) }
    }
    private func finishPicking(_ urls: [URL]) {
        guard !importingFile, !urls.isEmpty else { return }
        importingFile = true
        importMessage = "جارٍ استيراد الملف…"
        Task { @MainActor in
            defer { importingFile = false }
            var imported = 0
            var failures: [String] = []
            let destination = section
            for url in urls {
                do {
                    try await store.importDocumentAsync(url, section: destination)
                    DocumentPicker.discardIncomingCopy(url)
                    imported += 1
                }
                catch { failures.append(url.lastPathComponent + ": " + error.localizedDescription) }
            }
            if imported > 0 { showTrash = false; query = "" }
            if failures.isEmpty {
                importMessage = urls.count == 1 ? "تم استيراد " + urls[0].deletingPathExtension().lastPathComponent : "تم استيراد \(imported) ملفات"
            } else {
                importMessage = (imported > 0 ? "تم استيراد \(imported). " : "") + "لم يتم الاستيراد: " + failures.joined(separator: "\n")
            }

        }
    }

}
struct SectionsScreen: View {
    @EnvironmentObject private var store: LibraryStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    var body: some View {
        NavigationStack {
            List {
                Section { HStack { TextField("اسم القسم", text: $name); Button("إضافة") { store.addSection(name); name = "" }.disabled(name.trimmingCharacters(in: .whitespaces).isEmpty) } }
                Section("حذف القسم ينقل ملفاته إلى مكتبتي") {
                    ForEach(store.sections, id: \.self) { section in
                        HStack { Text(section); Spacer(); if section != "مكتبتي" { Button("حذف", role: .destructive) { store.deleteSection(section) } } }
                    }
                }
            }.navigationTitle("الأقسام").toolbar { Button("تم") { dismiss() } }
        }.environment(\.layoutDirection, .rightToLeft)
    }
}
