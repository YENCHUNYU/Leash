import SwiftUI

/// Composition root: builds the live services, then hands off to WalkHomeView.
struct WalkTrackingView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.appLanguage) private var language
    @State private var services: Services?
    @State private var setupFailed = false

    private struct Services {
        let walks: WalkViewModel
        let game: GameModel
        let toaster = Toaster()
    }

    var body: some View {
        ZStack {
            Theme.background(colorScheme).ignoresSafeArea()
            if let services {
                WalkHomeView(model: services.walks)
                    .environment(services.game)
                    .environment(services.game.photos)
                    .environment(services.game.spots)
                    .environment(services.toaster)
                    .toasts(services.toaster)
                    .task { await services.game.spots.loadBundled() }
            } else {
                ContentUnavailableView("Leash", systemImage: "pawprint", description: Text(
                    setupFailed ? WalkError.storageUnavailable.message(in: language) : language.text("Getting ready…", "準備中…")))
            }
        }
        .tint(Theme.accent)
        .task {
            guard services == nil else { return }
            do {
                let directory = try LeashDirectory.url()
                let walks = WalkViewModel(store: try FileWalkStore(directory: directory), location: LocationService())
                let game = GameModel(walks: walks, photos: try PhotoLibrary(directory: directory),
                                     spots: SpotCatalog(directory: directory), directory: directory)
                services = Services(walks: walks, game: game)
            } catch {
                setupFailed = true
            }
        }
    }
}

enum WalkFormat {
    static func duration(_ seconds: TimeInterval) -> String {
        Duration.seconds(seconds).formatted(.time(pattern: .hourMinuteSecond))
    }
    static func distance(_ walk: Walk, locale: Locale) -> String {
        distance(meters: walk.distanceMeters, locale: locale)
    }
    static func distance(meters: Double, locale: Locale) -> String {
        Measurement(value: meters, unit: UnitLength.meters)
            .formatted(.measurement(width: .abbreviated, usage: .road).locale(locale))
    }
    /// Minutes per kilometre or mile, matching the distance unit for the locale.
    static func pace(_ walk: Walk, locale: Locale) -> String {
        let miles = locale.measurementSystem == .us
        let units = walk.distanceMeters / (miles ? 1609.344 : 1000)
        guard units >= 0.05 else { return "--" }
        let perUnit = walk.duration(at: .now) / units
        return "\(Int(perUnit) / 60)'\(String(format: "%02d", Int(perUnit) % 60))\" /\(miles ? "mi" : "km")"
    }
    static func spotName(_ walk: Walk, spots: SpotCatalog, language: AppLanguage) -> String {
        if walk.isIndoor { return language.text("Indoor play", "在家玩") }
        return spots.spot(id: walk.spotID)?.name ?? language.text("Around the block", "附近散步")
    }
}
