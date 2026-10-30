import Foundation
import CoreLocation
import Observation

@MainActor @Observable
final class WalkViewModel {
    private(set) var archive = WalkArchive()
    private(set) var gpsStatus = GPSStatus.ready
    var error: WalkError?
    /// False after a failed load, so unreadable data is never overwritten.
    private(set) var canWrite = false
    private let store: any WalkStoring
    private let location: any LocationTracking
    private var previousLocation: CLLocation?
    private(set) var authorization: CLAuthorizationStatus
    /// Most recent accurate fix, kept even when no walk is running.
    private(set) var lastFix: CLLocation?
    private var wantsCurrentLocation = false

    var activeWalk: Walk? { archive.active }
    /// Latest route point during a walk, otherwise Core Location's cached fix.
    var currentLocation: CLLocation? {
        if let point = archive.active?.route.last { return CLLocation(latitude: point.latitude, longitude: point.longitude) }
        return lastFix ?? location.lastLocation
    }
    var totalMinutes: Int {
        Int(archive.completed.reduce(0) { $0 + $1.duration(at: .now) } / 60)
    }

    init(store: any WalkStoring, location: any LocationTracking) {
        self.store = store
        self.location = location
        authorization = location.authorization
        location.onLocation = { [weak self] in self?.receive($0) }
        location.onStatusChange = { [weak self] in self?.authorizationChanged() }
        location.onError = { [weak self] _ in self?.gpsStatus = .failed }
        reload()
    }

    func reload() {
        do {
            archive = try store.load()
            canWrite = true
            previousLocation = nil
            updateAuthorization()
        } catch {
            canWrite = false
            self.error = .load
        }
    }

    func start(at spotID: String? = nil, dogs: [UUID] = []) {
        guard archive.active == nil, saveActive(Walk(spotID: spotID, dogIDs: dogs)) else { return }
        previousLocation = nil
        updateAuthorization()
    }

    /// Returns the saved walk, or nil if it could not be saved.
    @discardableResult
    func finish() -> Walk? {
        guard canWrite, var walk = archive.active else { return nil }
        walk.endedAt = Date()
        let completed = [walk] + archive.completed
        guard saveCompleted(completed) else { return nil }
        // History is durable now; if clearing fails, load discards the stale active walk.
        try? store.saveActive(nil)
        archive = WalkArchive(active: nil, completed: completed)
        location.stop()
        previousLocation = nil
        gpsStatus = .ready
        return walk
    }

    func setSpot(_ spotID: String) {
        guard var walk = archive.active else { return }
        walk.spotID = spotID
        saveActive(walk)
    }

    func attachPhoto(_ id: UUID) {
        guard var walk = archive.active else { return }
        walk.photoIDs.append(id)
        saveActive(walk)
    }

    /// Records a ten-minute indoor play session, which counts toward the daily walk quest.
    @discardableResult
    func logIndoorPlay(_ activity: String, at date: Date = .now) -> Bool {
        let session = Walk(startedAt: date.addingTimeInterval(-600), endedAt: date,
                           spotID: Spot.indoorID, indoorActivity: activity)
        return saveCompleted([session] + archive.completed)
    }

    @discardableResult
    func delete(_ walk: Walk) -> Bool {
        saveCompleted(archive.completed.filter { $0.id != walk.id })
    }

    /// Saves changes to a diary entry.
    @discardableResult
    func update(_ walk: Walk) -> Bool {
        guard let index = archive.completed.firstIndex(where: { $0.id == walk.id }) else { return false }
        var completed = archive.completed
        completed[index] = walk
        return saveCompleted(completed)
    }

    /// Logs a pee or poop, for one dog when several are out.
    func log(_ kind: WalkEvent.Kind, dog: UUID? = nil) {
        guard var walk = archive.active else { return }
        walk.events.append(WalkEvent(kind: kind, dogID: dog))
        saveActive(walk)
    }

    /// Finds the user without starting a walk, asking for permission first if needed.
    func locateUser() {
        switch location.authorization {
        case .notDetermined:
            wantsCurrentLocation = true
            location.requestPermission()
        case .authorizedAlways, .authorizedWhenInUse:
            location.requestCurrentLocation()
        default:
            break
        }
    }

    private func authorizationChanged() {
        authorization = location.authorization
        updateAuthorization()
        if wantsCurrentLocation, authorization == .authorizedWhenInUse || authorization == .authorizedAlways {
            wantsCurrentLocation = false
            location.requestCurrentLocation()
        }
    }

    func updateAuthorization() {
        guard archive.active != nil else { return }
        switch location.authorization {
        case .notDetermined:
            gpsStatus = .waitingForPermission
            location.requestPermission()
        case .authorizedAlways, .authorizedWhenInUse:
            gpsStatus = .waitingForFix
            location.start()
        case .denied, .restricted:
            location.stop()
            previousLocation = nil
            gpsStatus = .denied
        @unknown default:
            gpsStatus = .failed
        }
    }

    private func receive(_ fix: CLLocation) {
        if fix.horizontalAccuracy >= 0, fix.horizontalAccuracy <= 100 { lastFix = fix }
        guard var walk = archive.active else { return }
        switch RouteFilter.evaluate(fix, previous: previousLocation, walk: walk) {
        case .inaccurate:
            gpsStatus = .weakSignal
        case .jump:
            gpsStatus = .ignoringJump
        case .skip:
            break
        case .accept(let distance):
            walk.distanceMeters += distance
            walk.route.append(RoutePoint(latitude: fix.coordinate.latitude,
                                         longitude: fix.coordinate.longitude, timestamp: fix.timestamp))
            if saveActive(walk) {
                previousLocation = fix
                gpsStatus = .tracking
            }
        }
    }

    private func saveCompleted(_ completed: [Walk]) -> Bool {
        guard canWrite else { return false }
        do {
            try store.saveCompleted(completed)
            archive.completed = completed
            return true
        } catch {
            self.error = .save
            return false
        }
    }

    /// Persists first, then publishes, so the UI never shows unsaved state.
    @discardableResult
    private func saveActive(_ walk: Walk?) -> Bool {
        guard canWrite else { return false }
        do {
            try store.saveActive(walk)
            archive.active = walk
            return true
        } catch {
            self.error = .save
            return false
        }
    }
}
