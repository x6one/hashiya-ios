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
            WorkspaceActionLabel(title: title, symbol: symbol)
                .foregroundStyle(selected ? TayyaTheme.paper : TayyaTheme.ink)
                .background(selected ? TayyaTheme.ink : Color.clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }.buttonStyle(.plain).accessibilityLabel(title).accessibilityAddTraits(selected ? .isSelected : [])
    }
}
struct WorkspaceActionLabel: View {
    let title: String
    let symbol: String
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: symbol).font(.body.weight(.medium)).symbolRenderingMode(.hierarchical)
            Text(title).font(.caption2.weight(.medium)).fixedSize(horizontal: true, vertical: true)
        }.frame(minWidth: 54, minHeight: 44).padding(.horizontal, 6).padding(.vertical, 4)
            .contentShape(Rectangle())
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
