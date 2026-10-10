import SwiftUI

enum WorkspaceToolGroup: String, CaseIterable, Identifiable {
    case writing = "كتابة", pages = "صفحات", study = "دراسة", files = "ملفات"
    var id: String { rawValue }
}
struct WorkspaceAction: View {
    let title: String
    let symbol: String
    var selected = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: symbol).font(.system(size: 20, weight: .medium))
                Text(title).font(.caption).fixedSize(horizontal: true, vertical: false)
            }.frame(minWidth: 52, minHeight: 48).padding(.horizontal, 5).padding(.vertical, 3)
                .foregroundStyle(selected ? TayyaTheme.paper : TayyaTheme.ink)
                .background(selected ? TayyaTheme.ink : Color.clear, in: RoundedRectangle(cornerRadius: 10))
        }.buttonStyle(.plain).accessibilityLabel(title).accessibilityAddTraits(selected ? .isSelected : [])
    }
}
struct WritingPaperPicker: View {
    let add: (PaperTemplate) -> Void
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List(PaperTemplate.allCases) { template in
                Button { add(template); dismiss() } label: {
                    Label(template.rawValue, systemImage: "doc.badge.plus").padding(.vertical, 10)
                }
            }.navigationTitle("إضافة ورقة للكتابة").toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("إلغاء") { dismiss() } }
            }
        }.environment(\.layoutDirection, .rightToLeft)
    }
}
