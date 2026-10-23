import SwiftUI

/// Composition root for the walk feature: builds the live services, then hands off to WalkHomeView.
struct WalkTrackingView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.appLanguage) private var language
    @State private var model: WalkViewModel?
    @State private var setupFailed = false

    var body: some View {
        ZStack {
            Theme.background(colorScheme).ignoresSafeArea()
            if let model {
                WalkHomeView(model: model)
            } else {
                ContentUnavailableView("Leash", systemImage: "pawprint", description: Text(
                    setupFailed ? WalkError.storageUnavailable.message(in: language) : language.text("Getting ready…", "準備中…")))
            }
        }
        .tint(Theme.accent)
        .task {
            guard model == nil else { return }
            do { model = WalkViewModel(store: try FileWalkStore(), location: LocationService()) }
            catch { setupFailed = true }
        }
    }
}

enum WalkFormat {
    static func duration(_ seconds: TimeInterval) -> String {
        Duration.seconds(seconds).formatted(.time(pattern: .hourMinuteSecond))
    }
    static func distance(_ walk: Walk, locale: Locale) -> String {
        Measurement(value: walk.distanceMeters, unit: UnitLength.meters)
            .formatted(.measurement(width: .abbreviated, usage: .road).locale(locale))
    }
}
