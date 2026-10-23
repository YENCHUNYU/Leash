import SwiftUI

nonisolated enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case chinese = "zh-Hant"

    /// AppStorage key. Only ContentView and the language picker read it; other views use `\.appLanguage`.
    static let storageKey = "leash.language"
    static var initial: String {
        Locale.preferredLanguages.first?.hasPrefix("zh") == true ? chinese.rawValue : english.rawValue
    }

    var id: String { rawValue }
    var title: String { self == .english ? "English" : "繁體中文" }
    var locale: Locale { Locale(identifier: rawValue) }
    func text(_ english: String, _ chinese: String) -> String { self == .english ? english : chinese }
}

extension EnvironmentValues {
    @Entry var appLanguage: AppLanguage = .english
}
