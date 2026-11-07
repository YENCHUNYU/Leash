import Foundation
import CoreLocation

/// Light Kalman filter over GPS fixes, so noise doesn't draw zigzags.
/// Each fix pulls the estimate toward it in proportion to how much we trust it:
/// precise fixes move it a lot, noisy ones barely.
struct RouteSmoother {
    /// How fast the true position can drift, in m/s. About a brisk walk.
    static let processNoise: Double = 3

    private var estimate: CLLocation?
    /// Uncertainty of `estimate`, in square meters.
    private var variance: Double = 0

    mutating func reset() { estimate = nil }

    /// The smoothed position for `fix`, keeping the fix's own accuracy and timestamp
    /// so `RouteFilter` still judges the raw signal. Call `commit` to keep it.
    func smoothed(_ fix: CLLocation) -> (location: CLLocation, variance: Double) {
        let noise = max(fix.horizontalAccuracy, 1) * max(fix.horizontalAccuracy, 1)
        guard let estimate else { return (fix, noise) }
        let elapsed = fix.timestamp.timeIntervalSince(estimate.timestamp)
        // Out of order, or a gap long enough to start a new segment: start over at the fix.
        guard elapsed > 0, elapsed <= RouteFilter.maxSegmentGap else { return (fix, noise) }

        let predicted = variance + elapsed * Self.processNoise * Self.processNoise
        let gain = predicted / (predicted + noise)
        let latitude = estimate.coordinate.latitude + gain * (fix.coordinate.latitude - estimate.coordinate.latitude)
        let longitude = estimate.coordinate.longitude + gain * (fix.coordinate.longitude - estimate.coordinate.longitude)
        let location = CLLocation(coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                                  altitude: fix.altitude, horizontalAccuracy: fix.horizontalAccuracy,
                                  verticalAccuracy: fix.verticalAccuracy, timestamp: fix.timestamp)
        return (location, (1 - gain) * predicted)
    }

    mutating func commit(_ result: (location: CLLocation, variance: Double)) {
        estimate = result.location
        variance = result.variance
    }
}
