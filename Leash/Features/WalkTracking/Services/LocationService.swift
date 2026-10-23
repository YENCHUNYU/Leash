import Foundation
import CoreLocation

@MainActor
protocol LocationTracking: AnyObject {
    var authorization: CLAuthorizationStatus { get }
    var onLocation: ((CLLocation) -> Void)? { get set }
    var onStatusChange: (() -> Void)? { get set }
    var onError: ((Error) -> Void)? { get set }
    func requestPermission()
    func start()
    func stop()
}

@MainActor
final class LocationService: NSObject, LocationTracking, @preconcurrency CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    var onLocation: ((CLLocation) -> Void)?
    var onStatusChange: (() -> Void)?
    var onError: ((Error) -> Void)?
    var authorization: CLAuthorizationStatus { manager.authorizationStatus }

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 5
        manager.activityType = .fitness
    }

    func requestPermission() { manager.requestWhenInUseAuthorization() }
    func start() {
        // Enable background updates only after the host app configures the capability.
        let modes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String] ?? []
        manager.allowsBackgroundLocationUpdates = modes.contains("location")
        manager.showsBackgroundLocationIndicator = true
        manager.startUpdatingLocation()
    }
    func stop() { manager.stopUpdatingLocation() }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) { onStatusChange?() }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for location in locations { onLocation?(location) }
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if (error as? CLError)?.code != .locationUnknown { onError?(error) }
    }
}
