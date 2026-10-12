import XCTest
import PDFKit
@testable import Hashiya

final class DocumentViewportTests: XCTestCase {
    @MainActor func testRepeatedToolbarResizesKeepTheReadingLocationOnLandscapePages() throws {
        let paper = CGRect(x: 0, y: 0, width: 960, height: 540)
        let data = UIGraphicsPDFRenderer(bounds: paper).pdfData { context in
            for index in 1...12 {
                context.beginPage()
                ("Slide \(index)" as NSString).draw(at: CGPoint(x: 40, y: 40),
                    withAttributes: [.font: UIFont.systemFont(ofSize: 30)])
            }
        }
        let document = try XCTUnwrap(PDFDocument(data: data))
        let controller = UIViewController()
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousWindow = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        window.rootViewController = controller; window.makeKeyAndVisible()
        defer { window.isHidden = true; previousWindow?.makeKeyAndVisible() }
        let view = ResizingPDFView(frame: CGRect(x: 0, y: 0, width: 393, height: 600))
        controller.view.addSubview(view)
        view.document = document; view.displayMode = .singlePageContinuous; view.autoScales = true
        view.layoutIfNeeded()
        let target = try XCTUnwrap(document.page(at: 3))
        view.go(to: PDFDestination(page: target, at: CGPoint(x: 0, y: 500)))
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        let initial = try XCTUnwrap(view.currentDestination)
        func trace(_ stage: String) {
            let destination = view.currentDestination
            let point = CGPoint(x: view.bounds.midX, y: view.bounds.minY + 1)
            let topPage = view.page(for: point, nearest: true)
            var ancestor = view.documentView?.superview
            while let current = ancestor, !(current is UIScrollView), current !== view { ancestor = current.superview }
            let offset = (ancestor as? UIScrollView)?.contentOffset
            print("Viewport trace \(stage): destinationPage=\(destination?.page.map { document.index(for: $0) } ?? -1) destination=\(String(describing: destination?.point)) topPage=\(topPage.map { document.index(for: $0) } ?? -1) top=\(topPage.map { view.convert(point, to: $0) } ?? .zero) offset=\(String(describing: offset)) scale=\(view.scaleFactor) bounds=\(view.bounds)")
        }
        trace("initial")
        for index in 0..<12 {
            trace("before-frame-\(index)")
            view.frame.size.height = index.isMultiple(of: 2) ? 552 : 600
            trace("after-frame-\(index)")
            view.setNeedsLayout(); view.layoutIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
            let current = try XCTUnwrap(view.currentDestination)
            print("PDF toolbar resize \(index): page=\(current.page.map { document.index(for: $0) } ?? -1) point=\(current.point) scale=\(view.scaleFactor) fit=\(view.scaleFactorForSizeToFit)")
            XCTAssertTrue(current.page === initial.page, "Showing the pen toolbar must not turn a slide, resize \(index)")
            XCTAssertEqual(current.point.y, initial.point.y, accuracy: 3,
                "Keep the reading offset rather than snapping to a page, resize \(index)")
            XCTAssertEqual(view.scaleFactor, view.scaleFactorForSizeToFit, accuracy: 0.01,
                "Restoring a reading location must retain the resized fit scale")
        }
    }
}
