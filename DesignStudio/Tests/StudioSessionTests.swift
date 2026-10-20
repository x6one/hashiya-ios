import XCTest
@testable import TayyaStudio

final class StudioSessionTests: XCTestCase {
    func testPageSwitchContinuesRecordingAndAddsPageMarker() {
        let session = StudioSession()
        session.beginRecording()
        session.tick(seconds: 12)
        session.changePage(to: 8)
        XCTAssertTrue(session.recording)
        XCTAssertEqual(session.page, 8)
        XCTAssertEqual(session.markers.map(\.page), [7, 8])
        XCTAssertEqual(session.markers.last?.time, 12)
        session.changePage(to: 8)
        XCTAssertEqual(session.markers.count, 2, "Repeated page notifications must not duplicate a mark")
    }

    func testWritingAndManualMarksUseCurrentPageAndTime() {
        let session = StudioSession()
        session.beginRecording()
        session.tick(seconds: 5)
        session.markWriting("نقطة مهمة")
        session.addManualMarker()
        XCTAssertEqual(session.markers.map(\.kind), ["page", "writing", "manual"])
        XCTAssertEqual(session.markers.last?.page, 7)
        XCTAssertEqual(session.markers.last?.time, 5)
    }

    func testMarkerActivationChangesPageAndSeeksToItsTime() {
        let session = StudioSession()
        session.activate(StudioMarker(page: 9, time: 335, label: "شرح", kind: "manual"))
        XCTAssertEqual(session.page, 9)
        XCTAssertEqual(session.playhead, 335)
        XCTAssertTrue(session.playing)
    }

    func testSeekAndPageClampToPlayableDocumentRange() {
        let session = StudioSession()
        session.seek(to: -10)
        XCTAssertEqual(session.playhead, 0)
        session.seek(to: 9999)
        XCTAssertEqual(session.playhead, 760)
        session.changePage(to: -1)
        XCTAssertEqual(session.page, 1)
        session.changePage(to: 999)
        XCTAssertEqual(session.page, 24)
    }

    func testRenamePreservesClipReferenceAndRejectsEmptyTitle() {
        let session = StudioSession()
        let original = session.clipReference
        session.rename(to: "  مراجعة الفصل  ")
        XCTAssertEqual(session.title, "مراجعة الفصل")
        session.rename(to: " \n ")
        XCTAssertEqual(session.title, "مراجعة الفصل")
        XCTAssertEqual(session.clipReference, original)
    }

    func testPlaybackRateBounds() {
        let session = StudioSession()
        session.setRate(1.5)
        XCTAssertEqual(session.rate, 1.5)
        session.setRate(3)
        XCTAssertEqual(session.rate, 2)
        session.setRate(0)
        XCTAssertEqual(session.rate, 0.75)
    }

    func testInterruptionStopsRecordingWithoutOpeningMarginOrAddingIdleMarks() {
        let session = StudioSession()
        session.beginRecording()
        XCTAssertTrue(session.recording)
        XCTAssertFalse(session.marginOpen)
        session.tick(seconds: 8)
        session.sceneBecameInactive()
        let count = session.markers.count
        session.markWriting("idle")
        session.tick(seconds: 2)
        XCTAssertFalse(session.recording)
        XCTAssertEqual(session.elapsed, 8)
        XCTAssertEqual(session.markers.count, count)
        XCTAssertFalse(session.marginOpen)
    }
}
