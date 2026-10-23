import CoreLocation
import Testing
@testable import Leash

struct WalkViewModelTests {
    @Test func startPersistsWalkAndStartsGPS() {
        let store = FakeWalkStore(), location = FakeLocation()
        let model = WalkViewModel(store: store, location: location)
        model.start()
        #expect(store.archive.active != nil)
        #expect(model.activeWalk?.id == store.archive.active?.id)
        #expect(location.isUpdating)
        #expect(model.gpsStatus == .waitingForFix)
    }

    @Test func undeterminedPermissionIsRequestedOnStart() {
        let location = FakeLocation(authorization: .notDetermined)
        let model = WalkViewModel(store: FakeWalkStore(), location: location)
        model.start()
        #expect(location.permissionRequests == 1)
        #expect(model.gpsStatus == .waitingForPermission)
    }

    @Test func deniedPermissionStillAllowsEvents() {
        let model = WalkViewModel(store: FakeWalkStore(), location: FakeLocation(authorization: .denied))
        model.start()
        model.log(.pee)
        model.log(.poop)
        model.log(.pee)
        #expect(model.gpsStatus == .denied)
        #expect(model.activeWalk?.count(of: .pee) == 2)
        #expect(model.activeWalk?.count(of: .poop) == 1)
    }

    @Test func finishMovesWalkToHistory() {
        let store = FakeWalkStore(), location = FakeLocation()
        let model = WalkViewModel(store: store, location: location)
        model.start()
        let id = model.activeWalk?.id
        #expect(model.finish())
        #expect(model.activeWalk == nil)
        #expect(store.archive.active == nil)
        #expect(store.archive.completed.map(\.id) == [id])
        #expect(store.archive.completed.first?.endedAt != nil)
        #expect(!location.isUpdating)
    }

    @Test func failedFinishKeepsActiveWalk() {
        let store = FakeWalkStore()
        let model = WalkViewModel(store: store, location: FakeLocation())
        model.start()
        store.failSaves = true
        #expect(!model.finish())
        #expect(model.activeWalk != nil)
        #expect(model.archive.completed.isEmpty)
        #expect(model.error == .save)
    }

    @Test func failedLoadBlocksWrites() {
        let store = FakeWalkStore()
        store.failLoad = true
        let model = WalkViewModel(store: store, location: FakeLocation())
        model.start()
        #expect(!model.canWrite)
        #expect(model.error == .load)
        #expect(model.activeWalk == nil)
        #expect(store.saveCount == 0)
    }

    @Test func gpsJumpDoesNotAddDistance() {
        let location = FakeLocation()
        let model = WalkViewModel(store: FakeWalkStore(), location: location)
        model.start()
        let now = Date()
        location.send(fix(now: now))
        location.send(fix(north: 10, now: now.addingTimeInterval(3)))
        location.send(fix(north: 600, now: now.addingTimeInterval(5)))
        #expect(model.activeWalk?.route.count == 2)
        #expect(abs((model.activeWalk?.distanceMeters ?? 0) - 10) < 0.5)
        #expect(model.gpsStatus == .ignoringJump)
    }

    @Test func gpsPointIsDroppedWhenSaveFails() {
        let store = FakeWalkStore(), location = FakeLocation()
        let model = WalkViewModel(store: store, location: location)
        model.start()
        store.failSaves = true
        location.send(fix())
        #expect(model.activeWalk?.route.isEmpty == true)
    }
}
