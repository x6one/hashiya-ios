import SwiftUI
struct Flashcard: Identifiable, Codable {
    var id = UUID()
    var question: String
    var answer: String
    var page: Int
    var known = false
}
@MainActor final class FlashcardStore: ObservableObject {
    @Published private(set) var cards: [Flashcard] = []
    @Published var error: String?
    let url: URL
    init(url: URL) {
        self.url = url
        if FileManager.default.fileExists(atPath: url.path) {
            do { cards = try JSONDecoder().decode([Flashcard].self, from: Data(contentsOf: url)) }
            catch { self.error = error.localizedDescription }
        }
    }
    @discardableResult func save(_ card: Flashcard) -> Bool {
        var updated = cards.filter { $0.id != card.id }; updated.append(card)
        return commit(updated)
    }
    func delete(_ id: UUID) { commit(cards.filter { $0.id != id }) }
    @discardableResult private func commit(_ updated: [Flashcard]) -> Bool {
        do { try JSONEncoder().encode(updated).write(to: url, options: .atomic); cards = updated; return true }
        catch { self.error = error.localizedDescription; return false }
    }
}
struct CardEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var card: Flashcard
    let save: (Flashcard) -> Bool
    init(card: Flashcard, save: @escaping (Flashcard) -> Bool) { _card = State(initialValue: card); self.save = save }
    var body: some View {
        NavigationStack {
            Form {
                Section("السؤال") { TextEditor(text: $card.question).frame(minHeight: 90) }
                Section("الإجابة") { TextEditor(text: $card.answer).frame(minHeight: 140) }
                Text("صفحة \(card.page)").font(.caption)
            }.navigationTitle("بطاقة مراجعة").toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("إلغاء") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("حفظ") { if save(card) { dismiss() } }.disabled(card.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || card.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
            }
        }.environment(\.layoutDirection, .rightToLeft)
    }
}
struct FlashcardsScreen: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var store: FlashcardStore
    @State private var editing: Flashcard?
    @State private var revealed: Set<UUID> = []
    @State private var onlyPending = true
    init(url: URL) { _store = StateObject(wrappedValue: FlashcardStore(url: url)) }
    var body: some View {
        NavigationStack {
            List {
                Toggle("مراجعة البطاقات التي تحتاج إعادة", isOn: $onlyPending)
                if store.cards.isEmpty { Text("حدد نصًا من المستند ثم اختر إنشاء بطاقة، أو أضف بطاقة بنفسك.") }
                ForEach(store.cards.filter { !onlyPending || !$0.known }) { card in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(card.question).font(.headline)
                        if revealed.contains(card.id) { Text(card.answer) }
                        Button(revealed.contains(card.id) ? "إخفاء الإجابة" : "إظهار الإجابة") { if revealed.contains(card.id) { revealed.remove(card.id) } else { revealed.insert(card.id) } }
                        HStack {
                            Button("أعرفها", systemImage: "checkmark") { var updated = card; updated.known = true; store.save(updated) }
                            Button("أراجعها", systemImage: "arrow.clockwise") { var updated = card; updated.known = false; store.save(updated) }
                            Button("تعديل") { editing = card }
                        }.buttonStyle(.bordered)
                        Text("صفحة \(card.page)").font(.caption).foregroundStyle(.secondary)
                    }.padding(.vertical, 8).swipeActions { Button("حذف", role: .destructive) { store.delete(card.id) } }
                }
            }.navigationTitle("بطاقات المراجعة").toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("تم") { dismiss() } }
                ToolbarItem(placement: .primaryAction) { Button("إضافة", systemImage: "plus") { editing = Flashcard(question: "", answer: "", page: 1) } }
            }.sheet(item: $editing) { card in CardEditor(card: card, save: store.save) }
            .alert("تعذر الحفظ", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) { Button("حسنًا") { store.error = nil } } message: { Text(store.error ?? "") }
        }.environment(\.layoutDirection, .rightToLeft)
    }
}
struct LibraryCardsScreen: View {
    @ObservedObject var library: LibraryStore
    @Environment(\.dismiss) private var dismiss
    @State private var section: String? = nil
    @State private var selected: Notebook?
    @State private var counts: [UUID: Int] = [:]
    private func refreshCounts() async {
        let notes = library.notebooks, root = library.root
        counts = await Task.detached(priority: .utility) {
            Dictionary(uniqueKeysWithValues: notes.map { note in
                let url = root.appendingPathComponent(note.id.uuidString + "-cards.json")
                let count = (try? JSONDecoder().decode([Flashcard].self, from: Data(contentsOf: url)))?.count ?? 0
                return (note.id, count)
            })
        }.value
    }
    var body: some View {
        NavigationStack {
            List {
                Picker("القسم", selection: $section) {
                    Text("كل الأقسام").tag(String?.none)
                    ForEach(library.sections, id: \.self) { Text($0).tag(Optional($0)) }
                }
                ForEach(library.notebooks.filter { !$0.trashed && (section == nil || $0.section == section) }) { note in
                    let total = counts[note.id] ?? 0
                    if total > 0 { Button { selected = note } label: {
                        HStack { VStack(alignment: .leading) { Text(note.title); Text(note.section).font(.caption).foregroundStyle(.secondary) }; Spacer(); Text("\(total) بطاقة") }
                    } }
                }
                Text("لإضافة بطاقة، افتح المستند وحدد نصًا ثم اختر إنشاء بطاقة من قائمة أدواته.").font(.caption).foregroundStyle(.secondary)
            }.navigationTitle("مراجعة الأقسام").toolbar { Button("تم") { dismiss() } }
            .task(id: library.notebooks) { await refreshCounts() }
            .onChange(of: selected) { _, value in if value == nil { Task { await refreshCounts() } } }
            .sheet(item: $selected) { note in FlashcardsScreen(url: library.root.appendingPathComponent(note.id.uuidString + "-cards.json")) }
        }.environment(\.layoutDirection, .rightToLeft)
    }
}
