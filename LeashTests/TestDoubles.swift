import CoreLocation
@testable import Leash

struct TestFailure: Error {}

final class FakeWalkStore: WalkStoring {
    var archive: WalkArchive
    var failLoad = false
    var failSaves = false
    private(set) var saveCount = 0

    init(_ archive: WalkArchive = WalkArchive()) { self.archive = archive }

    func load() throws -> WalkArchive {
        if failLoad { throw TestFailure() }
        return archive
    }
    func saveActive(_ walk: Walk?) throws {
        if failSaves { throw TestFailure() }
        saveCount += 1
        archive.active = walk
    }
    func saveCompleted(_ walks: [Walk]) throws {
        if failSaves { throw TestFailure() }
        saveCount += 1
        archive.completed = walks
    }
}

final class FakeLocation: LocationTracking {
    var authorization: CLAuthorizationStatus
    var lastLocation: CLLocation?
    var onLocation: ((CLLocation) -> Void)?
    var onStatusChange: (() -> Void)?
    var onError: ((Error) -> Void)?
    private(set) var isUpdating = false
    private(set) var permissionRequests = 0

    init(authorization: CLAuthorizationStatus = .authorizedWhenInUse) { self.authorization = authorization }

    func requestPermission() { permissionRequests += 1 }
    private(set) var locationRequests = 0
    func requestCurrentLocation() { locationRequests += 1 }
    func grant(_ status: CLAuthorizationStatus) {
        authorization = status
        onStatusChange?()
    }
    func start() { isUpdating = true }
    func stop() { isUpdating = false }
    func send(_ fix: CLLocation) { onLocation?(fix) }
}

/// A fix `north` metres from a fixed origin, `secondsAgo` before now.
func fix(north: Double = 0, secondsAgo: TimeInterval = 0, accuracy: CLLocationAccuracy = 5, now: Date = .now) -> CLLocation {
    CLLocation(coordinate: CLLocationCoordinate2D(latitude: 25.0330 + north / 111_320, longitude: 121.5654),
               altitude: 0, horizontalAccuracy: accuracy, verticalAccuracy: -1,
               timestamp: now.addingTimeInterval(-secondsAgo))
}
