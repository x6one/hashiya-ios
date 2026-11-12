import XCTest
import SwiftUI
import UIKit

/// Checks the suspected SwiftUI-to-UIKit color boundary without overriding
/// PencilKit's non-open tool property or changing production code for observation.
final class PrecisionInkStyleTests: XCTestCase {
    @MainActor func testRepeatedSwiftUIColorConversionsCompareEqualForNativeToolConfiguration() {
        let colors = [Color.red,
                      Color(uiColor: UIColor(red: 1, green: 0.709793, blue: 0.686264, alpha: 1)),
                      Color(uiColor: UIColor(red: 0.07, green: 0.25, blue: 0.22, alpha: 1))]
        for color in colors {
            let first = UIColor(color)
            XCTAssertEqual(first, UIColor(color),
                           "Repeated conversion must compare equal for the controller's unchanged-style guard")
            XCTAssertEqual(first, UIColor(Color(uiColor: first)),
                           "The native picker round trip must retain color equality")
        }
    }
}
