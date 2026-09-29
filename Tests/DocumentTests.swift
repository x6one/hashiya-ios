import XCTest
import PDFKit
import AVFoundation
import QuickLook
@testable import Hashiya

final class DocumentTests: XCTestCase {
    @MainActor func testBundledPDFIsReadable() throws {
        let bundle = Bundle(for: LibraryStore.self)
        let url = try XCTUnwrap(bundle.url(forResource: "english", withExtension: "pdf"))
        let document = try XCTUnwrap(PDFDocument(url: url))
        XCTAssertGreaterThan(document.pageCount, 0)
        let page = try XCTUnwrap(document.page(at: 0))
        XCTAssertGreaterThan(page.bounds(for: .mediaBox).width, 0)
    }
}

final class OfficeImportTests: XCTestCase {
    @MainActor func testImportPreservesOriginalAndSurvivesReload() throws {
        let source = try XCTUnwrap(Bundle(for: LibraryStore.self).url(forResource: "office-demo", withExtension: "pptx"))
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = LibraryStore(root: root, seedDemo: false)
        try store.importDocument(source)
        let note = try XCTUnwrap(store.notebooks.first)
        let saved = root.appendingPathComponent(note.file)
        XCTAssertEqual(try Data(contentsOf: source), try Data(contentsOf: saved))
        XCTAssertTrue(QLPreviewController.canPreview(saved as NSURL))
        XCTAssertEqual(LibraryStore(root: root, seedDemo: false).notebooks, store.notebooks)
    }
    @MainActor func testCorruptOfficeDoesNotCreateNotebook() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = LibraryStore(root: root, seedDemo: false)
        let bad = root.appendingPathComponent("broken.pptx")
        try Data("not an office archive".utf8).write(to: bad)
        XCTAssertThrowsError(try store.importDocument(bad))
        XCTAssertTrue(store.notebooks.isEmpty)
    }
    @MainActor func testEmbeddedVideoCanBePlayed() async throws {
        let source = try XCTUnwrap(Bundle(for: LibraryStore.self).url(forResource: "office-demo", withExtension: "pptx"))
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let media = try OfficeMedia.extract(from: source, into: root)
        XCTAssertEqual(media.count, 1)
        let item = try XCTUnwrap(media.first)
        let asset = AVURLAsset(url: item.url)
        let playable = try await asset.load(.isPlayable)
        let duration = try await asset.load(.duration)
        XCTAssertTrue(playable)
        XCTAssertGreaterThan(CMTimeGetSeconds(duration), 1)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        let track = try XCTUnwrap(tracks.first)
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
        reader.add(output)
        XCTAssertTrue(reader.startReading())
        XCTAssertNotNil(output.copyNextSampleBuffer(), "The extracted video must decode a real frame")
        reader.cancelReading()
    }
}
