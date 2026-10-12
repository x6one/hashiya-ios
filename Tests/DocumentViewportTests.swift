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
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        window.rootViewController = controller; window.makeKeyAndVisible()
        defer { window.isHidden = true }
        let view = ResizingPDFView(frame: CGRect(x: 0, y: 0, width: 393, height: 600))
        controller.view.addSubview(view)
        view.document = document; view.displayMode = .singlePageContinuous; view.autoScales = true
        view.layoutIfNeeded()
        let target = try XCTUnwrap(document.page(at: 3))
        view.go(to: PDFDestination(page: target, at: CGPoint(x: 0, y: 500)))
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        let initial = try XCTUnwrap(view.currentDestination)
        for index in 0..<12 {
            view.frame.size.height = index.isMultiple(of: 2) ? 552 : 600
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
