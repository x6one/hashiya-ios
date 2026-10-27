// Diagnostic host for unmodified production sources; never a Tayya release.
import SwiftUI
import PencilKit

// PaperTemplates.swift also owns unrelated library creation UI. This palette
// constant is the same opaque paper used by its PaperColor.cream case.
enum PaperColor {
    case cream
    var uiColor: UIColor { UIColor(red: 1, green: 0.995, blue: 0.96, alpha: 1) }
}

#if DEBUG
// MarginPane's diagnostic transport is not part of this isolated host. No
// --test-margin-viewport flag is passed, so production diagnostics are inactive.
@MainActor enum MarginRenderDiagnostics {
    static func record(_ event: String) {}
    static func recordCanvas(_ event: String, canvas: MarginCanvas) {}
}
#endif

struct ProductionNotesControl: View {
    @ObservedObject var store: MarginPages
    @ObservedObject var editor: MarginEditorState
    let control: MarginCanvasControl

    var body: some View {
        GeometryReader { geometry in
            let landscape = geometry.size.width > geometry.size.height
            let pad = ProcessInfo.processInfo.arguments.contains("--pad-recurrence")
            // Measured original native boundary from failed9fd1, not scaled
            // iPhone geometry. Keep the actual MarginNotebook source unchanged.
            let paper = pad
                ? CGRect(x: 0, y: 251.5, width: landscape ? 560 : 405, height: landscape ? 547 : 891)
                : landscape
                ? CGRect(x: 62, y: 235.33333333333334, width: 367.3333333333333, height: 88.66666666666666)
                : CGRect(x: 0, y: 670.6666666666666, width: 440, height: 147.33333333333331)
            let rail = pad
                ? CGRect(x: 0, y: landscape ? 908 : 1252, width: geometry.size.width, height: 44)
                : landscape
                ? CGRect(x: 62, y: 324, width: 832, height: 44)
                : CGRect(x: 0, y: 818, width: 440, height: 44)
            // The recorded frames are physical window coordinates. The RTL
            // host mirrors logical x placement; compensate in this Pad-only
            // fixture while keeping the actual Notes/toolbar Arabic direction.
            let paperCenterX = pad && TayyaLocalization.shared.direction == .rightToLeft
                ? geometry.size.width - paper.midX : paper.midX
            ZStack(alignment: .topLeading) {
                if let page = store.current {
                    MarginNotebook(page: page, drawing: editor.drawing, brush: editor.brush,
                                   color: editor.color, width: editor.width, control: control,
                                   saved: { store.saveInk($0, page: page.id) }, failed: { store.error = $0 })
                        .frame(width: paper.width, height: paper.height)
                        .position(x: paperCenterX, y: paper.midY)
                }
                InkToolbar(brush: $editor.brush, color: $editor.color, width: $editor.width,
                           allowsWidthFit: true, compact: true, action: control.action)
                    .frame(width: rail.width, height: rail.height)
                    .position(x: rail.midX, y: rail.midY)
            }
        }.ignoresSafeArea()
            .environment(\.locale, TayyaLocalization.shared.locale)
            .environment(\.layoutDirection, TayyaLocalization.shared.direction)
            .modifier(DebugVisualEnvironment())
    }
}
