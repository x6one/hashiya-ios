import SwiftUI

struct InkGeometryControls: View {
    @Binding var mode: InkGeometryMode
    @Binding var ruler: Bool
    @Binding var brush: InkBrush
    var body: some View {
        Menu {
            ForEach(InkGeometryMode.allCases, id: \.self) { item in
                Button(TayyaLocalized(item.title), systemImage: item.symbol) {
                    if brush == .eraser { brush = .pen }
                    mode = item; ruler = false
                }.accessibilityIdentifier("inkGeometry-" + item.rawValue)
            }
        } label: {
            Image(systemName: mode.symbol).font(.system(size: TayyaMetrics.icon))
                .foregroundStyle(mode == .freehand ? TayyaTheme.ink : TayyaTheme.brandInk)
                .frame(width: TayyaMetrics.touch, height: TayyaMetrics.touch).contentShape(Rectangle())
        }.accessibilityIdentifier("inkGeometry").accessibilityLabel(TayyaLocalized("طريقة الرسم"))
            .accessibilityValue(mode.rawValue)
        Button {
            let enabled = !ruler
            if enabled { mode = .freehand; if brush == .eraser { brush = .pen } }
            ruler = enabled
        } label: {
            Image(systemName: "ruler").font(.system(size: TayyaMetrics.icon))
                .foregroundStyle(ruler ? TayyaTheme.brandInk : TayyaTheme.ink)
                .frame(width: TayyaMetrics.touch, height: TayyaMetrics.touch)
                .background(ruler ? TayyaTheme.selection : Color.clear, in: RoundedRectangle(cornerRadius: TayyaMetrics.controlRadius))
                .contentShape(Rectangle())
        }.accessibilityIdentifier("inkRuler").accessibilityLabel(TayyaLocalized("المسطرة"))
            .accessibilityValue(ruler ? "on" : "off")
            .accessibilityHint(TayyaLocalized("حرّك المسطرة بإصبعين، ثم ارسم بالقلم بمحاذاتها."))
    }
}

extension InkGeometryMode {
    var title: String {
        switch self { case .freehand: return "رسم حر"; case .line: return "خط مستقيم"; case .highlighter: return "تظليل مستقيم" }
    }
    var symbol: String {
        switch self { case .freehand: return "pencil.tip"; case .line: return "line.diagonal"; case .highlighter: return "highlighter" }
    }
}

struct SelectedInkTools: View {
    let count: Int
    let allowsGeometry: Bool
    let action: (String) -> Void
    @State private var showingColors = false
    @State private var customColor = Color.blue
    var body: some View {
        TayyaToolbar {
            TayyaIconButton(title: "استقامة الخط", symbol: "line.diagonal") { action("straighten") }
                .disabled(!allowsGeometry).accessibilityIdentifier("straightenSelectedInk")
                .accessibilityValue(String(count))
                .accessibilityHint(TayyaLocalized("حدّد الخط باللمس أو أحط الكتابة، ثم اضغط لاستقامتها. تبقى الأطراف في مكانها."))
            Menu {
                ForEach([("أحمر", "red"), ("أزرق", "blue"), ("أخضر", "green"), ("أسود", "black"), ("أصفر", "yellow")], id: \.1) { title, name in
                    Button(TayyaLocalized(title)) { action("color-" + name) }.accessibilityIdentifier("selectedInkColor-" + name)
                }
                Button(TayyaLocalized("لون مخصص")) { showingColors = true }
            } label: { control("لون الخط", symbol: "paintpalette") }
                .disabled(count == 0).accessibilityIdentifier("selectedInkColor")
            Menu {
                ForEach([1, 2, 3, 5, 8, 12], id: \.self) { width in
                    Button(String(format: TayyaLocalized("سماكة %d"), width)) { action("width-\(width)") }
                        .accessibilityIdentifier("selectedInkWidth-\(width)")
                }
            } label: { control("سماكة الخط", symbol: "lineweight") }
                .disabled(count == 0).accessibilityIdentifier("selectedInkWidth")
            TayyaIconButton(title: "تراجع", symbol: "arrow.uturn.backward") { action("undo") }.accessibilityIdentifier("selectionUndo")
            TayyaIconButton(title: "إعادة", symbol: "arrow.uturn.forward") { action("redo") }.accessibilityIdentifier("selectionRedo")
            Menu {
                Section(TayyaLocalized("موضع الخط وحجمه")) {
                    ForEach([("يسار", "left", "arrow.left"), ("يمين", "right", "arrow.right"), ("أعلى", "up", "arrow.up"), ("أسفل", "down", "arrow.down"), ("تكبير", "grow", "arrow.up.left.and.arrow.down.right"), ("تصغير", "shrink", "arrow.down.right.and.arrow.up.left")], id: \.1) { title, name, symbol in
                        Button(TayyaLocalized(title), systemImage: symbol) { action(name) }
                            .disabled(count == 0).accessibilityIdentifier("selectionAction-" + name)
                    }
                    Button(TayyaLocalized("إطالة الخط"), systemImage: "arrow.left.and.right") { action("lengthen") }.disabled(count != 1 || !allowsGeometry)
                    Button(TayyaLocalized("تقصير الخط"), systemImage: "arrow.right.and.line.vertical.and.arrow.left") { action("shorten") }.disabled(count != 1 || !allowsGeometry)
                }
                Button(TayyaLocalized("نسخ"), systemImage: "doc.on.doc") { action("copy") }
                    .disabled(count == 0).accessibilityIdentifier("selectionAction-copy")
                Button(TayyaLocalized("لصق"), systemImage: "doc.on.clipboard") { action("paste") }.accessibilityIdentifier("selectionAction-paste")
            } label: { control("إجراءات التحديد", symbol: "ellipsis") }
                .accessibilityIdentifier("selectedInkActions")
        }
        .sheet(isPresented: $showingColors) {
            NavigationStack {
                ColorPicker(TayyaLocalized("لون الخط"), selection: $customColor, supportsOpacity: false)
                    .padding(TayyaMetrics.section).navigationTitle(TayyaLocalized("لون الخط"))
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button(TayyaLocalized("إلغاء")) { showingColors = false } }
                        ToolbarItem(placement: .confirmationAction) {
                            Button(TayyaLocalized("تطبيق")) { applyCustomColor(); showingColors = false }
                        }
                    }
            }.presentationDetents([.medium, .large])
        }
    }
    private func applyCustomColor() {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        if UIColor(customColor).getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            action("rgba:\(red),\(green),\(blue),\(alpha)")
        }
    }
    private func control(_ title: String, symbol: String) -> some View {
        Image(systemName: symbol).font(.system(size: TayyaMetrics.icon))
            .frame(width: TayyaMetrics.touch, height: TayyaMetrics.touch)
            .contentShape(Rectangle()).accessibilityLabel(TayyaLocalized(title))
    }
}
