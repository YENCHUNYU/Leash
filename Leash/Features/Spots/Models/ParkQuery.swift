import Foundation
import CoreLocation

/// Filter chips on the Spots screen. All but `nearest` require the facility to be mapped.
enum ParkFilter: CaseIterable, Hashable {
    case nearest, offLeash, water, fenced, smallDogArea, wasteStations, shade

    var tag: Spot.Tag? {
        switch self {
        case .nearest: nil
        case .offLeash: .offLeash
        case .water: .water
        case .fenced: .fence
        case .smallDogArea: .zone
        case .wasteStations: .bag
        case .shade: .shade
        }
    }

    var systemImage: String { tag?.systemImage ?? "location.fill" }

    func label(in language: AppLanguage) -> String {
        switch self {
        case .nearest: language.text("Nearest", "最近")
        case .offLeash: language.text("Off-leash", "可放繩")
        case .water: language.text("Drinking water", "飲水")
        case .fenced: language.text("Fenced", "有圍欄")
        case .smallDogArea: language.text("Small dog area", "小型犬區")
        case .wasteStations: language.text("Waste stations", "便袋站")
        case .shade: language.text("Shade", "遮蔭")
        }
    }
}

/// Search, filters and region for the park list and map.
struct ParkQuery: Equatable {
    var text = ""
    var filters: Set<ParkFilter> = [.nearest]
    var region: String?
    var subregion: String?

    var requiredTags: Set<Spot.Tag> { Set(filters.compactMap(\.tag)) }

    func matches(_ spot: Spot) -> Bool {
        guard region == nil || spot.region == region, subregion == nil || spot.subregion == subregion,
              requiredTags.isSubset(of: spot.tags) else { return false }
        let needle = text.trimmingCharacters(in: .whitespaces)
        guard !needle.isEmpty else { return true }
        let haystack = [spot.name, spot.address, spot.region, spot.subregion, Regions.displayName(spot.region)].joined(separator: " ")
        return haystack.localizedCaseInsensitiveContains(needle)
    }

    /// Nearest first from `origin` when that chip is on; otherwise by name. Parks without coordinates sort last.
    func apply(to spots: [Spot], origin: CLLocation) -> [Spot] {
        let matching = spots.filter(matches)
        guard filters.contains(.nearest) else {
            return matching.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        }
        return matching
            .map { ($0, $0.distance(from: origin) ?? .infinity) }
            .sorted { $0.1 < $1.1 }
            .map(\.0)
    }
}
