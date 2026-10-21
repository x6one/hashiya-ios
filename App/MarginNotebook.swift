import SwiftUI
import PencilKit

// Sheet coordinates never depend on the size of the split pane.
final class MarginCanvas: PKCanvasView {
    // Keep first-responder Undo/PencilKit routing without a text keyboard when
    // UIKit presents a tool menu. Text editing uses separate native editors.
    private let handwritingInput = UIView(frame: .zero)
    override var inputView: UIView? { handwritingInput }

    // Native UI diagnostics are available only to the dedicated regression test.
    override var accessibilityLabel: String? {
        get {
            let label = super.accessibilityLabel ?? ""
            guard ProcessInfo.processInfo.arguments.contains("--test-margin-viewport") else { return label }
            func describe(_ view: UIView, depth: Int) -> String {
                let own = "\(type(of: view)) frame=\(view.frame) bounds=\(view.bounds) transform=\(view.transform) hidden=\(view.isHidden) alpha=\(view.alpha) layerHidden=\(view.layer.isHidden) opacity=\(view.layer.opacity) contents=\(view.layer.contents != nil) children=\(view.subviews.count)"
                return own + (depth > 0 ? view.subviews.map { describe($0, depth: depth - 1) }.joined(separator: " | ") : "")
            }
            let nativeTool = tool as? PKInkingTool
            let lastInk = drawing.strokes.last?.ink
            let strokeDetails = drawing.strokes.last.map { stroke -> String in
                let path = stroke.path
                let indices = path.count == 0 ? [] : Array(Set([0, path.count / 2, path.count - 1])).sorted()
                let points = indices.map { index -> String in
                    let point = path[index]
                    return "point\(index) location=\(point.location) size=\(point.size) opacity=\(point.opacity) force=\(point.force)"
                }.joined(separator: "; ")
                return "renderBounds=\(stroke.renderBounds) transform=\(stroke.transform) points=\(path.count) \(points)"
            } ?? "none"
            return label + "; responder=\(isFirstResponder) keyWindow=\(window?.isKeyWindow ?? false) usingTool=\(usingTool); nativeTool=\(nativeTool?.inkType.rawValue ?? "none") color=\(String(describing: nativeTool?.color)) lastStrokeColor=\(String(describing: lastInk?.color)); lastStroke=[\(strokeDetails)]; zoom=\(zoomScale) content=\(contentSize) offset=\(contentOffset) inset=\(contentInset) ink=\(drawing.bounds) sheet=\(sheetSize) views=" + subviews.map { describe($0, depth: 3) }.joined(separator: " | ")
        }
        set { super.accessibilityLabel = newValue }
    }
    var sheetSize = CGSize(width: 650, height: 900)
    var followsFit = true
    private var fitsWidth = true
    private var previousBounds = CGSize.zero
    private var updatingViewport = false
    var usingTool = false
    private var pendingSheetSize: CGSize?
    func setSheetSize(_ size: CGSize) {
        guard size != sheetSize else { return }
        if usingTool { pendingSheetSize = size; return }
        sheetSize = size
        // UIScrollView's content size is in the current zoomed coordinate space.
        // Never reset PencilKit to zoom 1 while it is committing a stroke.
        contentSize = CGSize(width: size.width * zoomScale, height: size.height * zoomScale)
    }
    func finishedUsingTool() {
        usingTool = false
        if let size = pendingSheetSize { pendingSheetSize = nil; setSheetSize(size) }
    }
    func beganUserZooming() {
        if !updatingViewport, pinchGestureRecognizer?.state == .began { followsFit = false }
    }
    override func didMoveToWindow() {
        #if DEBUG
        MarginRenderDiagnostics.recordCanvas("didMoveToWindow enter", canvas: self)
        #endif
        super.didMoveToWindow()
        #if DEBUG
        MarginRenderDiagnostics.recordCanvas("didMoveToWindow before responder", canvas: self)
        #endif
        if window != nil { becomeFirstResponder() }
        #if DEBUG
        MarginRenderDiagnostics.recordCanvas("didMoveToWindow return", canvas: self)
        #endif
    }
    override func layoutSubviews() {
        let changed = bounds.size != previousBounds
        let oldSize = previousBounds
        let center = CGPoint(x: (contentOffset.x + oldSize.width / 2) / max(zoomScale, 0.01),
                             y: (contentOffset.y + oldSize.height / 2) / max(zoomScale, 0.01))
        previousBounds = bounds.size
        super.layoutSubviews()
        #if DEBUG
        if changed { MarginRenderDiagnostics.recordCanvas("layout bounds changed old=\(oldSize)", canvas: self) }
        #endif
        guard changed, bounds.width > 0, bounds.height > 0 else { return }
        if followsFit { fitContent() }
        else {
            contentOffset = CGPoint(x: max(-contentInset.left, center.x * zoomScale - bounds.width / 2),
                                    y: max(-contentInset.top, center.y * zoomScale - bounds.height / 2))
        }
    }
    func fitSheet() {
        fitsWidth = false; fitContent()
    }
    func fitWidth() {
        fitsWidth = true; fitContent()
    }
    private func fitContent() {
        guard !updatingViewport, bounds.width > 0, bounds.height > 0 else { return }
        updatingViewport = true
        defer { updatingViewport = false }
        followsFit = true
        let sheet = CGRect(origin: .zero, size: sheetSize).union(drawing.bounds)
        let scale = fitsWidth ? bounds.width / sheet.width : min(bounds.width / sheet.width, bounds.height / sheet.height)
        minimumZoomScale = min(0.1, scale)
        maximumZoomScale = max(4, scale)
        zoomScale = scale
        contentSize = CGSize(width: sheetSize.width * scale, height: sheetSize.height * scale)
        let horizontalGap = max(0, (bounds.width - sheet.width * scale) / 2)
        // Writing starts at the top of a width-fit pane. Centering a short
        // sheet in a tall split leaves an invisible, non-drawable gap above it.
        let verticalGap = fitsWidth ? 0 : max(0, (bounds.height - sheet.height * scale) / 2)
        contentInset = UIEdgeInsets(top: max(0, -sheet.minY * scale) + verticalGap,
                                   left: max(0, -sheet.minX * scale) + horizontalGap,
                                   bottom: verticalGap, right: horizontalGap)
        contentOffset = CGPoint(x: sheet.minX * scale - horizontalGap, y: sheet.minY * scale - verticalGap)
    }
}
@MainActor final class MarginEditorState: ObservableObject {
    @Published var handwriting = false
    @Published var drawing = true
    @Published var brush: InkBrush = .pen
    @Published var color = TayyaTheme.brandInk
    @Published var width = 3.0
}
@MainActor final class MarginCanvasControl: ObservableObject {
    weak var canvas: MarginCanvas?
    func action(_ name: String) {
        switch name {
        case "fit": canvas?.fitSheet()
        case "fitWidth": canvas?.fitWidth()
        case "undo": canvas?.undoManager?.undo()
        case "redo": canvas?.undoManager?.redo()
        default: break
        }
    }
}
enum InkBrush: String, CaseIterable, Identifiable, Codable {
    case pen = "قلم", pencil = "رصاص", marker = "تظليل", eraser = "ممحاة", selection = "تحديد"
    var id: String { rawValue }
    var symbol: String {
        switch self { case .pen: return "pencil.tip"; case .pencil: return "pencil"; case .marker: return "highlighter"; case .eraser: return "eraser"; case .selection: return "lasso" }
    }
    func tool(color: UIColor, width: CGFloat) -> PKTool {
        switch self {
        case .pen: return PKInkingTool(.pen, color: color, width: width)
        case .pencil: return PKInkingTool(.pencil, color: color, width: width)
        case .marker: return PKInkingTool(.marker, color: color.withAlphaComponent(0.4), width: width * 4)
        case .eraser: return PKEraserTool(.vector)
        case .selection: return PKLassoTool()
        }
    }
}
struct InkToolbar: View {
    @ObservedObject var localization = TayyaLocalization.shared
    @Binding var brush: InkBrush
    @Binding var color: Color
    @Binding var width: Double
    @State private var showingColorPicker = false
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var typeSize
    var allowsWidthFit = false
    var compact = false
    let action: (String) -> Void
    var body: some View {
        InkToolbarScrollView {
            HStack(spacing: 6) {
                FavoritePenMenu(brush: $brush, color: $color, width: $width)
                Menu {
                    ForEach(InkBrush.allCases.filter { $0 != .selection }) { item in
                        Button(TayyaLocalized(item.rawValue), systemImage: item.symbol) {
                            brush = item
                            NativeToolActionTrace.record("brush=\(brush.rawValue); width=\(width)")
                        }.accessibilityIdentifier("inkBrushOption-\(item.symbol)")
                    }
                }
                label: {
                    Group {
                        if compact { Label(TayyaLocalized(brush.rawValue), systemImage: brush.symbol).labelStyle(.iconOnly).font(.system(size: TayyaMetrics.icon)) }
                        else { Label(TayyaLocalized(brush.rawValue), systemImage: brush.symbol) }
                    }.frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                }.accessibilityIdentifier("inkBrush").accessibilityValue(TayyaLocalized(brush.rawValue))
                Button { showingColorPicker = true } label: {
                    Circle().fill(color)
                        .overlay(Circle().strokeBorder(TayyaTheme.detail, lineWidth: 1))
                        .frame(width: 28, height: 28)
                        .frame(width: 44, height: 44).contentShape(Rectangle())
                }.accessibilityLabel("لون الحبر").accessibilityValue(currentColorValue).accessibilityIdentifier("inkColor")
                Menu {
                    ForEach([1, 2, 3, 5, 8, 12], id: \.self) { value in
                        Button("سماكة \(value)") {
                            width = Double(value)
                            NativeToolActionTrace.record("width=\(width); brush=\(brush.rawValue)")
                        }.accessibilityIdentifier("inkWidthOption-\(value)")
                    }
                }
                label: {
                    Group {
                        if compact && typeSize >= .accessibility3 { Image(systemName: "slider.horizontal.3").font(.system(size: TayyaMetrics.icon)) }
                        else { Text("\(Int(width))").monospacedDigit().padding(6).background(.quaternary, in: Circle()) }
                    }.frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                }.accessibilityLabel("سماكة القلم").accessibilityValue("\(Int(width))").accessibilityIdentifier("inkWidth")
                Button { action("undo") } label: { inkTarget("تراجع", symbol: "arrow.uturn.backward") }
                    .accessibilityIdentifier("inkUndo")
                Button { action("redo") } label: { inkTarget("إعادة", symbol: "arrow.uturn.forward") }
                    .accessibilityIdentifier("inkRedo")
                Button { action("fit") } label: { inkTarget("إظهار الورقة كاملة", symbol: "arrow.up.left.and.arrow.down.right") }
                    .accessibilityIdentifier("fitMargin")
                if allowsWidthFit {
                    Button { action("fitWidth") } label: { inkTarget("عرض مناسب للكتابة", symbol: "arrow.left.and.right") }
                        .accessibilityIdentifier("fitMarginWidth")
                }
            }.buttonStyle(.plain).padding(.horizontal, 4)
                .padding(.vertical, compact ? 0 : verticalSizeClass == .compact ? 2 : 8)
        }
        // This is a spatial tool rail, not prose. Keep its scroll axis and
        // bounds left-to-right even inside the Arabic/right-to-left workspace:
        // native hit targets must remain reachable on compact and split panes.
        // Arabic labels keep their own glyph shaping and accessibility names.
        .environment(\.layoutDirection, .leftToRight)
        .background(TayyaTheme.surface)
        .accessibilityIdentifier("inkToolbar")
        .sheet(isPresented: $showingColorPicker) {
            NativeInkColorPicker(color: $color, isPresented: $showingColorPicker)
                .presentationDetents([.large])
        }
    }
    private var currentColorValue: String {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        guard UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return "" }
        return String(format: "rgba:%.4f,%.4f,%.4f,%.4f", Double(red), Double(green), Double(blue), Double(alpha))
    }
    private func inkTarget(_ title: String, symbol: String) -> some View {
        Label(TayyaLocalized(title), systemImage: symbol).labelStyle(.iconOnly).font(.system(size: TayyaMetrics.icon))
            .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
    }
}
private struct NativeInkColorPicker: UIViewControllerRepresentable {
    @Binding var color: Color
    @Binding var isPresented: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(color: $color, isPresented: $isPresented)
    }

    func makeUIViewController(context: Context) -> UIColorPickerViewController {
        // A real sheet owns the native picker. Do not present a second modal
        // from a transparent view controller inside the scrolling toolbar.
        let picker = UIColorPickerViewController()
        picker.supportsAlpha = false
        picker.selectedColor = UIColor(color)
        picker.delegate = context.coordinator
        picker.view.accessibilityIdentifier = "nativeInkColorPicker"
        picker.view.accessibilityViewIsModal = true

        let done = UIButton(type: .system)
        done.setTitle("تم", for: .normal)
        done.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        done.titleLabel?.adjustsFontForContentSizeCategory = true
        done.accessibilityIdentifier = "closeInkColorPicker"
        done.addTarget(context.coordinator, action: #selector(Coordinator.closePicker), for: .touchUpInside)
        done.translatesAutoresizingMaskIntoConstraints = false
        picker.view.addSubview(done)
        let safe = picker.view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            done.topAnchor.constraint(equalTo: safe.topAnchor, constant: 8),
            done.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -16),
            done.leadingAnchor.constraint(greaterThanOrEqualTo: safe.leadingAnchor, constant: 16),
            done.widthAnchor.constraint(greaterThanOrEqualToConstant: 44),
            done.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
        return picker
    }

    func updateUIViewController(_ picker: UIColorPickerViewController, context: Context) {
        context.coordinator.color = $color
        context.coordinator.isPresented = $isPresented
        let selected = UIColor(color)
        if !picker.selectedColor.isEqual(selected) {
            picker.selectedColor = selected
        }
    }

    final class Coordinator: NSObject, UIColorPickerViewControllerDelegate {
        var color: Binding<Color>
        var isPresented: Binding<Bool>
        init(color: Binding<Color>, isPresented: Binding<Bool>) {
            self.color = color
            self.isPresented = isPresented
        }

        func colorPickerViewController(_ viewController: UIColorPickerViewController,
                                       didSelect selectedColor: UIColor, continuously: Bool) {
            color.wrappedValue = Color(uiColor: selectedColor)
        }

        func colorPickerViewControllerDidFinish(_ viewController: UIColorPickerViewController) {
            isPresented.wrappedValue = false
        }

        @objc func closePicker() {
            isPresented.wrappedValue = false
        }
    }
}
struct MarginNotebook: UIViewRepresentable {
    let page: MarginPage
    let drawing: Bool
    let brush: InkBrush
    let color: Color
    let width: Double
    let control: MarginCanvasControl
    let saved: (PKDrawing) -> Void
    let failed: (String) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(saved: saved, failed: failed) }
    func makeUIView(context: Context) -> MarginCanvas {
        #if DEBUG
        MarginRenderDiagnostics.record("makeUIView enter page=\(page.id); control=\(ObjectIdentifier(control))")
        #endif
        let canvas = MarginCanvas()
        // PencilKit owns clipping of its zoomed tiles at the viewport boundary.
        // An additional SwiftUI mask must not wrap the native drawing surface.
        canvas.clipsToBounds = true
        canvas.backgroundColor = PaperColor.cream.uiColor
        canvas.drawingPolicy = .anyInput
        canvas.contentInsetAdjustmentBehavior = .never
        // Sheet coordinates keep their origin on the left in the Arabic UI too.
        canvas.semanticContentAttribute = .forceLeftToRight
        canvas.delegate = context.coordinator
        canvas.bounces = false
        canvas.isAccessibilityElement = true
        canvas.accessibilityIdentifier = "marginInkCanvas"
        canvas.accessibilityLabel = "ورقة الملاحظات بخط اليد"
        configure(canvas, context: context)
        #if DEBUG
        MarginRenderDiagnostics.recordCanvas("makeUIView return page=\(page.id); control=\(ObjectIdentifier(control))", canvas: canvas)
        #endif
        return canvas
    }
    #if DEBUG
    func updateUIView(_ canvas: MarginCanvas, context: Context) {
        MarginRenderDiagnostics.recordCanvas("updateUIView enter page=\(page.id); control=\(ObjectIdentifier(control))", canvas: canvas)
        configure(canvas, context: context)
        MarginRenderDiagnostics.recordCanvas("updateUIView return page=\(page.id); control=\(ObjectIdentifier(control))", canvas: canvas)
    }
    static func dismantleUIView(_ canvas: MarginCanvas, coordinator: Coordinator) {
        MarginRenderDiagnostics.recordCanvas("dismantleUIView page=\(coordinator.pageID?.uuidString ?? "missing")", canvas: canvas)
    }
    #else
    func updateUIView(_ canvas: MarginCanvas, context: Context) { configure(canvas, context: context) }
    #endif
    private func configure(_ canvas: MarginCanvas, context: Context) {
        let coordinator = context.coordinator
        coordinator.saved = saved; coordinator.failed = failed; control.canvas = canvas
        // Keep PencilKit's live strokes authoritative until the active gesture ends.
        // A SwiftUI re-render must not reload stale bytes over an in-flight stroke.
        if coordinator.pageID != page.id || (!coordinator.isStroking && coordinator.lastInk != page.ink) {
            coordinator.loading = true
            do {
                let ink = page.ink.isEmpty ? PKDrawing() : try PKDrawing(data: page.ink)
                canvas.drawing = ink
                canvas.undoManager?.removeAllActions()
                canvas.setSheetSize(CGSize(width: page.width, height: page.height))
                canvas.contentSize = CGSize(width: canvas.sheetSize.width * canvas.zoomScale, height: canvas.sheetSize.height * canvas.zoomScale)
                canvas.fitWidth(); coordinator.pageID = page.id; coordinator.lastInk = page.ink
                canvas.accessibilityValue = String(ink.strokes.count)
            } catch { failed(error.localizedDescription) }
            coordinator.loading = false
        }
        let size = CGSize(width: page.width, height: page.height)
        if canvas.sheetSize != size {
            canvas.setSheetSize(size)
        }
        if canvas.drawingGestureRecognizer.isEnabled != drawing {
            canvas.drawingGestureRecognizer.isEnabled = drawing
        }
        let panTouches = drawing ? 2 : 1
        if canvas.panGestureRecognizer.minimumNumberOfTouches != panTouches {
            canvas.panGestureRecognizer.minimumNumberOfTouches = panTouches
        }
        coordinator.applyTool(to: canvas, brush: brush, color: color, width: width)
    }
    @MainActor final class Coordinator: NSObject, PKCanvasViewDelegate {
        var pageID: UUID?
        var lastInk: Data?
        var loading = false
        var isStroking = false
        private var hasUncommittedStroke = false
        private var appliedBrush: InkBrush?
        private var appliedColor: Color?
        private var appliedWidth: Double?
        var saved: (PKDrawing) -> Void
        var failed: (String) -> Void
        init(saved: @escaping (PKDrawing) -> Void, failed: @escaping (String) -> Void) { self.saved = saved; self.failed = failed }
        func applyTool(to canvas: PKCanvasView, brush: InkBrush, color: Color, width: Double) {
            // Saving a stroke publishes a new page and updates this representable.
            // Do not replace PencilKit's tool while that same stroke is committing.
            guard appliedBrush != brush || appliedColor != color || appliedWidth != width else { return }
            canvas.tool = brush.tool(color: UIColor(color), width: width)
            appliedBrush = brush; appliedColor = color; appliedWidth = width
        }
        private func persist(_ canvas: PKCanvasView) {
            let data = canvas.drawing.dataRepresentation()
            guard data != lastInk else { return }
            lastInk = data
            saved(canvas.drawing)
        }
        func canvasViewDrawingDidChange(_ canvas: PKCanvasView) {
            guard !loading else { return }
            canvas.accessibilityValue = String(canvas.drawing.strokes.count)
            if isStroking {
                // Do not serialize and synchronously write every PencilKit frame.
                hasUncommittedStroke = true
            } else {
                persist(canvas) // Undo, redo, and programmatic drawing changes.
            }
        }
        func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
            isStroking = true
            (canvasView as? MarginCanvas)?.usingTool = true
        }
        func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
            isStroking = false
            if hasUncommittedStroke {
                hasUncommittedStroke = false
                persist(canvasView)
            }
            (canvasView as? MarginCanvas)?.finishedUsingTool()
        }
        func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) { (scrollView as? MarginCanvas)?.beganUserZooming() }
        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) { (scrollView as? MarginCanvas)?.followsFit = false }
    }
}
