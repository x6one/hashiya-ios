// Read saved PKDrawing bytes with Apple's public macOS PencilKit renderer.
// This is offline evidence analysis, never an iOS test or a release gate.
import AppKit
import PencilKit
import CryptoKit

enum EvidenceError: Error { case invalid(String) }

func rgba(_ color: NSColor) -> [Double] {
    guard let rgb = color.usingColorSpace(.sRGB) else { return [] }
    return [Double(rgb.redComponent), Double(rgb.greenComponent), Double(rgb.blueComponent), Double(rgb.alphaComponent)]
}

func render(_ drawing: PKDrawing, rect: CGRect, scale: CGFloat, to url: URL) throws -> [String: Any] {
    let image = drawing.image(from: rect, scale: scale)
    var proposed = CGRect(origin: .zero, size: image.size)
    guard let cg = image.cgImage(forProposedRect: &proposed, context: nil, hints: nil) else {
        throw EvidenceError.invalid("PencilKit produced no image")
    }
    guard cg.width > 0, cg.height > 0, cg.width * cg.height <= 6_000_000 else {
        throw EvidenceError.invalid("Unexpected raster dimensions")
    }
    var pixels = [UInt8](repeating: 0, count: cg.width * cg.height * 4)
    return try pixels.withUnsafeMutableBytes { buffer in
        guard let context = CGContext(data: buffer.baseAddress, width: cg.width, height: cg.height,
            bitsPerComponent: 8, bytesPerRow: cg.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else {
            throw EvidenceError.invalid("Raster context unavailable")
        }
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
        context.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
        var red = 0
        for index in stride(from: 0, to: buffer.count, by: 4) {
            let r = Int(buffer[index]), g = Int(buffer[index + 1]), b = Int(buffer[index + 2])
            if r > g + 25 && r > b + 25 && r > 80 { red += 1 }
        }
        guard let composite = context.makeImage(),
              let png = NSBitmapImageRep(cgImage: composite).representation(using: .png, properties: [:]) else {
            throw EvidenceError.invalid("PNG encoding failed")
        }
        try png.write(to: url, options: .atomic)
        return ["png": url.lastPathComponent, "width": cg.width, "height": cg.height,
            "red_dominant_pixels": red, "drawing_rect": String(describing: rect),
            "scale": Double(scale), "background": "opaque white"]
    }
}

func strokeReport(_ stroke: PKStroke) -> [String: Any] {
    let path = stroke.path
    let indexes = Array(Set([0, path.count / 2, max(0, path.count - 1)])).sorted().filter { $0 < path.count }
    let points = indexes.map { index -> [String: Any] in
        let point = path[index]
        return ["index": index, "location": [Double(point.location.x), Double(point.location.y)],
            "size": [Double(point.size.width), Double(point.size.height)],
            "opacity": Double(point.opacity), "force": Double(point.force)]
    }
    return ["ink_type": stroke.ink.inkType.rawValue, "rgba": rgba(stroke.ink.color),
        "render_bounds": String(describing: stroke.renderBounds), "point_count": path.count,
        "sampled_points": points, "transform": String(describing: stroke.transform)]
}

func main() throws {
    let args = Array(CommandLine.arguments.dropFirst())
    guard args.count == 2 else { throw EvidenceError.invalid("Usage: renderer <saved-drawings|--self-check> <output>") }
    let output = URL(fileURLWithPath: args[1], isDirectory: true)
    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
    if args[0] == "--self-check" {
        let points = (0..<3).map { index in
            PKStrokePoint(location: CGPoint(x: CGFloat(12 + index * 20), y: CGFloat(12 + index * 20)),
                timeOffset: Double(index) * 0.1, size: CGSize(width: 8, height: 8),
                opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
        }
        let stroke = PKStroke(ink: PKInk(.pen, color: .red),
            path: PKStrokePath(controlPoints: points, creationDate: Date()))
        let rectangle = CGRect(x: 0, y: 0, width: 80, height: 80)
        let blank = try render(PKDrawing(), rect: rectangle, scale: 1.7, to: output.appendingPathComponent("blank.png"))
        let red = try render(PKDrawing(strokes: [stroke]), rect: rectangle, scale: 1.7, to: output.appendingPathComponent("red.png"))
        guard blank["red_dominant_pixels"] as? Int == 0, (red["red_dominant_pixels"] as? Int ?? 0) > 40 else {
            throw EvidenceError.invalid("Raster reader failed known blank/red controls")
        }
        print("RESCUE_RASTER_SELF_CHECK=passed")
        return
    }
    let input = URL(fileURLWithPath: args[0], isDirectory: true)
    let object = try JSONSerialization.jsonObject(with: Data(contentsOf: input.appendingPathComponent("manifest.json")))
    guard let manifest = object as? [String: Any], let files = manifest["drawings"] as? [[String: Any]], !files.isEmpty else {
        throw EvidenceError.invalid("No captured drawing manifest")
    }
    var reports: [[String: Any]] = []
    for file in files {
        let report: [String: Any] = try autoreleasepool {
            guard let name = file["drawing"] as? String, name == URL(fileURLWithPath: name).lastPathComponent else {
                throw EvidenceError.invalid("Drawing must be a direct file")
            }
            let bytes = try Data(contentsOf: input.appendingPathComponent(name))
            let digest = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
            guard digest == file["drawing_sha256"] as? String else { throw EvidenceError.invalid("Drawing SHA256 mismatch") }
            let drawing = try PKDrawing(data: bytes)
            let prefix = name.replacingOccurrences(of: ".drawing", with: "")
            let zoom: CGFloat = 367.3333333333333 / 650
            let crops: [(String, CGRect, CGFloat)] = [
                ("sheet", CGRect(x: 0, y: 0, width: 650, height: 900), 1),
                ("top160", CGRect(x: 0, y: 0, width: 650, height: 160), zoom * 3),
                ("compact44", CGRect(x: 0, y: 0, width: 650, height: 44.333333333333314 / zoom), zoom * 3)]
            let rasters = try crops.map { label, rectangle, scale in
                try render(drawing, rect: rectangle, scale: scale, to: output.appendingPathComponent(prefix + "-" + label + ".png"))
            }
            return ["source": file, "verified_sha256": digest, "stroke_count": drawing.strokes.count,
                "bounds": String(describing: drawing.bounds), "strokes": drawing.strokes.prefix(4).map(strokeReport),
                "rasters": rasters]
        }
        reports.append(report)
    }
    let result: [String: Any] = ["platform": "macOS PencilKit raster, not an iOS onscreen test",
        "input_source": ProcessInfo.processInfo.environment["INPUT_SOURCE_SHA"] ?? "unspecified",
        "drawings": reports]
    let data = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
    try data.write(to: output.appendingPathComponent("raster-report.json"), options: .atomic)
    print("RESCUE_RASTER_REPORT=" + String(decoding: data, as: UTF8.self))
}

do { try main() }
catch {
    FileHandle.standardError.write(Data(("Raster evidence failed: " + String(describing: error) + "\n").utf8))
    exit(1)
}
