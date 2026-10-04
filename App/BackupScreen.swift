import SwiftUI
import UniformTypeIdentifiers
struct BackupScreen: View {
    @ObservedObject var store: LibraryStore
    @Environment(\.dismiss) private var dismiss
    @State private var busy = false
    @State private var picking = false
    @State private var share: URL?
    @State private var message = ""
    @State private var policy: RestorePolicy = .keepBoth
    var body: some View {
        NavigationStack {
            Form {
                Section("نسخة كاملة على جهازك") {
                    Text("تشمل الملفات وأصول Office والأقسام والمحذوفات والكتابة والصوت وبطاقات المراجعة.")
                    Button("تصدير نسخة احتياطية", systemImage: "square.and.arrow.up") {
                        busy = true
                        Task { defer { busy = false }; do { share = try await store.exportBackup() } catch { message = error.localizedDescription } }
                    }
                }
                Section("استعادة نسخة") {
                    Picker("إذا كان الملف موجودًا", selection: $policy) { ForEach(RestorePolicy.allCases) { Text($0.rawValue).tag($0) } }
                    Text("الاستعادة تدمج النسخة مع مكتبتك. لا تستبدل ملفاتك الموجودة.").font(.caption)
                    Button("اختيار النسخة الاحتياطية", systemImage: "square.and.arrow.down") { picking = true }
                }
                if busy { ProgressView("جارٍ إكمال العملية…") }
                if !message.isEmpty { Text(message) }
            }.disabled(busy).navigationTitle("النسخ الاحتياطي").toolbar { Button("تم") { dismiss() }.disabled(busy) }
            .fileImporter(isPresented: $picking, allowedContentTypes: [.zip]) { result in
                switch result {
                case .success(let url):
                    busy = true
                    Task {
                        let access = url.startAccessingSecurityScopedResource()
                        defer { if access { url.stopAccessingSecurityScopedResource() }; busy = false }
                        do { let count = try await store.restoreBackup(url, policy: policy); message = "تمت استعادة \(count) ملفات." }
                        catch { message = error.localizedDescription }
                    }
                case .failure(let error): message = error.localizedDescription
                }
            }
            .sheet(isPresented: Binding(get: { share != nil }, set: { if !$0 { if let share { try? FileManager.default.removeItem(at: share) }; share = nil } })) { if let share { ShareDocument(url: share) } }
        }.environment(\.layoutDirection, .rightToLeft).interactiveDismissDisabled(busy)
    }
}
