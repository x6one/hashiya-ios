import UIKit
import PencilKit

enum InkGeometryMode: String, CaseIterable {
    case freehand, line, highlighter
}
enum InkEditOperation {
    case straighten
    case recolor(UIColor)
    case width(CGFloat)
}

/// Value-only edits leave page ownership, persistence and native history to the canvas.
enum InkStrokeEditing {
    static func applying(_ edit: InkEditOperation, to drawing: PKDrawing, indices: [Int]) -> PKDrawing? {
        guard !indices.isEmpty, indices.allSatisfy({ drawing.strokes.indices.contains($0) }) else { return nil }
        var strokes = drawing.strokes
        for index in Set(indices) {
            var stroke = strokes[index]
            switch edit {
            case .recolor(let color):
                stroke.ink = PKInk(stroke.ink.inkType, color: color.withAlphaComponent(stroke.ink.color.cgColor.alpha))
            case .width(let width):
                guard width.isFinite, width > 0 else { return nil }
                let sizes = stroke.path.map { $0.size.width }.filter { $0.isFinite && $0 > 0 }.sorted()
                guard !sizes.isEmpty else { return nil }
                let nominal = sizes[sizes.count / 2]
                let ratio = width / nominal
                stroke.path = remapping(stroke.path) { point in
                    copy(point, size: CGSize(width: point.size.width * ratio, height: point.size.height * ratio))
                }
            case .straighten:
                // A partial eraser mask belongs to the old path. Never silently discard it
                // or move new ink outside that mask; recoloring/width remain available.
                guard stroke.mask == nil, let start = stroke.path.first?.location,
                    let end = stroke.path.last?.location, distance(start, end) > 0.01 else { return nil }
                let dx = end.x - start.x, dy = end.y - start.y
                let lengthSquared = dx * dx + dy * dy
                stroke.path = remapping(stroke.path) { point in
                    let fraction = min(1, max(0, ((point.location.x - start.x) * dx + (point.location.y - start.y) * dy) / lengthSquared))
                    return copy(point, location: CGPoint(x: start.x + fraction * dx, y: start.y + fraction * dy))
                }
            }
            strokes[index] = stroke
        }
        let result = PKDrawing(strokes: strokes)
        return result.dataRepresentation() == drawing.dataRepresentation() ? nil : result
    }

    static func hitIndex(in drawing: PKDrawing, at point: CGPoint, tolerance: CGFloat) -> Int? {
        guard point.x.isFinite, point.y.isFinite, tolerance.isFinite, tolerance >= 0 else { return nil }
        for index in drawing.strokes.indices.reversed() {
            let stroke = drawing.strokes[index]
            guard stroke.renderBounds.insetBy(dx: -tolerance, dy: -tolerance).contains(point) else { continue }
            if let mask = stroke.mask, !mask.contains(point.applying(stroke.transform.inverted())) { continue }
            let samples = Array(stroke.path.interpolatedPoints(by: .distance(3)))
            guard let first = samples.first else { continue }
            var previous = first.location.applying(stroke.transform)
            let scale = max(hypot(stroke.transform.a, stroke.transform.b), hypot(stroke.transform.c, stroke.transform.d))
            for sample in samples {
                let current = sample.location.applying(stroke.transform)
                let radius = max(sample.size.width, sample.size.height) * scale / 2
                if segmentDistance(point, previous, current) <= tolerance + radius { return index }
                previous = current
            }
        }
        return nil
    }

    static func line(from start: CGPoint, to end: CGPoint, ink: PKInk, width: CGFloat, creationDate: Date) -> PKStroke? {
        guard start.x.isFinite, start.y.isFinite, end.x.isFinite, end.y.isFinite,
            width.isFinite, width > 0, distance(start, end) > 0.01 else { return nil }
        let count = max(2, min(512, Int(ceil(distance(start, end) / 4)) + 1))
        let samples = (0..<count).map { index -> PKStrokePoint in
            let fraction = CGFloat(index) / CGFloat(count - 1)
            return PKStrokePoint(location: CGPoint(x: start.x + (end.x - start.x) * fraction, y: start.y + (end.y - start.y) * fraction),
                timeOffset: Double(fraction) * 0.2, size: CGSize(width: width, height: width), opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
        }
        return PKStroke(ink: ink, path: PKStrokePath(controlPoints: samples, creationDate: creationDate))
    }

    private static func remapping(_ path: PKStrokePath, _ transform: (PKStrokePoint) -> PKStrokePoint) -> PKStrokePath {
        PKStrokePath(controlPoints: path.map(transform), creationDate: path.creationDate)
    }
    private static func copy(_ point: PKStrokePoint, location: CGPoint? = nil, size: CGSize? = nil) -> PKStrokePoint {
        PKStrokePoint(location: location ?? point.location, timeOffset: point.timeOffset, size: size ?? point.size,
            opacity: point.opacity, force: point.force, azimuth: point.azimuth, altitude: point.altitude)
    }
    private static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }
    private static func segmentDistance(_ point: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = b.x - a.x, dy = b.y - a.y, length = dx * dx + dy * dy
        guard length > 0 else { return distance(point, a) }
        let t = min(1, max(0, ((point.x - a.x) * dx + (point.y - a.y) * dy) / length))
        return distance(point, CGPoint(x: a.x + dx * t, y: a.y + dy * t))
    }
}
