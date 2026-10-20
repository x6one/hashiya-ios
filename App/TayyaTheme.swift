import SwiftUI
import UIKit

/// Semantic colors adapt to the system appearance without tinting PDF pages.
enum TayyaTheme {
    static let paper = adaptive(0xF8F7F3, 0x151E1B)
    static let surface = adaptive(0xFFFFFF, 0x202C27)
    static let mutedSurface = adaptive(0xE9EFEA, 0x314A3E)
    static let separator = adaptive(0xDEE3DE, 0x405147)
    static let selection = adaptive(0xE9EFEA, 0x314A3E)
    static let text = adaptive(0x282C2B, 0xF1F3EE)
    static let detail = adaptive(0x5E6963, 0xB0BDB5)
    static let ink = adaptive(0x244C43, 0xB9D8C9)
    static let onInk = adaptive(0xFFFFFF, 0x151E1B)
    static let copper = adaptive(0xC48F68, 0xD5A583)
    static let destructive = adaptive(0xA83432, 0xFFB4AB)
    static let fold = copper
    // Drawing defaults are appearance-independent. Never resolve chrome into ink.
    static let brandInk = Color(red: 0.07, green: 0.25, blue: 0.22)
    static let ivory = Color(red: 0.965, green: 0.925, blue: 0.85)
    private static func adaptive(_ light: Int, _ dark: Int) -> Color {
        Color(uiColor: UIColor { traits in
            let value = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((value >> 16) & 255) / 255,
                           green: CGFloat((value >> 8) & 255) / 255,
                           blue: CGFloat(value & 255) / 255, alpha: 1)
        })
    }
}

/// A decorative dog-ear, independent of the notebook's contents or layout direction.
struct FoldedPageCorner: View {
    var size: CGFloat = 24
    var color: Color = TayyaTheme.fold

    var body: some View {
        Path { path in
            path.move(to: .zero)
            path.addLine(to: CGPoint(x: size, y: size))
            path.addLine(to: CGPoint(x: 0, y: size))
            path.closeSubpath()
        }
        .fill(color)
        .overlay {
            Path { path in
                path.move(to: .zero)
                path.addLine(to: CGPoint(x: size, y: size))
            }
            .stroke(TayyaTheme.surface.opacity(0.6), lineWidth: 1)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

/// The same folded ribbon gesture as the app icon, drawn natively for motion.
struct TayyaFold: Shape {
    func path(in rect: CGRect) -> Path {
        let x = rect.width, y = rect.height
        var p = Path()
        p.move(to: CGPoint(x: 0.08*x, y: 0.12*y))
        p.addLine(to: CGPoint(x: 0.78*x, y: 0.12*y))
        p.addQuadCurve(to: CGPoint(x: 0.87*x, y: 0.21*y), control: CGPoint(x: 0.85*x, y: 0.12*y))
        p.addLine(to: CGPoint(x: 0.91*x, y: 0.34*y))
        p.addQuadCurve(to: CGPoint(x: 0.85*x, y: 0.43*y), control: CGPoint(x: 0.94*x, y: 0.39*y))
        p.addLine(to: CGPoint(x: 0.61*x, y: 0.59*y))
        p.addQuadCurve(to: CGPoint(x: 0.58*x, y: 0.65*y), control: CGPoint(x: 0.58*x, y: 0.61*y))
        p.addLine(to: CGPoint(x: 0.58*x, y: 0.95*y))
        p.addLine(to: CGPoint(x: 0.42*x, y: 0.86*y))
        p.addQuadCurve(to: CGPoint(x: 0.35*x, y: 0.76*y), control: CGPoint(x: 0.35*x, y: 0.83*y))
        p.addLine(to: CGPoint(x: 0.35*x, y: 0.51*y))
        p.addQuadCurve(to: CGPoint(x: 0.40*x, y: 0.45*y), control: CGPoint(x: 0.35*x, y: 0.47*y))
        p.addLine(to: CGPoint(x: 0.65*x, y: 0.31*y))
        p.addLine(to: CGPoint(x: 0.25*x, y: 0.31*y))
        p.addQuadCurve(to: CGPoint(x: 0.13*x, y: 0.23*y), control: CGPoint(x: 0.17*x, y: 0.31*y))
        p.closeSubpath()
        return p
    }
}
