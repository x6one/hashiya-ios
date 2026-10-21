import XCTest
import PencilKit
import UIKit
@testable import Hashiya

final class StudioNativeInkInspectionTests: XCTestCase {
    @MainActor func testSavedInkInspectionRendersActualRedStrokeWithoutChangingOriginalFiles() throws {
        let temporary = FileManager.default.temporaryDirectory
        let root = temporary.appendingPathComponent("ReviewEntry-" + UUID().uuidString)
        let output = temporary.appendingPathComponent("Inspection-" + UUID().uuidString)
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: output)
        }
        let pages = MarginPages(root: root, notebook: UUID())
        let id = try XCTUnwrap(pages.currentID)
        func stroke(_ color: UIColor, y: CGFloat) -> PKStroke {
            let points = [CGPoint(x: 70, y: y), CGPoint(x: 400, y: y + 20)].enumerated().map { index, point in
                PKStrokePoint(location: point, timeOffset: Double(index) * 0.25, size: CGSize(width: 10, height: 10),
                              opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
            }
            return PKStroke(ink: PKInk(.pen, color: color), path: PKStrokePath(controlPoints: points, creationDate: Date()))
        }
        pages.saveInk(PKDrawing(strokes: [stroke(.green, y: 110), stroke(.red, y: 55)]), page: id)
        XCTAssertTrue(pages.saved)
        func originalBytes() throws -> [String: Data] {
            let paths = try FileManager.default.subpathsOfDirectory(atPath: root.path)
            var result: [String: Data] = [:]
            for path in paths {
                let file = root.appendingPathComponent(path)
                if (try file.resourceValues(forKeys: [.isRegularFileKey])).isRegularFile == true {
                    result[path] = try Data(contentsOf: file)
                }
            }
            return result
        }
        let before = try originalBytes()
        let report = try NativeInkInspection.export(roots: [root], to: output)
        let rows = try XCTUnwrap(report["drawings"] as? [[String: Any]])
        XCTAssertEqual(rows.count, 1)
        let row = try XCTUnwrap(rows.first)
        XCTAssertEqual(row["stroke_count"] as? Int, 2)
        XCTAssertGreaterThan(try XCTUnwrap(row["red_pixels"] as? Int), 40)
        XCTAssertGreaterThan(try XCTUnwrap(row["last_stroke_red_pixels"] as? Int), 40)
        XCTAssertEqual(report["errors"] as? [String], [])
        XCTAssertNotNil(UIImage(data: try Data(contentsOf: output.appendingPathComponent("000.png"))))
        XCTAssertEqual(try originalBytes(), before, "Inspecting saved ink must preserve every input byte and filename")
    }
}
