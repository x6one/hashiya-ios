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
    @State private var showingActions = false
    @State private var importMessage: String?
    @State private var importingFile = false
    private var filtered: [Notebook] {
        store.notebooks.filter { $0.trashed == showTrash && (section == nil || showTrash || $0.section == section) && (query.isEmpty || $0.title.localizedCaseInsensitiveContains(query)) }
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(showTrash ? "المحذوفات" : "فكرة جديدة؟").font(.largeTitle.weight(.semibold))
                        Text(showTrash ? "استعد ملفاتك أو احذفها نهائيًا." : "اترك لأفكارك حاشية.").foregroundStyle(.secondary)
                    }.padding(.vertical, 18)
                    if !showTrash {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                Button("الكل") { section = nil }.buttonStyle(.bordered)
                                ForEach(store.sections, id: \.self) { name in
                                    Button(name) { section = name }.buttonStyle(.bordered).tint(section == name ? .blue : .gray)
                                }
                            }
                        }
                    }
                    if filtered.isEmpty { ContentUnavailableView("لا توجد ملفات هنا", systemImage: "books.vertical", description: Text("استورد ملفًا أو أنشئ دفترًا جديدًا.")) }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 18)], spacing: 18) {
                        ForEach(filtered) { note in
                            VStack(alignment: .leading, spacing: 0) {
                                NavigationLink {
                                    if note.file.lowercased().hasSuffix(".pdf") { DocumentScreen(note: note, root: store.root) }
                                    else { OfficeDocumentScreen(note: note, root: store.root) }
                                } label: {
                                    VStack(alignment: .leading, spacing: 14) {
                                        Image(systemName: note.favorite ? "star.fill" : "book.closed").font(.system(size: 32)).padding(.bottom, 10)
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
                                        Button("نقل") { moving = note }
                                        Spacer()
                                        Menu {
                                            Button("تسمية") { title = note.title; renaming = note }
                                            Button(note.favorite ? "إلغاء المفضلة" : "للمفضلة") { store.change(note.id) { $0.favorite.toggle() } }
                                            Button("نقل للمحذوفات", role: .destructive) { store.change(note.id) { $0.trashed = true } }
                                        } label: { Image(systemName: "ellipsis").frame(width: 44, height: 30) }.accessibilityLabel("خيارات " + note.title)
                                    }
                                }.font(.subheadline).padding(.horizontal, 20).padding(.vertical, 10)
                            }.background(.white, in: RoundedRectangle(cornerRadius: 20))
                        }
                    }
                    Text("By Ahmad Al-awi").font(.footnote).foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.top, 24)
                }.padding(24)
            }.background(Color(red: 0.965, green: 0.964, blue: 0.943))
                .navigationTitle("حاشية").searchable(text: $query, prompt: "ابحث في دفاترك")
                .toolbar {
                    ToolbarItemGroup(placement: .primaryAction) {
                        Button("استيراد", systemImage: "square.and.arrow.down") { importing = true }
                            .accessibilityIdentifier("importDocument").disabled(importingFile)
                        Button("دفتر جديد", systemImage: "plus") { title = "دفتر جديد"; creating = true }
                            .accessibilityIdentifier("createNotebook")
                        Button { showingActions = true } label: {
                            Image(systemName: "ellipsis.circle")
                        }.accessibilityLabel("خيارات المكتبة").accessibilityIdentifier("libraryMenu")

                    }
                }
                .confirmationDialog("خيارات المكتبة", isPresented: $showingActions, titleVisibility: .visible) {
                    Button(showTrash ? "المكتبة" : "المحذوفات") { showTrash.toggle() }
                    Button("إدارة الأقسام") { managing = true }
                    Button("تجربة Office") {
                        do { if let url = Bundle.main.url(forResource: "office-demo", withExtension: "pptx") { try store.importDocument(url, title: "تجربة Office", section: section) } }
                        catch { store.error = error.localizedDescription }
                    }.accessibilityIdentifier("importOfficeDemo")
                    Button("إلغاء", role: .cancel) {}
                }
                .sheet(isPresented: $importing) {
                    DocumentPicker(directory: pickerDirectory, completed: { urls in
                        if let url = urls.first { finishPicking(url) }
                        importing = false
                    }, cancelled: { importing = false })
                    // The remote Files UI manages its own localization. Do not
                    // mirror its UIKit host with our forced Arabic app layout.
                    .environment(\.layoutDirection, .leftToRight)
                }
                .safeAreaInset(edge: .bottom) {
                    if let importMessage {
                        Text(importMessage).font(.callout).padding(12).frame(maxWidth: .infinity)
                            .background(.regularMaterial).accessibilityIdentifier("importStatus")
                    }
                }
                .onOpenURL { url in finishPicking(url) }
                .onChange(of: store.sections) { _, sections in
                    if let section, !sections.contains(section) { self.section = nil }
                }
                .alert("دفتر جديد", isPresented: $creating) { TextField("الاسم", text: $title); Button("إنشاء") { store.create(title.isEmpty ? "دفتر جديد" : title, section: section); query = ""; showTrash = false }; Button("إلغاء", role: .cancel) {} }
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
        }.tint(Color(red: 0.26, green: 0.42, blue: 0.53)).environment(\.layoutDirection, .rightToLeft)
    }
    private var pickerDirectory: URL? {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--test-file-picker") {
            let folder = store.root
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            if let source = Bundle.main.url(forResource: "english", withExtension: "pdf") {
                let target = folder.appendingPathComponent("Picker-fixture.pdf")
                if !FileManager.default.fileExists(atPath: target.path) { try? FileManager.default.copyItem(at: source, to: target) }
            }
            if let source = Bundle.main.url(forResource: "office-demo", withExtension: "pptx") {
                let target = folder.appendingPathComponent("Picker-office.pptx")
                if !FileManager.default.fileExists(atPath: target.path) { try? FileManager.default.copyItem(at: source, to: target) }
            }
            return folder
        }
        #endif
        return nil
    }
    private func finishPicking(_ url: URL) {
        importingFile = true
        importMessage = "جارٍ استيراد الملف…"
        Task { @MainActor in
            defer { importingFile = false }
            do {
                try store.importDocument(url, section: section)
                showTrash = false; query = ""
                importMessage = "تم استيراد " + url.deletingPathExtension().lastPathComponent
            } catch {
                importMessage = "لم يتم الاستيراد: " + error.localizedDescription
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
