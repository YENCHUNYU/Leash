import SwiftUI

struct SettingsView: View {
    @AppStorage(AppLanguage.storageKey) private var languageCode = AppLanguage.initial
    @Environment(\.appLanguage) private var language

    var body: some View {
        Form {
            Section(language.text("Language", "語言")) {
                Picker(language.text("App language", "App 語言"), selection: $languageCode) {
                    ForEach(AppLanguage.allCases) { option in
                        Text(option.title).tag(option.rawValue)
                    }
                }.pickerStyle(.inline)
            }
            Section {
                Text(language.text("Your language preference is saved on this device and applies immediately.", "語言偏好會儲存在此裝置，切換後立即套用。"))
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
}
