import SwiftUI

struct SettingsView: View {
    @AppStorage(AppLanguage.storageKey) private var languageCode = AppLanguage.initial
    @AppStorage(SystemPhotos.saveKey) private var savePhotosToLibrary = true
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
                Toggle(language.text("Save walk photos to Photos", "散步照片也存到手機相簿"), isOn: $savePhotosToLibrary)
            } header: {
                Text(language.text("Photos", "照片"))
            } footer: {
                Text(language.text("Photos you take on walks are also saved to your iPhone's Photos, so you can use them anywhere.",
                                   "散步時拍的照片也會存到 iPhone 的「照片」，在其他地方也能使用。"))
            }
            Section {
                Text(language.text("Your language preference is saved on this device and applies immediately.", "語言偏好會儲存在此裝置，切換後立即套用。"))
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
}
