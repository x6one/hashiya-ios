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
    func save(_ card: Flashcard) {
        var updated = cards.filter { $0.id != card.id }; updated.append(card)
        commit(updated)
    }
    func delete(_ id: UUID) { commit(cards.filter { $0.id != id }) }
    private func commit(_ updated: [Flashcard]) {
        do { try JSONEncoder().encode(updated).write(to: url, options: .atomic); cards = updated }
        catch { self.error = error.localizedDescription }
    }
}
struct CardEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var card: Flashcard
    let save: (Flashcard) -> Void
    var body: some View {
        NavigationStack {
            Form {
                Section("السؤال") { TextEditor(text: $card.question).frame(minHeight: 90) }
                Section("الإجابة") { TextEditor(text: $card.answer).frame(minHeight: 140) }
                Text("صفحة \(card.page)").font(.caption)
            }.navigationTitle("بطاقة مراجعة").toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("إلغاء") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("حفظ") { save(card); dismiss() }.disabled(card.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || card.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
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
