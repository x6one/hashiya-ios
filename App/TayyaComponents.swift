import SwiftUI

/// Approved Studio metrics, shared by real production screens.
enum TayyaMetrics {
    static let unit: CGFloat = 4
    static let compact: CGFloat = 8
    static let inset: CGFloat = 12
    static let spacing: CGFloat = 16
    static let section: CGFloat = 24
    static let touch: CGFloat = 44
    static let icon: CGFloat = 19
    static let controlRadius: CGFloat = 12
    static let cardRadius: CGFloat = 16
    static let notesMinimum: CGFloat = 340
    static let documentMinimum: CGFloat = 300
}

struct TayyaBrand: View {
    var body: some View {
        HStack(spacing: TayyaMetrics.compact) {
            TayyaFold().fill(TayyaTheme.ink).frame(width: 29, height: 32)
                .accessibilityHidden(true)
            Text("طَيّة").font(.title2.bold())
            Text("STUDIO").font(.system(size: 9, weight: .semibold))
                .tracking(2).foregroundStyle(TayyaTheme.detail)
        }.accessibilityElement(children: .combine)
    }
}

struct TayyaPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, TayyaMetrics.spacing)
            .padding(.vertical, TayyaMetrics.unit)
            .foregroundStyle(TayyaTheme.onInk)
            .background(TayyaTheme.ink,
                        in: RoundedRectangle(cornerRadius: TayyaMetrics.controlRadius))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

struct TayyaIconButton: View {
    let title: String
    let symbol: String
    var selected = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: TayyaMetrics.icon, weight: .regular))
                .frame(minWidth: TayyaMetrics.touch, minHeight: TayyaMetrics.touch)
                .foregroundStyle(selected ? TayyaTheme.ink : TayyaTheme.detail)
                .background(selected ? TayyaTheme.selection : Color.clear,
                            in: RoundedRectangle(cornerRadius: TayyaMetrics.controlRadius))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .help(title)
    }
}

struct TayyaToolbar<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: TayyaMetrics.unit, content: content)
                .padding(.horizontal, TayyaMetrics.inset)
        }
        .frame(minHeight: TayyaMetrics.touch)
        .background(TayyaTheme.surface)
    }
}

struct TayyaSectionHeader: View {
    let title: String
    var detail = ""

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.headline)
                Spacer(minLength: TayyaMetrics.compact)
                if !detail.isEmpty { detailLabel }
            }
            VStack(alignment: .leading, spacing: TayyaMetrics.unit) {
                Text(title).font(.headline)
                if !detail.isEmpty { detailLabel }
            }
        }.accessibilityAddTraits(.isHeader)
    }

    private var detailLabel: some View {
        Text(detail).font(.caption).foregroundStyle(TayyaTheme.detail)
            .fixedSize(horizontal: true, vertical: true)
    }
}

extension View {
    func tayyaCard(_ padding: CGFloat = TayyaMetrics.spacing) -> some View {
        self.padding(padding)
            .background(TayyaTheme.surface, in: RoundedRectangle(cornerRadius: TayyaMetrics.cardRadius))
            .overlay {
                RoundedRectangle(cornerRadius: TayyaMetrics.cardRadius)
                    .strokeBorder(TayyaTheme.separator.opacity(0.6), lineWidth: 0.5)
            }
    }
}
