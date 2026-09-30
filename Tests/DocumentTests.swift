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

final class LibraryMutationTests: XCTestCase {
    @MainActor func testNewDocumentsUseSelectedSection() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = LibraryStore(root: root, seedDemo: false)
        store.addSection("الجامعة")
        store.create("محاضرة", section: "الجامعة")
        let source = try XCTUnwrap(Bundle(for: LibraryStore.self).url(forResource: "english", withExtension: "pdf"))
        try store.importDocument(source, section: "الجامعة")
        let restored = LibraryStore(root: root, seedDemo: false)
        XCTAssertEqual(restored.notebooks.count, 2)
        XCTAssertTrue(restored.notebooks.allSatisfy { $0.section == "الجامعة" })
    }

    @MainActor func testSectionsMoveAndPermanentDeletion() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = LibraryStore(root: root, seedDemo: false)
        let source = try XCTUnwrap(Bundle(for: LibraryStore.self).url(forResource: "english", withExtension: "pdf"))
        try store.importDocument(source)
        let note = try XCTUnwrap(store.notebooks.first)
        store.addSection("الجامعة")
        store.change(note.id) { $0.section = "الجامعة" }
        store.deleteSection("الجامعة")
        XCTAssertEqual(store.notebooks.first?.section, "مكتبتي")
        XCTAssertFalse(LibraryStore(root: root, seedDemo: false).sections.contains("الجامعة"))
        store.permanentlyDelete(note)
        XCTAssertEqual(store.notebooks.count, 1, "Live documents cannot be permanently deleted")
        let audio = root.appendingPathComponent(note.id.uuidString + "-audio")
        try FileManager.default.createDirectory(at: audio, withIntermediateDirectories: true)
        try Data([1, 2, 3]).write(to: audio.appendingPathComponent("test.m4a"))
        store.change(note.id) { $0.trashed = true }
        store.permanentlyDelete(try XCTUnwrap(store.notebooks.first))
        XCTAssertTrue(store.notebooks.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent(note.file).path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: audio.path))
        XCTAssertTrue(LibraryStore(root: root, seedDemo: false).notebooks.isEmpty)
    }
    @MainActor func testTextEditsPersistAndExport() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = LibraryStore(root: root, seedDemo: false)
        try store.importDocument(try XCTUnwrap(Bundle(for: LibraryStore.self).url(forResource: "english", withExtension: "pdf")))
        let note = try XCTUnwrap(store.notebooks.first)
        print("TextExport: prepare workspace")
        let editor = PDFWorkspace(note: note, root: root)
        var text = PageText(page: 0, text: "حاشية عربية", x: 50, y: 50)
        print("TextExport: save text")
        editor.saveText(text); text.text = "Edited note"; editor.saveText(text)
        print("TextExport: reopen")
        let reopened = PDFWorkspace(note: note, root: root)
        XCTAssertEqual(reopened.texts.count, 1)
        XCTAssertEqual(reopened.texts.first?.text, "Edited note")
        print("TextExport: render PDF")
        reopened.export()
        print("TextExport: inspect output")
        let output = try XCTUnwrap(reopened.exported)
        defer { try? FileManager.default.removeItem(at: output) }
        XCTAssertEqual(PDFDocument(url: output)?.pageCount, reopened.document.pageCount)
        XCTAssertNil(reopened.error)
        text.text = ""; reopened.saveText(text)
        XCTAssertTrue(PDFWorkspace(note: note, root: root).texts.isEmpty)
    }
}
