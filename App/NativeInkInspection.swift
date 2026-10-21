#if DEBUG
import UIKit
import PencilKit
import CryptoKit

// Failure evidence only. Reads synthetic review roots and never saves through
// LibraryStore/MarginPages. Generated rasters are not simulator screenshots.
@MainActor enum NativeInkInspection {
    static func runIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("--test-inspect-review-ink") else { return }
        let temporary = FileManager.default.temporaryDirectory
        do {
            let roots = try FileManager.default.contentsOfDirectory(at: temporary, includingPropertiesForKeys: nil)
                .filter { $0.lastPathComponent.hasPrefix("ReviewEntry-")
                    && UUID(uuidString: String($0.lastPathComponent.dropFirst("ReviewEntry-".count))) != nil }
            _ = try export(roots: roots, to: temporary.appendingPathComponent("TayyaInkInspection"))
        } catch { print("NativeInkInspection failed: \(error)") }
    }

    @discardableResult static func export(roots: [URL], to destination: URL) throws -> [String: Any] {
        let files = FileManager.default
        try files.createDirectory(at: destination, withIntermediateDirectories: true)
        var rows: [[String: Any]] = []
        var errors: [String] = []
        for root in roots.sorted(by: { $0.path < $1.path }) {
            guard let iterator = files.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey]) else { continue }
            for case let source as URL in iterator {
                let marginPage = source.pathExtension == "json"
                    && source.deletingLastPathComponent().lastPathComponent.hasSuffix("-margins")
                    && source.lastPathComponent != "index.json"
                guard marginPage || source.pathExtension == "drawing" else { continue }
                let relative = root.lastPathComponent + "/" + String(source.path.dropFirst(root.path.count + 1))
                do {
                    let bytes = try Data(contentsOf: source)
                    let ink = marginPage ? try JSONDecoder().decode(MarginPage.self, from: bytes).ink : bytes
                    let drawing = ink.isEmpty ? PKDrawing() : try PKDrawing(data: ink)
                    let prefix = String(format: "%03d", rows.count)
                    try ink.write(to: destination.appendingPathComponent(prefix + ".drawing"), options: .atomic)
                    var row: [String: Any] = ["path": relative, "source_sha256": hash(bytes),
                        "drawing_sha256": hash(ink), "stroke_count": drawing.strokes.count]
                    row["strokes"] = drawing.strokes.map { stroke -> [String: Any] in
                        let path = stroke.path
                        var points: [[String: Any]] = []
                        for index in 0..<path.count {
                            let point = path[index]
                            points.append(["x": point.location.x, "y": point.location.y,
                                "width": point.size.width, "height": point.size.height,
                                "opacity": point.opacity, "force": point.force])
                        }
                        return ["type": stroke.ink.inkType.rawValue,
                            "color": String(describing: stroke.ink.color),
                            "bounds": String(describing: stroke.renderBounds),
                            "transform": String(describing: stroke.transform), "points": points]
                    }
                    let image = raster(drawing)
                    let png = try pngData(image)
                    try png.write(to: destination.appendingPathComponent(prefix + ".png"), options: .atomic)
                    row["raster"] = prefix + ".png"; row["raster_sha256"] = hash(png)
                    row["red_pixels"] = redPixels(image)
                    if let last = drawing.strokes.last {
                        let lastImage = raster(PKDrawing(strokes: [last]))
                        try pngData(lastImage).write(to: destination.appendingPathComponent(prefix + "-last.png"), options: .atomic)
                        row["last_stroke_red_pixels"] = redPixels(lastImage)
                    }
                    rows.append(row)
                } catch { errors.append(relative + ": " + error.localizedDescription) }
            }
        }
        let report: [String: Any] = ["kind": "native PKDrawing raster, not a simulator screenshot",
            "roots": roots.map(\.lastPathComponent), "drawings": rows, "errors": errors]
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
            .write(to: destination.appendingPathComponent("report.json"), options: .atomic)
        return report
    }

    private static func hash(_ bytes: Data) -> String {
        SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    }
    private static func pngData(_ image: UIImage) throws -> Data {
        guard let png = image.pngData() else { throw CocoaError(.fileWriteUnknown) }
        return png
    }
    private static func raster(_ drawing: PKDrawing) -> UIImage {
        let bounds = CGRect(x: 0, y: 0, width: 650, height: 900).union(drawing.bounds.isEmpty ? .zero : drawing.bounds)
        let format = UIGraphicsImageRendererFormat()
        format.scale = min(2, 2048 / max(bounds.width, bounds.height)); format.opaque = true
        return UIGraphicsImageRenderer(size: bounds.size, format: format).image { context in
            PaperColor.cream.uiColor.setFill(); context.cgContext.fill(CGRect(origin: .zero, size: bounds.size))
            drawing.image(from: bounds, scale: format.scale).draw(in: CGRect(origin: .zero, size: bounds.size))
        }
    }
    private static func redPixels(_ image: UIImage) -> Int {
        guard let image = image.cgImage else { return 0 }
        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        return bytes.withUnsafeMutableBytes { pixels in
            guard let context = CGContext(data: pixels.baseAddress, width: image.width, height: image.height,
                bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else { return 0 }
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            var count = 0
            for index in stride(from: 0, to: pixels.count, by: 4) {
                let red = Int(pixels[index]), green = Int(pixels[index + 1]), blue = Int(pixels[index + 2])
                if red > green + 25 && red > blue + 25 && red > 80 { count += 1 }
            }
            return count
        }
    }
}
#endif
