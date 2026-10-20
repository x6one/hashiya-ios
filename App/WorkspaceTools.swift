import SwiftUI

enum WorkspaceToolGroup: String, CaseIterable, Identifiable {
    case writing = "كتابة", pages = "صفحات", study = "دراسة", files = "ملفات"
    var id: String { rawValue }
}
struct WorkspaceAction: View {
    @ObservedObject var localization = TayyaLocalization.shared
    let title: String
    let symbol: String
    var selected = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            WorkspaceActionLabel(title: title, symbol: symbol)
                .foregroundStyle(selected ? TayyaTheme.ink : TayyaTheme.detail)
                .background(selected ? TayyaTheme.selection : Color.clear, in: RoundedRectangle(cornerRadius: TayyaMetrics.controlRadius, style: .continuous))
        }.buttonStyle(.plain).accessibilityLabel(TayyaLocalized(title)).accessibilityAddTraits(selected ? .isSelected : [])
    }
}
struct WorkspaceActionLabel: View {
    @ObservedObject var localization = TayyaLocalization.shared
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.verticalSizeClass) private var verticalClass
    let title: String
    let symbol: String
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: symbol).font(.system(size: TayyaMetrics.icon)).symbolRenderingMode(.hierarchical)
            if typeSize < .accessibility3 && verticalClass != .compact {
                Text(TayyaLocalized(title)).font(.caption2.weight(.medium)).fixedSize(horizontal: true, vertical: true)
            }
        }.frame(minWidth: 54, minHeight: TayyaMetrics.touch).padding(.horizontal, 6)
            .padding(.vertical, typeSize >= .accessibility3 || verticalClass == .compact ? 0 : TayyaMetrics.unit)
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
        }
    }
}
