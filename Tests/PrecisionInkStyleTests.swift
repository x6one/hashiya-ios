import XCTest
import SwiftUI
import UIKit
import PencilKit
@testable import Hashiya

/// Regression for the pre-existing rule: publishing the same ink settings
/// must not replace PencilKit's tool during a native stroke commit.
final class PrecisionInkStyleTests: XCTestCase {
    @MainActor func testEquivalentPickerColorDoesNotReplaceToolOnRepeatedOrQueuedConfiguration() {
        let colors = [Color.red,
                      Color(uiColor: UIColor(red: 1, green: 0.709793, blue: 0.686264, alpha: 1)),
                      Color(uiColor: UIColor(red: 0.07, green: 0.25, blue: 0.22, alpha: 1))]
        for color in colors {
            let canvas = ToolAssignmentCanvas(frame: CGRect(x: 0, y: 0, width: 500, height: 700))
            let owner = PrecisionInkController(canvas: canvas)
            func configure() {
                owner.configure(mode: .freehand, selection: false, ruler: false,
                                brush: .pencil, color: UIColor(color), width: 8, enabled: true)
            }
            configure()
            let assignments = canvas.toolAssignments
            configure()
            XCTAssertEqual(canvas.toolAssignments, assignments, "An unchanged SwiftUI update must not replace the native tool")
            owner.nativeToolBegan()
            configure()
            XCTAssertEqual(canvas.toolAssignments, assignments, "The live stroke must keep its native tool")
            owner.nativeToolEnded()
            XCTAssertEqual(canvas.toolAssignments, assignments, "An unchanged queued configuration must not replace the tool inside native completion")
        }
    }
}

@MainActor private final class ToolAssignmentCanvas: PKCanvasView {
    var toolAssignments = 0
    override var tool: PKTool { didSet { toolAssignments += 1 } }
}
