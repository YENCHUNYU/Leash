import Foundation
import CoreLocation

/// Decides whether a GPS fix extends the route. Thresholds are initial heuristics requiring field tuning.
enum RouteFilter {
    static let maxAccuracy: CLLocationAccuracy = 50
    static let maxFixAge: TimeInterval = 15
    static let maxWalkingSpeed: CLLocationSpeed = 8
    static let minStep: CLLocationDistance = 5
    /// Longer gaps start a new segment; never bridge missing background tracking.
    static let maxSegmentGap: TimeInterval = 30

    enum Decision: Equatable {
        /// Append the fix, adding `distance` to the walk.
        case accept(distance: CLLocationDistance)
        case inaccurate
        case jump
        /// Duplicate, out of order, or too close to the previous fix.
        case skip
    }

    static func evaluate(_ fix: CLLocation, previous: CLLocation?, walk: Walk, now: Date = .now) -> Decision {
        guard fix.horizontalAccuracy >= 0, fix.horizontalAccuracy <= maxAccuracy,
              abs(fix.timestamp.timeIntervalSince(now)) <= maxFixAge,
              fix.timestamp >= walk.startedAt else { return .inaccurate }
        if let last = walk.route.last, fix.timestamp <= last.timestamp { return .skip }
        guard let previous else { return .accept(distance: 0) }

        let elapsed = fix.timestamp.timeIntervalSince(previous.timestamp)
        guard elapsed > 0 else { return .skip }
        guard elapsed <= maxSegmentGap else { return .accept(distance: 0) }
        let distance = fix.distance(from: previous)
        guard distance / elapsed <= maxWalkingSpeed else { return .jump }
        guard distance >= minStep else { return .skip }
        return .accept(distance: distance)
    }
}
