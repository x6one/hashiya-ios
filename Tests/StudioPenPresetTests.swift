import XCTest
import SwiftUI
@testable import Hashiya

final class StudioPenPresetTests: XCTestCase {
    @MainActor func testThreeNativePresetsRetainBrushRGBAAndWidthAcrossFreshStore() throws {
        let suite = "TayyaPresetTest-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = PenPresetStore(defaults: defaults)
        XCTAssertEqual(store.presets.count, 3)
        XCTAssertTrue(store.save(slot: 1, brush: .pencil, color: Color(red: 0.8, green: 0.2, blue: 0.6), width: 5))
        let reopened = PenPresetStore(defaults: defaults)
        XCTAssertEqual(reopened.presets.count, 3)
        let preset = reopened.presets[1]
        XCTAssertEqual(preset.brush, .pencil); XCTAssertEqual(preset.width, 5)
        XCTAssertEqual(preset.red, 0.8, accuracy: 0.001); XCTAssertEqual(preset.green, 0.2, accuracy: 0.001)
        XCTAssertEqual(preset.blue, 0.6, accuracy: 0.001)
        XCTAssertEqual(reopened.presets[0].brush, store.presets[0].brush, "Saving one slot leaves other saved tools intact")
        XCTAssertFalse(store.save(slot: 1, brush: .eraser, color: .black, width: 3))
        XCTAssertFalse(store.save(slot: 4, brush: .pen, color: .black, width: 3))
        XCTAssertFalse(store.save(slot: 1, brush: .pen, color: .black, width: .nan))
        XCTAssertEqual(PenPresetStore(defaults: defaults).presets[1].brush, .pencil)
    }
    @MainActor func testDamagedExistingPreferenceIsNeverOverwrittenWithDefaults() throws {
        let suite = "TayyaPresetTest-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let broken = Data("[interrupted".utf8)
        defaults.set(broken, forKey: PenPresetStore.key)
        let store = PenPresetStore(defaults: defaults)
        XCTAssertNotNil(store.error)
        XCTAssertEqual(store.presets.count, 3, "Usable defaults must not require destructive preference repair")
        XCTAssertFalse(store.save(slot: 0, brush: .pencil, color: .red, width: 2))
        XCTAssertEqual(defaults.data(forKey: PenPresetStore.key), broken)
    }
}
