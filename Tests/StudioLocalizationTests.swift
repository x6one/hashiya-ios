import XCTest
import SwiftUI
@testable import Hashiya

final class StudioLocalizationTests: XCTestCase {
    func testLanguagePersistsInItsOwnPreferenceWithoutChangingSectionIdentity() throws {
        let suite = "TayyaLocalizationTest-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let localization = TayyaLocalization(defaults: defaults)
        XCTAssertEqual(localization.language, .ar)
        localization.language = .en
        XCTAssertEqual(localization.text("الملاحظات"), "Notes")
        XCTAssertEqual(localization.text("مكتبتي"), "My Library")
        let reopened = TayyaLocalization(defaults: defaults)
        XCTAssertEqual(reopened.language, .en)
        XCTAssertEqual(reopened.direction, .leftToRight)
        var note = Notebook(title: "ملاحظاتي القديمة", file: "unchanged.pdf")
        note.section = "مكتبتي"
        let bytes = try JSONEncoder().encode(note)
        localization.language = .ar
        XCTAssertEqual(localization.text("الملاحظات"), "الملاحظات")
        let stored = try JSONDecoder().decode(Notebook.self, from: bytes)
        XCTAssertEqual(stored.section, "مكتبتي")
        XCTAssertEqual(stored.title, "ملاحظاتي القديمة")
        XCTAssertEqual(stored.file, "unchanged.pdf")
    }
}
