import SwiftUI

enum TayyaAppLanguage: String, CaseIterable, Identifiable {
    case ar, en
    var id: String { rawValue }
    var title: String { self == .ar ? "العربية" : "English" }
}

/// Display language never changes persisted section names, identifiers or content.
final class TayyaLocalization: ObservableObject {
    static let shared = TayyaLocalization()
    @Published var language: TayyaAppLanguage {
        didSet { defaults.set(language.rawValue, forKey: "tayya.language") }
    }
    private let defaults: UserDefaults
    var locale: Locale { Locale(identifier: language.rawValue) }
    var direction: LayoutDirection { language == .ar ? .rightToLeft : .leftToRight }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--test-english") { language = .en; return }
        #endif
        language = defaults.string(forKey: "tayya.language").flatMap(TayyaAppLanguage.init(rawValue:)) ?? .ar
    }

    func text(_ key: String) -> String {
        guard let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else { return key }
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }
}

func TayyaLocalized(_ key: String) -> String { TayyaLocalization.shared.text(key) }
