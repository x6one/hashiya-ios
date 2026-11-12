import XCTest
import UIKit
import PencilKit
@testable import Hashiya

final class PrecisionInkTests: XCTestCase {
    private func stroke(_ points: [CGPoint], ink: PKInk = PKInk(.pen, color: .red), widths: [CGFloat]? = nil, transform: CGAffineTransform = .identity) -> PKStroke {
        let samples = points.enumerated().map { i, point in
            PKStrokePoint(location: point, timeOffset: Double(i) * 0.02,
                size: CGSize(width: widths?[i] ?? 4, height: widths?[i] ?? 4),
                opacity: 0.8, force: 0.6, azimuth: 0.3, altitude: 1.2)
        }
        return PKStroke(ink: ink, path: PKStrokePath(controlPoints: samples, creationDate: Date(timeIntervalSince1970: 100)), transform: transform)
    }
    private func unchanged(_ a: PKStroke, _ b: PKStroke, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(a.ink.inkType, b.ink.inkType, file: file, line: line)
        XCTAssertEqual(a.ink.color, b.ink.color, file: file, line: line)
        XCTAssertEqual(a.transform, b.transform, file: file, line: line)
        XCTAssertEqual(a.path.creationDate, b.path.creationDate, file: file, line: line)
        XCTAssertEqual(a.path.count, b.path.count, file: file, line: line)
        for i in 0..<min(a.path.count, b.path.count) {
            XCTAssertEqual(a.path[i].location, b.path[i].location, file: file, line: line)
            XCTAssertEqual(a.path[i].size, b.path[i].size, file: file, line: line)
            XCTAssertEqual(a.path[i].force, b.path[i].force, file: file, line: line)
            XCTAssertEqual(a.path[i].opacity, b.path[i].opacity, file: file, line: line)
            XCTAssertEqual(a.path[i].timeOffset, b.path[i].timeOffset, file: file, line: line)
        }
    }
    func testStraighteningOnlySelectedMiddleStrokePreservesOrderAndStyle() throws {
        let first = stroke([CGPoint(x: 1, y: 2), CGPoint(x: 3, y: 4)])
        let middle = stroke([CGPoint(x: 10, y: 40), CGPoint(x: 70, y: 49), CGPoint(x: 130, y: 40)], transform: CGAffineTransform(translationX: 15, y: 23))
        let last = stroke([CGPoint(x: 2, y: 90), CGPoint(x: 20, y: 110)])
        let edited = try XCTUnwrap(InkStrokeEditing.applying(.straighten, to: PKDrawing(strokes: [first, middle, last]), indices: [1]))
        XCTAssertEqual(edited.strokes.count, 3)
        unchanged(first, edited.strokes[0]); unchanged(last, edited.strokes[2])
        let changed = edited.strokes[1]
        XCTAssertEqual(changed.path.first?.location, middle.path.first?.location)
        XCTAssertEqual(changed.path.last?.location, middle.path.last?.location)
        XCTAssertEqual(changed.transform, middle.transform)
        XCTAssertEqual(changed.ink.color, middle.ink.color)
        XCTAssertEqual(changed.path.creationDate, middle.path.creationDate)
        for point in changed.path { XCTAssertEqual(point.location.y, 40, accuracy: 0.001) }
    }
    func testTapHitsInterpolatedSegmentAndHonorsStrokeTransform() {
        let path = stroke([.zero, CGPoint(x: 100, y: 0)], transform: CGAffineTransform(translationX: 100, y: 50))
        XCTAssertEqual(InkStrokeEditing.hitIndex(in: PKDrawing(strokes: [path]), at: CGPoint(x: 150, y: 50), tolerance: 3), 0)
        XCTAssertNil(InkStrokeEditing.hitIndex(in: PKDrawing(strokes: [path]), at: CGPoint(x: 150, y: 80), tolerance: 3))
    }
    func testOverlappingHitChoosesTopmostStroke() {
        let path = stroke([.zero, CGPoint(x: 100, y: 0)])
        XCTAssertEqual(InkStrokeEditing.hitIndex(in: PKDrawing(strokes: [path, path]), at: CGPoint(x: 50, y: 0), tolerance: 3), 1)
    }
    func testRecolorPreservesMarkerAlphaAndPointAttributes() throws {
        let old = stroke([.zero, CGPoint(x: 100, y: 0)], ink: PKInk(.marker, color: UIColor.yellow.withAlphaComponent(0.4)))
        let result = try XCTUnwrap(InkStrokeEditing.applying(.recolor(.blue), to: PKDrawing(strokes: [old]), indices: [0])).strokes[0]
        XCTAssertEqual(result.ink.inkType, .marker)
        XCTAssertEqual(result.ink.color.cgColor.alpha, 0.4, accuracy: 0.001)
        XCTAssertEqual(result.ink.color, UIColor.blue.withAlphaComponent(0.4))
        XCTAssertEqual(result.path[0].location, old.path[0].location)
        XCTAssertEqual(result.path[0].size, old.path[0].size)
        XCTAssertEqual(result.path[0].opacity, old.path[0].opacity)
    }
    func testWidthEditScalesPressureProfileWithoutMovingInk() throws {
        let old = stroke([.zero, CGPoint(x: 50, y: 4), CGPoint(x: 100, y: 0)], widths: [2, 4, 6])
        let result = try XCTUnwrap(InkStrokeEditing.applying(.width(6), to: PKDrawing(strokes: [old]), indices: [0])).strokes[0]
        for i in 0..<3 {
            XCTAssertEqual(result.path[i].location, old.path[i].location)
            XCTAssertEqual(result.path[i].size.width, old.path[i].size.width * 1.5, accuracy: 0.001)
            XCTAssertEqual(result.path[i].force, old.path[i].force)
        }
    }
    func testLineIsConstantWidthAndRetainsEndpoints() throws {
        let date = Date(timeIntervalSince1970: 42)
        let line = try XCTUnwrap(InkStrokeEditing.line(from: CGPoint(x: 10, y: 20), to: CGPoint(x: 170, y: 25), ink: PKInk(.marker, color: UIColor.cyan.withAlphaComponent(0.4)), width: 16, creationDate: date))
        XCTAssertEqual(line.path.first?.location, CGPoint(x: 10, y: 20))
        XCTAssertEqual(line.path.last?.location, CGPoint(x: 170, y: 25))
        XCTAssertEqual(line.path.creationDate, date)
        XCTAssertEqual(line.ink.inkType, .marker)
        for point in line.path { XCTAssertEqual(point.size, CGSize(width: 16, height: 16)); XCTAssertEqual(point.force, 1) }
    }
    func testEndpointAdjustmentPreservesTransformDateAndUnaffectedStroke() throws {
        let old = stroke([CGPoint(x: 10, y: 20), CGPoint(x: 60, y: 20), CGPoint(x: 110, y: 20)], transform: CGAffineTransform(translationX: 5, y: 7))
        let other = stroke([CGPoint(x: 20, y: 150), CGPoint(x: 80, y: 150)])
        let result = try XCTUnwrap(InkStrokeEditing.applying(.endpoints(start: CGPoint(x: 0, y: 30), end: CGPoint(x: 200, y: 30)), to: PKDrawing(strokes: [old, other]), indices: [0]))
        XCTAssertEqual(result.strokes[0].path.first?.location, CGPoint(x: 0, y: 30))
        XCTAssertEqual(result.strokes[0].path.last?.location, CGPoint(x: 200, y: 30))
        XCTAssertEqual(result.strokes[0].path[1].location, CGPoint(x: 100, y: 30))
        XCTAssertEqual(result.strokes[0].transform, old.transform)
        XCTAssertEqual(result.strokes[0].path.creationDate, old.path.creationDate)
        XCTAssertEqual(result.strokes[0].path[1].force, old.path[1].force)
        unchanged(result.strokes[1], other)
    }
    func testPartialErasureMaskSurvivesColorEditAndCannotBeSilentlyDiscarded() throws {
        var old = stroke([.zero, CGPoint(x: 100, y: 0)])
        old.mask = UIBezierPath(rect: CGRect(x: 10, y: -10, width: 60, height: 20))
        let original = PKDrawing(strokes: [old])
        let edited = try XCTUnwrap(InkStrokeEditing.applying(.recolor(.blue), to: original, indices: [0]))
        XCTAssertEqual(edited.strokes[0].mask?.bounds, old.mask?.bounds)
        XCTAssertNil(InkStrokeEditing.applying(.straighten, to: original, indices: [0]))
        XCTAssertNil(InkStrokeEditing.hitIndex(in: original, at: CGPoint(x: 90, y: 0), tolerance: 2))
        XCTAssertEqual(InkStrokeEditing.hitIndex(in: original, at: CGPoint(x: 30, y: 0), tolerance: 2), 0)
    }
    func testInvalidSelectionAndWidthsNeverChangeDrawing() {
        let drawing = PKDrawing(strokes: [stroke([.zero, CGPoint(x: 100, y: 0)])])
        XCTAssertNil(InkStrokeEditing.applying(.straighten, to: drawing, indices: [0, 8]))
        XCTAssertNil(InkStrokeEditing.applying(.width(.nan), to: drawing, indices: [0]))
        XCTAssertNil(InkStrokeEditing.applying(.width(0), to: drawing, indices: [0]))
        XCTAssertNil(InkStrokeEditing.line(from: .zero, to: .zero, ink: PKInk(.pen, color: .red), width: 3, creationDate: Date()))
    }
}
