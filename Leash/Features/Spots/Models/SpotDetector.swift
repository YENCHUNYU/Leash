import Foundation
import CoreLocation

/// Picks the park a finished walk was at, so the diary can name it instead of "Around the block".
/// A dog park wins over a regular park or trail; among those, the one the walk stayed near longest.
enum SpotDetector {
    /// OSM dog parks are small areas mapped by their middle.
    static let dogParkRadius: CLLocationDistance = 80
    /// Apple Maps parks and trails are one point for an area that is often much bigger.
    static let parkRadius: CLLocationDistance = 150

    /// Time near a place that counts as walking there: 30% of the walk, at least 1 and at most 3 minutes.
    static func timeNeeded(for walk: Walk) -> TimeInterval {
        max(60, min(180, walk.duration(at: walk.endedAt ?? .now) * 0.3))
    }

    static func detect(_ walk: Walk, among spots: [Spot]) -> Spot? {
        guard !walk.isIndoor, let first = walk.route.first else { return nil }
        // Only look at places near the route at all.
        let lats = walk.route.map(\.latitude), lons = walk.route.map(\.longitude)
        let margin = 0.004  // About 400 m.
        let candidates = spots.filter { spot in
            guard let latitude = spot.latitude, let longitude = spot.longitude, spot.source != .userAdded else { return false }
            return latitude >= lats.min()! - margin && latitude <= lats.max()! + margin
                && longitude >= lons.min()! - margin && longitude <= lons.max()! + margin
        }
        guard !candidates.isEmpty else { return nil }

        // Each route point stands for the time until the next one (the last, until the walk ended).
        let end = walk.endedAt ?? walk.route.last?.timestamp ?? first.timestamp
        let stays = walk.route.indices.map { index in
            let next = index + 1 < walk.route.count ? walk.route[index + 1].timestamp : end
            return (location: CLLocation(latitude: walk.route[index].latitude, longitude: walk.route[index].longitude),
                    seconds: max(0, next.timeIntervalSince(walk.route[index].timestamp)))
        }

        let needed = timeNeeded(for: walk)
        let scored = candidates.compactMap { spot -> (spot: Spot, seconds: TimeInterval)? in
            guard let place = spot.location else { return nil }
            let radius = spot.isDogPark ? dogParkRadius : parkRadius
            let seconds = stays.filter { $0.location.distance(from: place) <= radius }.reduce(0) { $0 + $1.seconds }
            return seconds >= needed ? (spot, seconds) : nil
        }
        let dogParks = scored.filter(\.spot.isDogPark)
        return (dogParks.isEmpty ? scored : dogParks).max { $0.seconds < $1.seconds }?.spot
    }

    /// The middle of the route, for loading the parks around it.
    static func center(of route: [RoutePoint]) -> CLLocationCoordinate2D? {
        guard !route.isEmpty else { return nil }
        let lats = route.map(\.latitude), lons = route.map(\.longitude)
        return CLLocationCoordinate2D(latitude: (lats.min()! + lats.max()!) / 2, longitude: (lons.min()! + lons.max()!) / 2)
    }
}
