import SwiftUI

enum LibraryDestination: String, CaseIterable, Identifiable {
    case library, sections, review, settings
    var id: Self { self }
    var title: String {
        switch self {
        case .library: return "المكتبة"
        case .sections: return "الأقسام"
        case .review: return "المراجعة"
        case .settings: return "الإعدادات"
        }
    }
    var symbol: String {
        switch self {
        case .library: return "books.vertical"
        case .sections: return "folder"
        case .review: return "rectangle.stack"
        case .settings: return "gearshape"
        }
    }
    var accessibilityID: String {
        switch self {
        case .library: return "libraryHome"
        case .sections: return "librarySections"
        case .review: return "libraryReview"
        case .settings: return "librarySettings"
        }
    }
}

/// Embeds the real local review decks without a second navigation stack.
struct LibraryReviewDestination: View {
    @ObservedObject var library: LibraryStore
    @State private var section: String?
    @State private var selected: Notebook?
    @State private var counts: [UUID: Int] = [:]
    @State private var loading = true
    private var decks: [Notebook] {
        library.notebooks.filter { !$0.trashed && (section == nil || $0.section == section) && (counts[$0.id] ?? 0) > 0 }
    }
    var body: some View {
        List {
            Section {
                Picker("القسم", selection: $section) {
                    Text("كل الأقسام").tag(String?.none)
                    ForEach(library.sections, id: \.self) { Text($0).tag(Optional($0)) }
                }
            }
            Section("بطاقاتك") {
                if loading { ProgressView("تحميل البطاقات…") }
                else if decks.isEmpty {
                    Text("لا توجد بطاقات في هذا القسم. أضف بطاقة من أدوات المراجعة داخل ملفك.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                ForEach(decks) { note in
                    Button { selected = note } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(note.title).foregroundStyle(.primary)
                                Text(note.section).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(counts[note.id] ?? 0) بطاقة").font(.caption)
                        }.frame(minHeight: 44)
                    }.accessibilityIdentifier("reviewNotebook-" + note.title)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .task(id: library.notebooks) { await refreshCounts() }
        .sheet(item: $selected, onDismiss: { Task { await refreshCounts() } }) { note in
            FlashcardsScreen(url: library.root.appendingPathComponent(note.id.uuidString + "-cards.json"))
        }
    }
    private func refreshCounts() async {
        let notes = library.notebooks.filter { !$0.trashed }, root = library.root
        let result = await Task.detached(priority: .utility) {
            Dictionary(uniqueKeysWithValues: notes.map { note in
                let url = root.appendingPathComponent(note.id.uuidString + "-cards.json")
                let count = (try? JSONDecoder().decode([Flashcard].self, from: Data(contentsOf: url)))?.count ?? 0
                return (note.id, count)
            })
        }.value
        guard !Task.isCancelled else { return }
        counts = result
        loading = false
    }
}

/// Additive reading progress; documents and library metadata remain untouched.
/// Pages are one-based, matching search routes and the page navigation field.
enum LibraryReadingPosition {
    private static func key(for notebook: UUID, root: URL) -> String {
        "tayya.readingPage." + root.standardizedFileURL.path + "." + notebook.uuidString
    }
    static func page(for notebook: UUID, root: URL) -> Int? {
        let value = UserDefaults.standard.integer(forKey: key(for: notebook, root: root))
        return value > 0 ? value : nil
    }
    static func save(page: Int, for notebook: UUID, root: URL) {
        guard page > 0 else { return }
        UserDefaults.standard.set(page, forKey: key(for: notebook, root: root))
    }
}
