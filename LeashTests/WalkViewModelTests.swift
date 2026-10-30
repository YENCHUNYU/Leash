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
        #expect(model.finish() != nil)
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
        #expect(model.finish() == nil)
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

struct SeveralDogsAndDiaryTests {
    @Test func walkRemembersItsDogsAndWhoDidWhat() {
        let model = WalkViewModel(store: FakeWalkStore(), location: FakeLocation())
        let a = UUID(), b = UUID()
        model.start(dogs: [a, b])
        model.log(.pee, dog: a)
        model.log(.pee, dog: b)
        model.log(.poop, dog: b)
        let walk = model.finish()
        #expect(walk?.dogIDs == [a, b])
        #expect(walk?.count(of: .pee) == 2)
        #expect(walk?.count(of: .poop, dog: a) == 0)
        #expect(walk?.count(of: .poop, dog: b) == 1)
    }

    @Test func diaryEntriesCanBeEditedAndLeftOut() throws {
        let store = FakeWalkStore()
        let model = WalkViewModel(store: store, location: FakeLocation())
        model.start()
        var walk = try #require(model.finish())
        walk.note = "Sunny"
        walk.setCount(of: .poop, to: 2)
        #expect(model.update(walk))
        #expect(store.archive.completed.first?.note == "Sunny")
        #expect(store.archive.completed.first?.count(of: .poop) == 2)
        #expect(model.delete(walk))
        #expect(store.archive.completed.isEmpty)
    }

    @Test func setCountAddsAndRemovesOnlyMatchingEvents() {
        let a = UUID(), b = UUID()
        var walk = Walk(endedAt: .now, events: [WalkEvent(kind: .pee, dogID: a), WalkEvent(kind: .pee, dogID: b)], dogIDs: [a, b])
        walk.setCount(of: .pee, dog: a, to: 3)
        #expect(walk.count(of: .pee, dog: a) == 3)
        #expect(walk.count(of: .pee, dog: b) == 1)
        walk.setCount(of: .pee, dog: a, to: 0)
        #expect(walk.count(of: .pee) == 1)
    }

    @Test func oldWalksWithoutDogsOrNotesStillLoad() throws {
        let json = #"{"id":"6B7A9E2C-0D5F-4E0B-9C1A-2F3E4D5C6B7A","startedAt":0,"events":[{"id":"1B7A9E2C-0D5F-4E0B-9C1A-2F3E4D5C6B7A","kind":"pee","timestamp":0}]}"#
        let walk = try JSONDecoder().decode(Walk.self, from: Data(json.utf8))
        #expect(walk.dogIDs.isEmpty)
        #expect(walk.note == nil)
        #expect(walk.events.first?.dogID == nil)
    }

    @Test func rosterWalksEveryDogUntilChosen() {
        var roster = DogRoster(dogs: [DogProfile(), DogProfile()])
        #expect(roster.walking.count == 2)
        roster.walkingIDs = [roster.dogs[1].id]
        #expect(roster.walking.map(\.id) == [roster.dogs[1].id])
        roster.walkingIDs = []
        #expect(roster.walking.map(\.id) == [roster.active.id])
    }
}
