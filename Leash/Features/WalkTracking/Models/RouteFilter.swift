import Foundation
import CoreLocation

/// Decides whether a GPS fix extends the route. Thresholds are initial heuristics requiring field tuning.
enum RouteFilter {
    /// Walking routes are only tens of meters across, so anything vaguer than this draws spikes.
    static let maxAccuracy: CLLocationAccuracy = 20
    static let maxFixAge: TimeInterval = 15
    /// A fast jog with the dog; GPS bounces show up as faster "movement" than this.
    static let maxWalkingSpeed: CLLocationSpeed = 4
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

    /// `lastSeen` is when the last usable fix arrived, drawn or not. Standing still skips fixes
    /// without losing GPS, so only a gap since `lastSeen` means tracking was lost.
    static func evaluate(_ fix: CLLocation, previous: CLLocation?, lastSeen: Date? = nil, walk: Walk, now: Date = .now) -> Decision {
        guard fix.horizontalAccuracy >= 0, fix.horizontalAccuracy <= maxAccuracy,
              abs(fix.timestamp.timeIntervalSince(now)) <= maxFixAge,
              fix.timestamp >= walk.startedAt else { return .inaccurate }
        if let last = walk.route.last, fix.timestamp <= last.timestamp { return .skip }
        guard let previous else { return .accept(distance: 0) }

        let elapsed = fix.timestamp.timeIntervalSince(previous.timestamp)
        guard elapsed > 0 else { return .skip }
        guard fix.timestamp.timeIntervalSince(lastSeen ?? previous.timestamp) <= maxSegmentGap else { return .accept(distance: 0) }
        let distance = fix.distance(from: previous)
        guard distance / elapsed <= maxWalkingSpeed else { return .jump }
        // Steps well inside the fix's own error are probably noise. The smoother has already damped
        // the jitter, so half the error is enough; more would drop the corners of small loops.
        guard distance >= max(minStep, fix.horizontalAccuracy / 2) else { return .skip }
        return .accept(distance: distance)
    }
}
