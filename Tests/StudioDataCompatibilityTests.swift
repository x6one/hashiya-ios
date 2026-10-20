import XCTest
import AVFoundation
import PDFKit
import PencilKit
@testable import Hashiya

final class StudioDataCompatibilityTests: XCTestCase {
    @MainActor func testPreviousVersionStudyFolderSurvivesOpenSaveReloadAndBackupRestore() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let restoredRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: restoredRoot)
        }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let noteID = UUID(), trashID = UUID(), notePage = UUID(), otherPage = UUID(), deletedPage = UUID()
        let markerID = UUID(), textID = UUID(), cardID = UUID()
        // Literal previous-version keys deliberately avoid the current model's encoder.
        try writeJSON([
            ["id": noteID.uuidString, "title": "Legacy study", "file": "old.pdf", "section": "الجامعة", "favorite": true, "trashed": false],
            ["id": trashID.uuidString, "title": "Deleted study", "file": "trash.pdf", "section": "مكتبتي", "favorite": false, "trashed": true]
        ], to: root.appendingPathComponent("library.json"))
        try writeJSON(["مكتبتي", "الجامعة"], to: root.appendingPathComponent("sections.json"))
        let pdf = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792)).pdfData { context in
            for page in 1...3 {
                context.beginPage()
                ("Previous version page \(page)" as NSString).draw(at: CGPoint(x: 40, y: 40), withAttributes: [.font: UIFont.systemFont(ofSize: 24)])
            }
        }
        try pdf.write(to: root.appendingPathComponent("old.pdf"))
        try pdf.write(to: root.appendingPathComponent("trash.pdf"))
        let drawing = oldDrawing(), inkBytes = drawing.dataRepresentation()
        let inkFolder = root.appendingPathComponent(noteID.uuidString)
        try FileManager.default.createDirectory(at: inkFolder, withIntermediateDirectories: true)
        try inkBytes.write(to: inkFolder.appendingPathComponent("1.drawing"))
        try Data("Untouched pre-paged notes".utf8).write(to: root.appendingPathComponent(noteID.uuidString + "-margin.txt"))
        try inkBytes.write(to: root.appendingPathComponent(noteID.uuidString + "-margin.drawing"))
        try writeJSON([["id": textID.uuidString, "page": 1, "text": "Stored annotation", "x": 40, "y": 90, "width": 220, "height": 80, "size": 16, "font": "Arial", "red": 0.16, "green": 0.22, "blue": 0.28]], to: root.appendingPathComponent(noteID.uuidString + "-text.json"))
        try writeJSON([["id": cardID.uuidString, "question": "Old question", "answer": "Old answer", "page": 2, "known": false]], to: root.appendingPathComponent(noteID.uuidString + "-cards.json"))
        let marginsFolder = root.appendingPathComponent(noteID.uuidString + "-margins")
        try FileManager.default.createDirectory(at: marginsFolder, withIntermediateDirectories: true)
        try writeJSON(["version": 1, "pages": [notePage.uuidString, otherPage.uuidString], "current": notePage.uuidString, "deleted": [deletedPage.uuidString]], to: marginsFolder.appendingPathComponent("index.json"))
        for (identity, title, source) in [(notePage, "Independent note", 2), (otherPage, "Second note", 3), (deletedPage, "Recoverable note", 1)] {
            try writeJSON(["id": identity.uuidString, "title": title, "sourcePage": source, "text": title + " text", "ink": inkBytes.base64EncodedString(), "width": 650, "height": 900], to: marginsFolder.appendingPathComponent(identity.uuidString + ".json"))
        }
        let linked = root.appendingPathComponent(noteID.uuidString + "-audio/linked")
        let legacy = root.appendingPathComponent(noteID.uuidString + "-audio/2")
        for folder in [linked, legacy] { try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true) }
        let clip = linked.appendingPathComponent("unchanged-legacy.m4a")
        try makeM4AFixture(at: clip)
        let clipBytes = try Data(contentsOf: clip)
        try clipBytes.write(to: legacy.appendingPathComponent("page-recording.m4a"))
        try writeJSON([["id": markerID.uuidString, "clip": clip.lastPathComponent, "time": 0.25, "page": 2, "textID": textID.uuidString, "strokeCount": 1, "label": "Old marker"]], to: linked.appendingPathComponent("links.json"))
        let beforeOpen = try allFiles(root)

        let library = LibraryStore(root: root, seedDemo: false)
        XCTAssertNil(library.error)
        let note = try XCTUnwrap(library.notebooks.first { $0.id == noteID })
        XCTAssertTrue(note.favorite)
        XCTAssertEqual(note.section, "الجامعة")
        XCTAssertEqual(library.notebooks.first { $0.id == trashID }?.trashed, true)
        let workspace = PDFWorkspace(note: note, root: root)
        XCTAssertEqual(workspace.document.pageCount, 3)
        XCTAssertEqual(workspace.texts.first?.id, textID)
        XCTAssertEqual(try PKDrawing(data: Data(contentsOf: workspace.storage.appendingPathComponent("1.drawing"))).strokes.count, 1)
        let margins = MarginPages(root: root, notebook: noteID)
        XCTAssertNil(margins.error)
        XCTAssertEqual(margins.pages.map(\.id), [notePage, otherPage])
        XCTAssertEqual(margins.deletedPages.map(\.id), [deletedPage])
        let audio = PageAudio(folder: linked)
        XCTAssertNil(audio.error)
        XCTAssertEqual(audio.markers.first?.id, markerID)
        XCTAssertEqual(try AVAudioPlayer(contentsOf: clip).duration, 1, accuracy: 0.1)
        XCTAssertEqual(FlashcardStore(url: root.appendingPathComponent(noteID.uuidString + "-cards.json")).cards.first?.id, cardID)
        for (path, bytes) in beforeOpen { XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent(path)), bytes, "Opening must preserve " + path) }

        margins.editText("Saved by integrated Notes", page: notePage)
        XCTAssertTrue(margins.flush())
        XCTAssertEqual(MarginPages(root: root, notebook: noteID).current?.text, "Saved by integrated Notes")
        XCTAssertEqual(PDFWorkspace(note: note, root: root).texts.first?.text, "Stored annotation")
        XCTAssertEqual(try Data(contentsOf: clip), clipBytes)
        let backup = try await library.exportBackup()
        defer { try? FileManager.default.removeItem(at: backup) }
        let archived = try allFiles(root)
        let restored = LibraryStore(root: restoredRoot, seedDemo: false)
        let restoredCount = try await restored.restoreBackup(backup, policy: .skipExisting)
        XCTAssertEqual(restoredCount, 2)
        let restoredNote = try XCTUnwrap(restored.notebooks.first { $0.id == noteID })
        XCTAssertTrue(restoredNote.favorite)
        XCTAssertEqual(restoredNote.section, "الجامعة")
        XCTAssertEqual(restored.notebooks.first { $0.id == trashID }?.trashed, true)
        for name in note.resources {
            if name == note.file {
                XCTAssertEqual(try Data(contentsOf: restoredRoot.appendingPathComponent(restoredNote.file)), pdf)
            } else {
                for (path, bytes) in archived where path == name || path.hasPrefix(name + "/") {
                    XCTAssertEqual(try Data(contentsOf: restoredRoot.appendingPathComponent(path)), bytes, "Backup must preserve " + path)
                }
            }
        }
        let reloaded = LibraryStore(root: restoredRoot, seedDemo: false)
        XCTAssertEqual(reloaded.notebooks.map(\.id), library.notebooks.map(\.id))
        XCTAssertEqual(MarginPages(root: restoredRoot, notebook: noteID).current?.text, "Saved by integrated Notes")
        XCTAssertEqual(PageAudio(folder: restoredRoot.appendingPathComponent(noteID.uuidString + "-audio/linked")).markers.first?.id, markerID)
    }

    private func writeJSON(_ object: Any, to url: URL) throws {
        try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]).write(to: url, options: .atomic)
    }

    private func allFiles(_ root: URL) throws -> [String: Data] {
        let enumerator = try XCTUnwrap(FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey]))
        var files: [String: Data] = [:]
        for case let url as URL in enumerator where try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true {
            files[String(url.path.dropFirst(root.path.count + 1))] = try Data(contentsOf: url)
        }
        return files
    }

    private func oldDrawing() -> PKDrawing {
        let points = [CGPoint(x: 35, y: 45), CGPoint(x: 150, y: 90)].enumerated().map { index, point in
            PKStrokePoint(location: point, timeOffset: Double(index) / 4, size: CGSize(width: 5, height: 5), opacity: 1, force: 0.8, azimuth: 0, altitude: .pi / 2)
        }
        return PKDrawing(strokes: [PKStroke(ink: PKInk(.pen, color: .black), path: PKStrokePath(controlPoints: points, creationDate: Date(timeIntervalSince1970: 1_700_000_000)))])
    }

    /// Encodes a real decodable AAC/M4A fixture without claiming microphone capture.
    private func makeM4AFixture(at url: URL) throws {
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 44100))
        buffer.frameLength = 44100
        let samples = try XCTUnwrap(buffer.floatChannelData?.pointee)
        for index in 0..<44100 { samples[index] = sin(Float(index) * 2 * .pi * 440 / 44100) * 0.05 }
        let file = try AVAudioFile(forWriting: url, settings: [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 44100, AVNumberOfChannelsKey: 1])
        try file.write(from: buffer)
    }
}
