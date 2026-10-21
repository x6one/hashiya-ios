import XCTest
import SwiftUI
import PDFKit
@testable import Hashiya

private struct NativeVisibilityProbe: View {
    let workspace: PDFWorkspace
    let presented: Bool
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                NativePDF(workspace: workspace, presented: presented)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    .opacity(presented ? 1 : 0).allowsHitTesting(presented).accessibilityHidden(!presented)
                Color.white.opacity(presented ? 0 : 1).allowsHitTesting(!presented).accessibilityHidden(presented)
            }
        }
    }
}

final class StudioNativeVisibilityTests: XCTestCase {
    @MainActor func testRetainedPDFHonorsNativeVisibilityAcrossSwiftUIUpdates() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let library = LibraryStore(root: root, seedDemo: false)
        let workspace = PDFWorkspace(note: try library.installDemonstration(), root: root)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previous = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 440, height: 956)
        let host = UIHostingController(rootView: NativeVisibilityProbe(workspace: workspace, presented: true))
        window.rootViewController = host; window.makeKeyAndVisible(); host.view.layoutIfNeeded()
        defer { window.isHidden = true; window.rootViewController = nil; previous?.makeKeyAndVisible() }
        func settle(_ condition: @escaping () -> Bool) {
            let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condition() }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 3), .completed)
        }
        settle { workspace.view?.bounds.height ?? 0 > 100 }
        let view = try XCTUnwrap(workspace.view)
        let document = try XCTUnwrap(view.document)
        func trace(_ stage: String) {
            print("NativeVisibility stage=\(stage) hidden=\(view.isHidden) axHidden=\(view.accessibilityElementsHidden) alpha=\(view.alpha) element=\(view.isAccessibilityElement) frame=\(view.frame) owner=\(String(describing: view.superview.map { type(of: $0) }))")
        }
        trace("shown")
        XCTAssertFalse(view.isHidden)
        host.rootView = NativeVisibilityProbe(workspace: workspace, presented: false)
        host.view.setNeedsLayout(); host.view.layoutIfNeeded()
        settle { view.isHidden && view.accessibilityElementsHidden }
        trace("expanded-notes")
        XCTAssertTrue(view.isHidden, "A retained native PDF must actually hide while Notes owns the full area")
        XCTAssertTrue(view.accessibilityElementsHidden)
        XCTAssertTrue(workspace.view === view)
        XCTAssertTrue(view.document === document, "Hiding Notes must never replace the actual PDF")
        host.rootView = NativeVisibilityProbe(workspace: workspace, presented: true)
        host.view.setNeedsLayout(); host.view.layoutIfNeeded()
        settle { !view.isHidden && !view.accessibilityElementsHidden }
        trace("restored")
        XCTAssertTrue(workspace.view === view)
        XCTAssertTrue(view.document === document)
        XCTAssertEqual(workspace.page, 1)
    }
}
