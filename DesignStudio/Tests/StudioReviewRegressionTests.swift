import PDFKit
import SwiftUI
import XCTest
@testable import TayyaStudio

final class StudioReviewRegressionTests: XCTestCase {
    @MainActor func testNotesFormattingNeverMutatesOtherPDFPagesOrSavedAnnotations() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let draft = StudioDraft(url: folder.appendingPathComponent("preview.json"))
        let session = StudioSession()
        let navigation = StudioNavigation()
        navigation.scene = .document
        let pdf = StudioPDFController()
        let workspace = StudioWorkspace(session: session, navigation: navigation, documentInk: StudioCanvas(), marginInk: StudioCanvas(margin: true), pdf: pdf, draft: draft)
        let (window, previous) = try studioTestWindow(UIHostingController(rootView: workspace))
        defer { window.isHidden = true; previous?.makeKeyAndVisible() }
        waitUntil { pdf.view.window != nil }
        pdf.updateText("PAGE-7", size: 18, color: 0x244C43, alignment: 0, page: 7)
        pdf.updateText("PAGE-8", size: 18, color: 0x244C43, alignment: 0, page: 8)
        draft.state.text = "PAGE-8"
        draft.state.pdf = pdf.view.document?.dataRepresentation()
        let originalSize = try XCTUnwrap(pdf.view.document?.page(at: 7)?.annotations.first?.font?.pointSize)
        session.changePage(to: 9)
        navigation.scene = .margin
        draft.state.textSize = 32
        draft.state.textAlignment = 1
        waitUntil { draft.status == "saved" }
        XCTAssertEqual(pdf.view.document?.page(at: 6)?.annotations.first?.contents, "PAGE-7")
        XCTAssertEqual(pdf.view.document?.page(at: 7)?.annotations.first?.contents, "PAGE-8")
        XCTAssertEqual(pdf.view.document?.page(at: 7)?.annotations.first?.font?.pointSize, originalSize)
        XCTAssertTrue(try XCTUnwrap(pdf.view.document?.page(at: 8)).annotations.isEmpty, "Notes formatting must never copy the previous PDF text onto a new page")
        let restored = StudioDraft(url: folder.appendingPathComponent("preview.json"))
        let savedPDF = PDFDocument(data: try XCTUnwrap(restored.state.pdf))
        XCTAssertEqual(savedPDF?.page(at: 6)?.annotations.first?.contents, "PAGE-7")
        XCTAssertEqual(savedPDF?.page(at: 7)?.annotations.first?.contents, "PAGE-8")
        XCTAssertTrue(try XCTUnwrap(savedPDF?.page(at: 8)).annotations.isEmpty)
    }

    @MainActor func testNotesFormattingRemainsVisibleOutsideTextMode() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let draft = StudioDraft(url: folder.appendingPathComponent("preview.json"))
        draft.state.textSize = 32
        let session = StudioSession(), navigation = StudioNavigation(), pdf = StudioPDFController()
        navigation.scene = .margin
        let host = UIHostingController(rootView: StudioWorkspace(session: session, navigation: navigation, documentInk: StudioCanvas(), marginInk: StudioCanvas(margin: true), pdf: pdf, draft: draft))
        let (window, previous) = try studioTestWindow(host)
        defer { window.isHidden = true; previous?.makeKeyAndVisible() }
        func editor(in view: UIView) -> UITextView? {
            if let text = view as? UITextView, text.text == draft.state.notes { return text }
            return view.subviews.lazy.compactMap { editor(in: $0) }.first
        }
        waitUntil { editor(in: window) != nil }
        let text = try XCTUnwrap(editor(in: window))
        let size = text.font?.pointSize ?? (text.typingAttributes[.font] as? UIFont)?.pointSize
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(size), 30, "Saved Notes formatting must stay visible while Pen is selected")
        waitUntil { draft.status == "saved" }
    }

    @MainActor private func waitUntil(_ condition: @escaping () -> Bool) {
        let done = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condition() }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [done], timeout: 5), .completed)
    }
}
