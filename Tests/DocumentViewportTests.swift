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
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let library = LibraryStore(root: root, seedDemo: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("slides.pdf"); try data.write(to: source)
        try library.importPDF(source, title: "Landscape slides")
        let workspace = PDFWorkspace(note: try XCTUnwrap(library.notebooks.first), root: root)
        let document = workspace.document
        let controller = UIViewController()
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousWindow = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        window.rootViewController = controller; window.makeKeyAndVisible()
        XCTAssertTrue(window.isKeyWindow, "Exercise PDFKit in the active iOS window")
        defer { window.isHidden = true; previousWindow?.makeKeyAndVisible() }
        let view = ResizingPDFView(frame: CGRect(x: 0, y: 0, width: 393, height: 600))
        workspace.view = view
        let coordinator = NativePDF.Coordinator(workspace: workspace)
        controller.view.addSubview(view)
        view.document = document; view.displayMode = .singlePageContinuous; view.autoScales = true
        view.layoutIfNeeded()
        let target = try XCTUnwrap(document.page(at: 3))
        view.go(to: PDFDestination(page: target, at: CGPoint(x: 0, y: 500)))
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        let probe = CGPoint(x: view.bounds.midX, y: view.bounds.minY + 1)
        XCTAssertTrue(view.page(for: probe, nearest: true) === target)
        let initialPoint = view.convert(probe, to: target)
        coordinator.pageChanged()
        XCTAssertEqual(workspace.page, 4, "The counter must identify the visible reading page, not a later slide")
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
        let toolbarSizes = (0..<12).map { CGSize(width: 393, height: $0.isMultiple(of: 2) ? 552 : 600) }
        let splitSizes = [CGSize(width: 260, height: 600), CGSize(width: 393, height: 300),
                          CGSize(width: 850, height: 320), CGSize(width: 393, height: 600)]
        for (index, size) in (toolbarSizes + splitSizes).enumerated() {
            trace("before-frame-\(index)")
            view.frame.size = size
            trace("after-frame-\(index)")
            view.setNeedsLayout(); view.layoutIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
            let probe = CGPoint(x: view.bounds.midX, y: view.bounds.minY + 1)
            let currentPage = try XCTUnwrap(view.page(for: probe, nearest: true))
            let currentPoint = view.convert(probe, to: currentPage)
            print("PDF toolbar resize \(index): visiblePage=\(document.index(for: currentPage)) point=\(currentPoint) scale=\(view.scaleFactor) fit=\(view.scaleFactorForSizeToFit)")
            XCTAssertTrue(currentPage === target, "Showing the pen toolbar must not turn a visible slide, resize \(index)")
            XCTAssertEqual(currentPoint.y, initialPoint.y, accuracy: 3,
                "Keep the reading offset rather than snapping to a page, resize \(index)")
            XCTAssertEqual(view.scaleFactor, view.scaleFactorForSizeToFit, accuracy: 0.01,
                "Restoring a reading location must retain the resized fit scale")
            coordinator.pageChanged()
            XCTAssertEqual(workspace.page, 4, "Counter and ink must stay on the reading page after resizing")
        }
        workspace.jump(7); view.layoutIfNeeded(); coordinator.pageChanged()
        XCTAssertEqual(workspace.page, 7, "Explicit page navigation must still work")
        view.autoScales = false; view.scaleFactor = 0.8
        view.layoutIfNeeded()
        let zoomPage = try XCTUnwrap(view.page(for: CGPoint(x: view.bounds.midX, y: 1), nearest: true))
        let zoomPoint = view.convert(CGPoint(x: view.bounds.midX, y: 1), to: zoomPage)
        view.frame.size.height = 480; view.layoutIfNeeded()
        XCTAssertEqual(view.scaleFactor, 0.8, accuracy: 0.01, "Toolbars must retain manual zoom")
        XCTAssertTrue(view.page(for: CGPoint(x: view.bounds.midX, y: 1), nearest: true) === zoomPage)
        XCTAssertEqual(view.convert(CGPoint(x: view.bounds.midX, y: 1), to: zoomPage).y, zoomPoint.y, accuracy: 3)
    }
}
