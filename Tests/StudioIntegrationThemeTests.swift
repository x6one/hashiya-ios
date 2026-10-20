import XCTest
import SwiftUI
import UIKit
@testable import Hashiya

final class StudioIntegrationThemeTests: XCTestCase {
    @MainActor func testApprovedChromePaletteInBothAppearances() {
        let colors: [(Color, UInt32, UInt32)] = [
            (TayyaTheme.paper, 0xF8F7F3, 0x151E1B),
            (TayyaTheme.surface, 0xFFFFFF, 0x202C27),
            (TayyaTheme.ink, 0x244C43, 0xB9D8C9),
            (TayyaTheme.copper, 0xC48F68, 0xD5A583),
            (TayyaTheme.selection, 0xE9EFEA, 0x314A3E),
            (TayyaTheme.text, 0x282C2B, 0xF1F3EE),
            (TayyaTheme.detail, 0x5E6963, 0xB0BDB5)
        ]
        for (color, light, dark) in colors {
            for (style, expected) in [(UIUserInterfaceStyle.light, light), (.dark, dark)] {
                let resolved = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
                var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
                XCTAssertTrue(resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha))
                XCTAssertEqual(red, CGFloat((expected >> 16) & 255) / 255, accuracy: 0.002)
                XCTAssertEqual(green, CGFloat((expected >> 8) & 255) / 255, accuracy: 0.002)
                XCTAssertEqual(blue, CGFloat(expected & 255) / 255, accuracy: 0.002)
                XCTAssertEqual(alpha, 1)
            }
        }
    }

    @MainActor func testChromeAppearanceDoesNotChangeStoredInkColor() {
        let ink = UIColor(TayyaTheme.brandInk)
        XCTAssertEqual(ink.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light)),
                       ink.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark)),
                       "A chrome theme change must never change persisted drawing colors")
    }
}
