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

    var activeWalk: Walk? { archive.active }
    /// Latest route point during a walk, otherwise Core Location's cached fix.
    var currentLocation: CLLocation? {
        if let point = archive.active?.route.last { return CLLocation(latitude: point.latitude, longitude: point.longitude) }
        return location.lastLocation
    }
    var totalMinutes: Int {
        Int(archive.completed.reduce(0) { $0 + $1.duration(at: .now) } / 60)
    }

    init(store: any WalkStoring, location: any LocationTracking) {
        self.store = store
        self.location = location
        location.onLocation = { [weak self] in self?.receive($0) }
        location.onStatusChange = { [weak self] in self?.updateAuthorization() }
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

    func start(at spotID: String? = nil) {
        guard archive.active == nil, saveActive(Walk(spotID: spotID)) else { return }
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

    func log(_ kind: WalkEvent.Kind) {
        guard var walk = archive.active else { return }
        walk.events.append(WalkEvent(kind: kind))
        saveActive(walk)
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
