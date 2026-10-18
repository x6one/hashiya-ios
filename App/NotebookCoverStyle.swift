import SwiftUI
import UIKit

enum NotebookCoverStyle {
    // Muted green, sage, sand, and copper. Static adaptive colors avoid new storage.
    private static let palette: [Color] = [
        adaptive(light: (0.24, 0.43, 0.35), dark: (0.27, 0.43, 0.35)),
        adaptive(light: (0.63, 0.72, 0.58), dark: (0.39, 0.49, 0.36)),
        adaptive(light: (0.84, 0.75, 0.59), dark: (0.53, 0.45, 0.32)),
        adaptive(light: (0.72, 0.49, 0.35), dark: (0.56, 0.36, 0.25))
    ]

    static func color(for id: UUID) -> Color {
        // FNV-1a over UUID's sixteen bytes is stable across launches and devices.
        let value = withUnsafeBytes(of: id.uuid) { bytes in
            bytes.reduce(UInt64(14_695_981_039_346_656_037)) { hash, byte in
                (hash ^ UInt64(byte)) &* 1_099_511_628_211
            }
        }
        return palette[Int(value % UInt64(palette.count))]
    }

    private static func adaptive(light: (CGFloat, CGFloat, CGFloat), dark: (CGFloat, CGFloat, CGFloat)) -> Color {
        Color(uiColor: UIColor { traits in
            let value = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: value.0, green: value.1, blue: value.2, alpha: 1)
        })
    }
}
