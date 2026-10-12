import SwiftUI
import UIKit

/// Semantic colors adapt to the system appearance without tinting PDF pages.
enum TayyaTheme {
    static let paper = adaptive(light: (0.975, 0.96, 0.925), dark: (0.065, 0.085, 0.075))
    static let surface = adaptive(light: (1, 1, 0.99), dark: (0.11, 0.145, 0.125))
    static let mutedSurface = adaptive(light: (0.945, 0.93, 0.89), dark: (0.145, 0.18, 0.155))
    static let separator = adaptive(light: (0.83, 0.84, 0.79), dark: (0.29, 0.35, 0.30))
    static let selection = adaptive(light: (0.88, 0.925, 0.88), dark: (0.16, 0.25, 0.20))
    static let text = adaptive(light: (0.14, 0.19, 0.17), dark: (0.925, 0.94, 0.90))
    static let detail = adaptive(light: (0.38, 0.43, 0.40), dark: (0.67, 0.74, 0.69))
    static let ink = adaptive(light: (0.07, 0.25, 0.22), dark: (0.75, 0.88, 0.79))
    static let copper = adaptive(light: (0.59, 0.30, 0.18), dark: (0.90, 0.60, 0.41))
    static let fold = copper
    static let brandInk = Color(red: 0.07, green: 0.25, blue: 0.22)
    static let ivory = Color(red: 0.965, green: 0.925, blue: 0.85)
    private static func adaptive(light: (CGFloat, CGFloat, CGFloat), dark: (CGFloat, CGFloat, CGFloat)) -> Color {
        Color(uiColor: UIColor { traits in
            let value = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: value.0, green: value.1, blue: value.2, alpha: 1)
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
