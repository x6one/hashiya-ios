import SwiftUI
import UIKit

/// Semantic colors adapt to the system appearance without tinting PDF pages.
enum TayyaTheme {
    static let paper = adaptive(light: (0.97, 0.95, 0.90), dark: (0.055, 0.09, 0.08))
    static let surface = adaptive(light: (1, 0.99, 0.96), dark: (0.10, 0.15, 0.13))
    static let ink = adaptive(light: (0.07, 0.25, 0.22), dark: (0.75, 0.88, 0.79))
    static let fold = adaptive(light: (0.68, 0.32, 0.19), dark: (0.90, 0.56, 0.36))
    static let brandInk = Color(red: 0.07, green: 0.25, blue: 0.22)
    static let ivory = Color(red: 0.965, green: 0.925, blue: 0.85)
    private static func adaptive(light: (CGFloat, CGFloat, CGFloat), dark: (CGFloat, CGFloat, CGFloat)) -> Color {
        Color(uiColor: UIColor { traits in
            let value = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: value.0, green: value.1, blue: value.2, alpha: 1)
        })
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
