import SwiftUI

struct TayyaIconButton: View {
    let title: String
    let symbol: String
    var selected = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: StudioMetrics.icon, weight: .regular))
                .frame(minWidth: StudioMetrics.touch, minHeight: StudioMetrics.touch)
                .foregroundStyle(selected ? StudioTheme.primary : StudioTheme.secondary)
                .background(selected ? StudioTheme.selection : Color.clear, in: RoundedRectangle(cornerRadius: StudioMetrics.controlRadius))
                .contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityLabel(title).help(title)
    }
}

struct StudioSaveStatus: View {
    @ObservedObject var draft: StudioDraft
    var identifier = "saveStatus"
    var compact = false
    private var statusLabel: String {
        draft.status == "saved" ? L("محفوظ محليًا", "Saved locally") : draft.status == "failed" ? L("تعذّر الحفظ", "Could not save") : draft.status == "saving" ? L("جارٍ الحفظ", "Saving") : L("مسودة المعاينة", "Preview draft")
    }
    var body: some View {
        Text(compact && draft.status == "saved" ? L("محفوظ", "Saved") : compact && draft.status == "unsaved" ? L("معاينة", "Preview") : statusLabel)
            .font(.caption2).foregroundStyle(draft.status == "failed" ? StudioTheme.destructive : StudioTheme.secondary).lineLimit(1)
            .accessibilityIdentifier(identifier).accessibilityValue(draft.status).accessibilityLabel(statusLabel)
    }
}

struct TayyaPrimaryButton: View {
    let title: String
    var symbol = "plus"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol).font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 48)
                .foregroundStyle(StudioTheme.onPrimary)
                .background(StudioTheme.primary, in: RoundedRectangle(cornerRadius: StudioMetrics.controlRadius))
        }.buttonStyle(.plain)
    }
}

struct TayyaToolbar<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4, content: content).padding(.horizontal, 12)
        }.frame(height: StudioMetrics.touch).background(StudioTheme.surface)
    }
}

struct TayyaSectionHeader: View {
    let title: String
    var detail = ""
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.headline)
            Spacer(minLength: 8)
            if !detail.isEmpty { Text(detail).font(.caption).foregroundStyle(StudioTheme.secondary) }
        }
    }
}

struct TayyaEmptyState: View {
    let title: String
    let message: String
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "books.vertical").font(.largeTitle).foregroundStyle(StudioTheme.primary)
            Text(title).font(.headline)
            Text(message).font(.subheadline).foregroundStyle(StudioTheme.secondary)
                .multilineTextAlignment(.center)
        }.padding(24).frame(maxWidth: .infinity)
    }
}

struct TayyaPageNavigator: View {
    @ObservedObject var session: StudioSession
    let openPages: () -> Void
    var body: some View {
        HStack(spacing: 8) {
            TayyaIconButton(title: L("الصفحة السابقة", "Previous page"), symbol: "chevron.backward") {
                session.changePage(to: session.page - 1)
            }.disabled(session.page <= 1).accessibilityIdentifier("previousPage")
            Spacer(minLength: 0)
            Button(action: openPages) {
                HStack(spacing: 8) {
                    Text("\(session.page)").font(.subheadline.bold())
                        .padding(.horizontal, 12).padding(.vertical, 6).background(StudioTheme.selection, in: RoundedRectangle(cornerRadius: 8))
                    Text(L("من \(session.totalPages)", "of \(session.totalPages)")).font(.caption).foregroundStyle(StudioTheme.secondary)
                }.frame(minHeight: StudioMetrics.touch).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel(L("الصفحة \(session.page) من \(session.totalPages)", "Page \(session.page) of \(session.totalPages)"))
                .accessibilityIdentifier("pageCount").accessibilityValue(String(session.page))
            Spacer(minLength: 0)
            TayyaIconButton(title: L("الصفحة التالية", "Next page"), symbol: "chevron.forward") {
                session.changePage(to: session.page + 1)
            }.disabled(session.page >= session.totalPages).accessibilityIdentifier("nextPage")
            Divider().frame(height: 20)
            TayyaIconButton(title: L("مصغرات الصفحات", "Page thumbnails"), symbol: "square.grid.2x2", action: openPages)
                .accessibilityIdentifier("pageThumbnails")
        }.padding(.horizontal, 12).background(StudioTheme.surface)
    }
}

struct StudioWaveform: View {
    var active = false
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let count = max(1, Int(geometry.size.width / 5))
                for index in 0..<count {
                    let value = abs(sin(Double(index) * 1.3) * cos(Double(index) * 0.27))
                    let height = CGFloat(value) * geometry.size.height * 0.85 + 3
                    let x = CGFloat(index) * 5
                    path.move(to: CGPoint(x: x, y: (geometry.size.height - height) / 2))
                    path.addLine(to: CGPoint(x: x, y: (geometry.size.height + height) / 2))
                }
            }.stroke(StudioTheme.copper.opacity(active ? 1 : 0.55), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }.accessibilityHidden(true)
    }
}

func studioTime(_ time: Double) -> String {
    String(format: "%02d:%02d", Int(max(0, time)) / 60, Int(max(0, time)) % 60)
}
