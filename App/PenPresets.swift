import SwiftUI

/// Dedicated DEBUG probe: no publication, UI refresh, persistence or audio data.
/// Release calls compile to no-ops; native snapshots read actual model bindings.
@MainActor enum NativeToolActionTrace {
    #if DEBUG
    private(set) static var events: [String] = []
    #endif
    static func record(_ event: String) {
        #if DEBUG
        guard ProcessInfo.processInfo.arguments.contains("--test-native-menu") else { return }
        events.append(event)
        if events.count > 12 { events.removeFirst() }
        #endif
    }
}

struct PenPreset: Codable {
    var brush: InkBrush
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double = 1
    var width: Double
    var color: Color { Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha) }
    var valid: Bool {
        [InkBrush.pen, .pencil, .marker].contains(brush) && width.isFinite && (1...12).contains(width)
            && [red, green, blue, alpha].allSatisfy { $0.isFinite && (0...1).contains($0) }
    }
}

@MainActor final class PenPresetStore: ObservableObject {
    static let key = "tayya.penPresets.v1"
    static let shared = PenPresetStore()
    @Published private(set) var presets = [
        PenPreset(brush: .pen, red: 0.07, green: 0.25, blue: 0.22, width: 3),
        PenPreset(brush: .pencil, red: 0.77, green: 0.56, blue: 0.41, width: 2),
        PenPreset(brush: .marker, red: 1, green: 0.78, blue: 0.25, width: 5)
    ]
    @Published private(set) var error: String?
    private let defaults: UserDefaults
    private var unreadable = false
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        guard defaults.object(forKey: Self.key) != nil else { return }
        do {
            guard let data = defaults.data(forKey: Self.key) else { throw CocoaError(.fileReadCorruptFile) }
            let loaded = try JSONDecoder().decode([PenPreset].self, from: data)
            guard loaded.count == 3, loaded.allSatisfy(\.valid) else { throw CocoaError(.fileReadCorruptFile) }
            presets = loaded
        } catch { unreadable = true; self.error = error.localizedDescription }
    }
    @discardableResult func save(slot: Int, brush: InkBrush, color: Color, width: Double) -> Bool {
        guard !unreadable, presets.indices.contains(slot) else { return false }
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        guard UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return false }
        let value = PenPreset(brush: brush, red: Double(red), green: Double(green), blue: Double(blue), alpha: Double(alpha), width: width)
        guard value.valid else { return false }
        do {
            var updated = presets; updated[slot] = value
            let data = try JSONEncoder().encode(updated)
            defaults.set(data, forKey: Self.key)
            presets = updated; error = nil
            return true
        } catch { self.error = error.localizedDescription; return false }
    }
}

struct FavoritePenMenu: View {
    @ObservedObject private var store = PenPresetStore.shared
    @Binding var brush: InkBrush
    @Binding var color: Color
    @Binding var width: Double
    @State private var failed = false
    var body: some View {
        Menu {
            ForEach(0..<3, id: \.self) { slot in
                Button {
                    let preset = store.presets[slot]
                    brush = preset.brush; color = preset.color; width = preset.width
                    NativeToolActionTrace.record("apply=\(slot); brush=\(brush.rawValue); width=\(width)")
                } label: {
                    Label(String(format: TayyaLocalized("قلم %d — %@، %.1f نقطة"), slot + 1,
                        TayyaLocalized(store.presets[slot].brush.rawValue), store.presets[slot].width),
                        systemImage: store.presets[slot].brush.symbol)
                }.accessibilityIdentifier("usePenPreset-\(slot)")
            }
            Section(TayyaLocalized("حفظ إعداد القلم الحالي")) {
                ForEach(0..<3, id: \.self) { slot in
                    Button(String(format: TayyaLocalized("حفظ في القلم %d"), slot + 1)) {
                        failed = !store.save(slot: slot, brush: brush, color: color, width: width)
                        NativeToolActionTrace.record("save=\(slot); failed=\(failed); brush=\(brush.rawValue); width=\(width)")
                    }.accessibilityIdentifier("savePenPreset-\(slot)")
                        .disabled(![InkBrush.pen, .pencil, .marker].contains(brush))
                }
            }
        } label: {
            Image(systemName: "star").font(.system(size: TayyaMetrics.icon))
                .frame(width: TayyaMetrics.touch, height: TayyaMetrics.touch)
        }.accessibilityLabel(TayyaLocalized("الأقلام المفضلة")).accessibilityIdentifier("favoritePens")
            .alert(TayyaLocalized("تعذّر حفظ إعداد القلم"), isPresented: $failed) {
                Button(TayyaLocalized("حسنًا")) { failed = false }
            } message: { Text(store.error ?? TayyaLocalized("اختر قلمًا ولونًا وسماكة صالحة قبل الحفظ.")) }
    }
}
