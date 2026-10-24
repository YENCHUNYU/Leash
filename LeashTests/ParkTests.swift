import CoreLocation
import Testing
@testable import Leash

struct ParkQueryTests {
    let here = CLLocation(latitude: 25.0, longitude: 121.5)

    private func park(_ id: String, _ name: String, north meters: Double?, tags: Set<Spot.Tag> = [.offLeash],
                      region: String = "臺北市", address: String = "") -> Spot {
        Spot(id: id, name: name, country: .taiwan, region: region, subregion: "大安區", address: address, tags: tags,
             latitude: meters.map { 25.0 + $0 / 111_320 }, longitude: meters == nil ? nil : 121.5)
    }

    @Test func nearestIsDefaultAndSortsByDistance() {
        let parks = [park("far", "B", north: 900), park("near", "C", north: 100), park("none", "A", north: nil)]
        #expect(ParkQuery().filters == [.nearest])
        #expect(ParkQuery().apply(to: parks, origin: here).map(\.id) == ["near", "far", "none"])
    }

    @Test func withoutNearestSortsByName() {
        let parks = [park("1", "Zebra Park", north: 10), park("2", "Apple Park", north: 900)]
        var query = ParkQuery()
        query.filters = []
        #expect(query.apply(to: parks, origin: here).map(\.name) == ["Apple Park", "Zebra Park"])
    }

    @Test func facilityFiltersCombine() {
        let parks = [park("both", "A", north: 1, tags: [.water, .fence]), park("water", "B", north: 2, tags: [.water]),
                     park("none", "C", north: 3)]
        var query = ParkQuery()
        query.filters = [.nearest, .water]
        #expect(query.apply(to: parks, origin: here).map(\.id) == ["both", "water"])
        query.filters.insert(.fenced)
        #expect(query.apply(to: parks, origin: here).map(\.id) == ["both"])
    }

    @Test func searchMatchesNameAddressAndRegion() {
        let parks = [park("1", "Riverside Dog Run", north: 1, address: "12 Elm St, Irvine, CA"),
                     park("2", "迎風狗運動公園", north: 2, region: "新北市")]
        var query = ParkQuery()
        query.text = "riverside"
        #expect(query.apply(to: parks, origin: here).map(\.id) == ["1"])
        query.text = "irvine"
        #expect(query.apply(to: parks, origin: here).map(\.id) == ["1"])
        query.text = "新北"
        #expect(query.apply(to: parks, origin: here).map(\.id) == ["2"])
    }
}

struct ParkDataTests {
    @Test func missingFacilitiesAreNotVerifiedNotUnavailable() {
        let spot = Spot(id: "x", name: "X", country: .taiwan, region: "臺北市", subregion: "", address: "",
                        tags: [.fence], latitude: 25, longitude: 121)
        #expect(spot.status(.fence) == .available)
        #expect(spot.status(.water) == .notVerified)
        #expect(spot.leashPolicy == .unknown)
        #expect(spot.hoursDescription == nil)
    }

    @Test func bundledDataKeepsHoursAddressesAndCoordinates() async {
        let catalog = SpotCatalog(directory: nil)
        await catalog.loadBundled()
        #expect(catalog.bundled.allSatisfy { $0.coordinate != nil && $0.source == .openStreetMap })
        #expect(catalog.bundled.filter { $0.openingHours != nil }.count == 248)
        let us = catalog.spot(id: "osmn356542941")
        #expect(us?.address == "1190 Yew Avenue, Blaine, WA")
        #expect(catalog.spot(id: "osmw1557260053")?.address == "嘉義市東區")
    }

    @Test func customSpotsHaveNoInventedCoordinates() {
        let spot = CustomSpot(name: "Backyard", area: "Irvine", tags: [], country: .unitedStates, region: "Irvine").spot
        #expect(spot.coordinate == nil)
        #expect(spot.source == .userAdded)
        #expect(spot.distance(from: CLLocation(latitude: 0, longitude: 0)) == nil)
    }
}

struct LocateUserTests {
    @Test func asksPermissionThenFetchesOneFix() {
        let location = FakeLocation(authorization: .notDetermined)
        let model = WalkViewModel(store: FakeWalkStore(), location: location)
        model.locateUser()
        #expect(location.permissionRequests == 1)
        #expect(location.locationRequests == 0)
        location.grant(.authorizedWhenInUse)
        #expect(location.locationRequests == 1)
        #expect(model.authorization == .authorizedWhenInUse)
        #expect(!location.isUpdating)
    }

    @Test func fixesOutsideWalksUpdateLocationButNotRoute() {
        let location = FakeLocation()
        let model = WalkViewModel(store: FakeWalkStore(), location: location)
        location.send(fix(north: 50))
        #expect(model.currentLocation != nil)
        #expect(model.activeWalk == nil)
    }

    @Test func deniedPermissionDoesNotRequest() {
        let location = FakeLocation(authorization: .denied)
        let model = WalkViewModel(store: FakeWalkStore(), location: location)
        model.locateUser()
        #expect(location.permissionRequests == 0)
        #expect(location.locationRequests == 0)
    }
}
