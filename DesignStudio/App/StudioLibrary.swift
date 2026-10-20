import SwiftUI

struct StudioNotebook: Identifiable {
    let id = UUID()
    let arabic: String
    let english: String
    let pages: Int
    let tint: Int
    let symbol: String
    var favorite = false
    var title: String { L(arabic, english) }
}

struct TayyaDocumentCard: View {
    let note: StudioNotebook
    let open: () -> Void
    let favorite: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: open) {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 10).fill(Color(uiColor: StudioTheme.ui(note.tint)))
                    VStack(spacing: 12) {
                        Spacer(minLength: 8)
                        Image(systemName: note.symbol).font(.system(size: 29, weight: .light))
                        Rectangle().fill(.white.opacity(0.3)).frame(width: 48, height: 1)
                        Text(note.title).font(.subheadline.weight(.semibold)).multilineTextAlignment(.center)
                        Spacer(minLength: 8)
                    }.foregroundStyle(.white).padding(12).frame(maxWidth: .infinity)
                    Path { p in p.move(to: .zero); p.addLine(to: CGPoint(x: 24, y: 0)); p.addLine(to: CGPoint(x: 24, y: 24)); p.closeSubpath() }
                        .fill(StudioTheme.copper).frame(width: 24, height: 24)
                }.frame(height: 156)
            }.buttonStyle(.plain).accessibilityLabel(note.title)
            HStack(alignment: .top, spacing: 4) {
                Button(action: open) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(note.title).font(.subheadline.weight(.semibold)).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                        Text(L("\(note.pages) صفحة · PDF", "\(note.pages) pages · PDF")).font(.caption).foregroundStyle(StudioTheme.secondary)
                    }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }.buttonStyle(.plain)
                TayyaIconButton(title: L("المفضلة", "Favorite"), symbol: note.favorite ? "star.fill" : "star", selected: note.favorite, action: favorite)
            }
        }.studioCard(12)
    }
}

struct StudioLibrary: View {
    @ObservedObject var navigation: StudioNavigation
    @State private var query = ""
    @State private var selectedSection = 0
    @State private var favorites = false
    @State private var destination = 0
    @Environment(\.dynamicTypeSize) private var type
    @State private var notes = [
        StudioNotebook(arabic: "مبادئ المحاسبة", english: "Accounting principles", pages: 24, tint: 0x416B5D, symbol: "chart.bar.xaxis", favorite: true),
        StudioNotebook(arabic: "القانون المدني", english: "Civil law", pages: 38, tint: 0x886347, symbol: "building.columns"),
        StudioNotebook(arabic: "الرياضيات المتقدمة", english: "Advanced mathematics", pages: 16, tint: 0x486574, symbol: "function"),
        StudioNotebook(arabic: "دفتر أفكاري", english: "My ideas", pages: 12, tint: 0x646A49, symbol: "sparkles")
    ]
    private var filtered: [StudioNotebook] {
        notes.filter { (!favorites || $0.favorite) && (query.isEmpty || $0.title.localizedCaseInsensitiveContains(query)) }
    }
    var body: some View {
        GeometryReader { geo in
            let tablet = UIDevice.current.userInterfaceIdiom == .pad
            HStack(spacing: 0) {
                if tablet { sidebar.frame(width: 208) }
                VStack(spacing: 0) {
                    header
                    if destination == 0 { libraryContent(width: geo.size.width - (tablet ? 208 : 0)) }
                    else { destinationContent }
                    if !tablet { bottomTabs }
                }
            }.background(StudioTheme.background)
        }.accessibilityIdentifier("libraryScene")
            .sheet(isPresented: $navigation.addNotebook) { addSheet }
    }
    private var header: some View {
        HStack {
            StudioBrand()
            Spacer()
            Menu {
                Button(L("دفتر جديد", "New notebook"), systemImage: "doc.badge.plus") { navigation.addNotebook = true }
                Button(L("استيراد ملف", "Import document"), systemImage: "square.and.arrow.down") { navigation.sheet = .importDocument }
            } label: {
                Image(systemName: "plus").font(.title3.weight(.medium)).frame(width: 44, height: 44)
                    .foregroundStyle(StudioTheme.onPrimary).background(StudioTheme.primary, in: RoundedRectangle(cornerRadius: 14))
            }.accessibilityLabel(L("إضافة", "Add")).accessibilityIdentifier("libraryAdd")
        }.padding(.horizontal, 24).padding(.vertical, 12)
    }
    private func libraryContent(width: CGFloat) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(StudioTheme.secondary)
                    TextField(L("ابحث في مكتبتك", "Search your library"), text: $query).accessibilityIdentifier("librarySearch")
                }.padding(12).frame(minHeight: 48).background(StudioTheme.surface, in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("مساحتك للدراسة", "Your space to study")).font(.largeTitle.bold())
                    Text(L("كل فكرة، في مكانها.", "A place for every idea.")).font(.subheadline).foregroundStyle(StudioTheme.secondary)
                }
                Button { navigation.scene = .document } label: {
                    HStack(spacing: 16) {
                        Image(systemName: "book.closed").font(.title2).frame(width: 48, height: 56)
                            .background(StudioTheme.surface, in: RoundedRectangle(cornerRadius: 10))
                        VStack(alignment: .leading, spacing: 6) {
                            Text(L("متابعة القراءة", "Continue reading")).font(.caption).foregroundStyle(StudioTheme.secondary)
                            Text(L("مبادئ المحاسبة", "Accounting principles")).font(.headline)
                            ProgressView(value: 7, total: 24).tint(StudioTheme.primary)
                            Text(L("صفحة 7 من 24", "Page 7 of 24")).font(.caption2).foregroundStyle(StudioTheme.secondary)
                        }
                        Image(systemName: "chevron.forward").font(.caption)
                    }.padding(16).background(StudioTheme.selection, in: RoundedRectangle(cornerRadius: 16))
                }.buttonStyle(.plain).accessibilityIdentifier("continueReading")
                VStack(alignment: .leading, spacing: 12) {
                    TayyaSectionHeader(title: L("أقسامك", "Your sections"))
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(0..<3) { index in
                                let labels = [L("الكل", "All"), L("الجامعة", "University"), L("شخصي", "Personal")]
                                Button { selectedSection = index; query = index == 2 ? L("دفتر", "ideas") : "" } label: {
                                    Label(labels[index], systemImage: index == 0 ? "books.vertical" : "folder")
                                        .font(.caption.weight(.medium)).padding(.horizontal, 16).frame(minHeight: 44)
                                        .background(selectedSection == index ? StudioTheme.selection : StudioTheme.surface, in: Capsule())
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                }
                VStack(spacing: 16) {
                    HStack {
                        TayyaSectionHeader(title: L("دفاترك", "Your notebooks"), detail: "\(filtered.count)")
                        Button { favorites.toggle() } label: {
                            Label(L("المفضلة", "Favorites"), systemImage: favorites ? "star.fill" : "star")
                                .font(.caption).padding(.horizontal, 12).frame(minHeight: 44)
                                .background(favorites ? StudioTheme.selection : Color.clear, in: Capsule())
                        }.buttonStyle(.plain)
                    }
                    if filtered.isEmpty { TayyaEmptyState(title: L("لا توجد ملفات", "No documents"), message: L("جرّب كلمة بحث أخرى أو أضف دفترًا.", "Try another search or add a notebook.")) }
                    let columns = type.isAccessibilitySize ? 1 : width > 700 ? 3 : 2
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: columns), spacing: 16) {
                        ForEach(filtered) { note in
                            TayyaDocumentCard(note: note, open: { navigation.scene = .document }, favorite: {
                                if let i = notes.firstIndex(where: { $0.id == note.id }) { notes[i].favorite.toggle() }
                            })
                        }
                    }
                }
            }.padding(24).frame(maxWidth: 1060).frame(maxWidth: .infinity)
        }
    }
    private var bottomTabs: some View {
        HStack(spacing: 4) { ForEach(0..<4) { tab($0) } }
            .padding(.horizontal, 12).padding(.vertical, 8).background(StudioTheme.surface)
    }
    private func tab(_ index: Int) -> some View {
        let titles = [L("المكتبة", "Library"), L("الأقسام", "Sections"), L("المراجعة", "Review"), L("الإعدادات", "Settings")]
        let icons = ["books.vertical", "folder", "rectangle.stack", "gearshape"]
        return Button { if index == 2 { navigation.scene = .cards } else { destination = index } } label: {
            VStack(spacing: 4) {
                Image(systemName: icons[index]).font(.system(size: 20))
                Text(titles[index]).font(.caption2).fixedSize(horizontal: false, vertical: true)
            }.frame(maxWidth: .infinity, minHeight: 48)
                .foregroundStyle(destination == index ? StudioTheme.primary : StudioTheme.secondary)
                .background(destination == index ? StudioTheme.selection : Color.clear, in: RoundedRectangle(cornerRadius: 12))
        }.buttonStyle(.plain)
    }
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L("مساحة الدراسة", "STUDY SPACE")).font(.caption).foregroundStyle(StudioTheme.secondary).padding(.top, 24)
            ForEach(0..<4) { tab($0) }
            Divider().padding(.vertical, 8)
            Text(L("أقسامك", "YOUR SECTIONS")).font(.caption).foregroundStyle(StudioTheme.secondary)
            Button { destination = 0; query = "" } label: { Label(L("الجامعة", "University"), systemImage: "folder").frame(minHeight: 44) }
            Button { destination = 0; query = L("دفتر", "ideas") } label: { Label(L("شخصي", "Personal"), systemImage: "folder").frame(minHeight: 44) }
            Spacer()
            Text(L("مساحة هادئة، لأفكار كبيرة.", "A quiet space for big ideas.")).font(.caption).foregroundStyle(StudioTheme.secondary)
        }.buttonStyle(.plain).padding(16).background(StudioTheme.surface)
    }
    @ViewBuilder private var destinationContent: some View {
        if destination == 1 {
            VStack(spacing: 24) {
                TayyaSectionHeader(title: L("الأقسام", "Sections"))
                ForEach([L("الجامعة", "University"), L("شخصي", "Personal")], id: \.self) { title in
                    Button { destination = 0; query = title == L("شخصي", "Personal") ? L("دفتر", "ideas") : "" } label: {
                        Label(title, systemImage: "folder").frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).studioCard()
                    }.buttonStyle(.plain)
                }
                Spacer()
            }.padding(24)
        } else {
            List {
                Section(L("إدارة المكتبة", "Library management")) {
                    Button(L("المحذوفات", "Recently deleted"), systemImage: "trash") { navigation.sheet = .trash }
                    Button(L("النسخ الاحتياطية", "Backups"), systemImage: "externaldrive") { navigation.sheet = .backup }
                }
                Section(L("المظهر", "Appearance")) {
                    Text(L("تلقائي حسب الجهاز", "Follows system appearance"))
                    Text(L("العربية والإنجليزية · نص قابل للتكبير", "Arabic and English · scalable text"))
                }
            }.scrollContentBackground(.hidden)
        }
    }
    private var addSheet: some View {
        StudioAddNotebook { title in
            notes.append(StudioNotebook(arabic: title, english: title, pages: 1, tint: 0x416B5D, symbol: "doc"))
            navigation.addNotebook = false
        }
    }
}

private struct StudioAddNotebook: View {
    let save: (String) -> Void
    @State private var title = ""
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form { TextField(L("اسم الدفتر", "Notebook title"), text: $title) }
                .navigationTitle(L("دفتر جديد", "New notebook"))
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button(L("إلغاء", "Cancel")) { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button(L("إضافة", "Add")) { save(title) }.disabled(title.trimmingCharacters(in: .whitespaces).isEmpty) }
                }
        }
    }
}
