import SwiftUI
import UIKit

func L(_ arabic: String, _ english: String) -> String {
    ProcessInfo.processInfo.arguments.contains("--english") ? english : arabic
}

enum StudioTheme {
    static let background = color(0xF8F7F3, 0x151E1B)
    static let surface = color(0xFFFFFF, 0x202C27)
    static let primary = color(0x244C43, 0xB9D8C9)
    static let onPrimary = color(0xFFFFFF, 0x151E1B)
    static let copper = color(0xC48F68, 0xD5A583)
    static let selection = color(0xE9EFEA, 0x314A3E)
    static let text = color(0x282C2B, 0xF1F3EE)
    static let secondary = color(0x5E6963, 0xB0BDB5)
    static let divider = color(0xDEE3DE, 0x405147)
    static let destructive = color(0xA83432, 0xFFB4AB)
    static let symbols = ["plus", "magnifyingglass", "books.vertical", "folder",
                          "rectangle.stack", "gearshape", "chevron.backward", "chevron.forward",
                          "bookmark", "bookmark.fill", "square.and.arrow.up", "pencil.tip",
                          "pencil", "highlighter", "eraser", "textformat", "lasso",
                          "note.text", "square.grid.2x2", "arrow.uturn.backward", "arrow.uturn.forward",
                          "mic", "stop.fill", "play.fill", "pause.fill", "backward.end.fill",
                          "gobackward.10", "goforward.10", "flag", "sidebar.leading",
                          "arrow.up.left.and.arrow.down.right", "arrow.down.right.and.arrow.up.left",
                          "ellipsis", "checkmark", "star", "star.fill", "xmark", "waveform",
                          "doc", "doc.badge.plus", "trash", "externaldrive", "slider.horizontal.3"]

    static func ui(_ value: Int) -> UIColor {
        UIColor(red: CGFloat((value >> 16) & 255) / 255,
                green: CGFloat((value >> 8) & 255) / 255,
                blue: CGFloat(value & 255) / 255, alpha: 1)
    }

    private static func color(_ light: Int, _ dark: Int) -> Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? ui(dark) : ui(light) })
    }
}

extension View {
    func studioCard(_ padding: CGFloat = 16) -> some View {
        self.padding(padding)
            .background(StudioTheme.surface, in: RoundedRectangle(cornerRadius: 16))
            .overlay { RoundedRectangle(cornerRadius: 16).stroke(StudioTheme.divider.opacity(0.6), lineWidth: 0.5) }
    }
}

struct StudioBrand: View {
    var body: some View {
        HStack(spacing: 8) {
            StudioFold().fill(StudioTheme.primary).frame(width: 29, height: 32)
                .overlay(alignment: .topTrailing) {
                    Rectangle().fill(StudioTheme.copper).frame(width: 6, height: 6).rotationEffect(.degrees(45))
                }
            Text(L("طَيّة", "Tayya")).font(.title2.bold())
            Text("STUDIO").font(.system(size: 9, weight: .semibold)).tracking(2).foregroundStyle(StudioTheme.secondary)
        }.accessibilityElement(children: .combine)
    }
}

/// Retains the existing folded-paper identity in the isolated proposal.
struct StudioFold: Shape {
    func path(in rect: CGRect) -> Path {
        let x = rect.width, y = rect.height
        var p = Path()
        p.move(to: CGPoint(x: 0.08 * x, y: 0.12 * y))
        p.addLine(to: CGPoint(x: 0.78 * x, y: 0.12 * y))
        p.addQuadCurve(to: CGPoint(x: 0.87 * x, y: 0.21 * y), control: CGPoint(x: 0.85 * x, y: 0.12 * y))
        p.addLine(to: CGPoint(x: 0.91 * x, y: 0.34 * y))
        p.addQuadCurve(to: CGPoint(x: 0.85 * x, y: 0.43 * y), control: CGPoint(x: 0.94 * x, y: 0.39 * y))
        p.addLine(to: CGPoint(x: 0.61 * x, y: 0.59 * y))
        p.addQuadCurve(to: CGPoint(x: 0.58 * x, y: 0.65 * y), control: CGPoint(x: 0.58 * x, y: 0.61 * y))
        p.addLine(to: CGPoint(x: 0.58 * x, y: 0.95 * y))
        p.addLine(to: CGPoint(x: 0.42 * x, y: 0.86 * y))
        p.addQuadCurve(to: CGPoint(x: 0.35 * x, y: 0.76 * y), control: CGPoint(x: 0.35 * x, y: 0.83 * y))
        p.addLine(to: CGPoint(x: 0.35 * x, y: 0.51 * y))
        p.addQuadCurve(to: CGPoint(x: 0.40 * x, y: 0.45 * y), control: CGPoint(x: 0.35 * x, y: 0.47 * y))
        p.addLine(to: CGPoint(x: 0.65 * x, y: 0.31 * y))
        p.addLine(to: CGPoint(x: 0.25 * x, y: 0.31 * y))
        p.addQuadCurve(to: CGPoint(x: 0.13 * x, y: 0.23 * y), control: CGPoint(x: 0.17 * x, y: 0.31 * y))
        p.closeSubpath()
        return p
    }
}
