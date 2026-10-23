import SwiftUI

struct ContentView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(AppLanguage.storageKey) private var languageCode = AppLanguage.initial
    @State private var showingLaunch = true
    private var language: AppLanguage { AppLanguage(rawValue: languageCode) ?? .english }

    var body: some View {
        // Mount tracking after the introduction so a location prompt cannot obscure it.
        Group {
            if showingLaunch {
                LaunchScreenView()
            } else {
                WalkTrackingView()
            }
        }
        .environment(\.appLanguage, language)
        .environment(\.locale, language.locale)
        .task {
            guard showingLaunch else { return }
            do { try await Task.sleep(for: .seconds(1)) }
            catch { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                showingLaunch = false
            }
        }
    }
}
