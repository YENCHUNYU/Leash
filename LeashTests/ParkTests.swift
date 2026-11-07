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

    @Test func bundledParksCarrySourceLinksAndEditDates() async {
        let catalog = SpotCatalog(directory: nil)
        await catalog.loadBundled()
        #expect(catalog.fetchedOn?.count == 10)
        let park = catalog.spot(id: "osmw1557260053")
        #expect(park?.sourceURL?.absoluteString == "https://www.openstreetmap.org/way/1557260053")
        #expect(park?.lastUpdated?.count == 10)
        #expect(catalog.bundled.filter { $0.lastUpdated != nil }.count > 8_000)
    }

    @Test func sourceLinksOnlyForOpenStreetMapIDs() {
        func spot(_ id: String, source: Spot.Source = .openStreetMap) -> Spot {
            Spot(id: id, name: "X", country: .taiwan, region: "", subregion: "", address: "", tags: [],
                 latitude: nil, longitude: nil, source: source)
        }
        #expect(spot("osmn42").sourceURL?.absoluteString == "https://www.openstreetmap.org/node/42")
        #expect(spot("osmr7").sourceURL?.absoluteString == "https://www.openstreetmap.org/relation/7")
        #expect(spot("osmx7").sourceURL == nil)
        #expect(spot("osmw").sourceURL == nil)
        #expect(spot("c123", source: .userAdded).sourceURL == nil)
    }

    @Test func customSpotsRecordWhenTheyWereAdded() throws {
        let new = CustomSpot(name: "Backyard", area: "Irvine", tags: [], country: .unitedStates, region: "Irvine")
        #expect(new.spot.lastUpdated?.count == 10)
        // Spots saved before the date was recorded still load, with the date unknown.
        let old = try JSONDecoder().decode(CustomSpot.self, from: Data(#"{"id":"c1","name":"Old","area":"","tags":[],"country":"taiwan","region":"臺北市"}"#.utf8))
        #expect(old.spot.lastUpdated == nil)
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

struct NearbyPlacesTests {
    private func spot(_ kind: Spot.Kind) -> Spot {
        Spot(id: "x", name: "Mason Park", country: .unitedStates, region: "CA", subregion: "", address: "",
             tags: [], latitude: 33.65, longitude: -117.83, source: kind == .dogPark ? .openStreetMap : .appleMaps, kind: kind)
    }

    @Test func dogParksOnlyHidesParksAndTrails() {
        var query = ParkQuery()
        query.filters = [.dogParksOnly]
        #expect(query.matches(spot(.dogPark)))
        #expect(!query.matches(spot(.park)))
        #expect(!query.matches(spot(.trail)))
    }

    @Test func parksAreUsuallyLeashed() {
        #expect(spot(.park).leashPolicy == .usuallyLeashed)
        #expect(spot(.dogPark).leashPolicy == .unknown)
    }

    @Test func spotsAppleListsAsDogParks() {
        #expect(ApplePlaces.looksLikeDogPark("Central Bark"))
        #expect(ApplePlaces.looksLikeDogPark("華江寵物公園"))
        #expect(!ApplePlaces.looksLikeDogPark("Mason Regional Park"))
    }

    @Test func unnamedDogParksAreMarked() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("spots-\(UUID()).json")
        try #"[["w1","Dog Park · Orange","Irvine, CA","",64,33.6,-117.8,"","Orange County"],["w2","Central Bark","Irvine, CA","",64,33.6,-117.8,"","Orange County"]]"#
            .data(using: .utf8)!.write(to: url)
        let spots = SpotCatalog.decode(url)
        #expect(spots.map(\.name) == ["Dog Park", "Central Bark"])
        #expect(spots.map(\.hasGenericName) == [true, false])
    }
}

struct SpotDetectorTests {
    let start = Date(timeIntervalSince1970: 1_800_000_000)

    /// A walk that stands at `north` meters for each (meters, seconds) leg, from 33.65, -117.83.
    private func walk(_ legs: [(north: Double, seconds: Double)]) -> Walk {
        var time = start
        var walk = Walk(startedAt: start)
        for leg in legs {
            walk.route.append(RoutePoint(latitude: 33.65 + leg.north / 111_320, longitude: -117.83, timestamp: time))
            time = time.addingTimeInterval(leg.seconds)
        }
        walk.endedAt = time
        return walk
    }

    private func place(_ name: String, north: Double, kind: Spot.Kind) -> Spot {
        Spot(id: name, name: name, country: .unitedStates, region: "CA", subregion: "", address: "", tags: [],
             latitude: 33.65 + north / 111_320, longitude: -117.83,
             source: kind == .dogPark ? .openStreetMap : .appleMaps, kind: kind)
    }

    @Test func namesTheDogParkTheWalkStayedAt() {
        let trip = walk([(0, 120), (500, 600), (0, 60)])
        let found = SpotDetector.detect(trip, among: [place("Bark Park", north: 520, kind: .dogPark)])
        #expect(found?.name == "Bark Park")
    }

    @Test func passingByIsNotEnough() {
        let trip = walk([(0, 600), (500, 20), (1000, 600)])
        #expect(SpotDetector.detect(trip, among: [place("Bark Park", north: 500, kind: .dogPark)]) == nil)
    }

    @Test func dogParkWinsOverTheParkAroundIt() {
        let trip = walk([(0, 900), (60, 300)])
        let found = SpotDetector.detect(trip, among: [place("Mason Park", north: 0, kind: .park),
                                                      place("Bark Park", north: 60, kind: .dogPark)])
        #expect(found?.name == "Bark Park")
    }

    @Test func fallsBackToAParkOrTrail() {
        let trip = walk([(0, 300), (100, 300)])
        let found = SpotDetector.detect(trip, among: [place("Far Dog Park", north: 3000, kind: .dogPark),
                                                      place("Creek Trail", north: 50, kind: .trail)])
        #expect(found?.name == "Creek Trail")
    }

    @Test func standingStillAtOnePointCounts() {
        // With little movement the route can be a single point; its time runs to the end of the walk.
        let trip = walk([(10, 400)])
        #expect(SpotDetector.detect(trip, among: [place("Bark Park", north: 0, kind: .dogPark)])?.name == "Bark Park")
    }
}

struct CommunityFacilitiesTests {
    typealias Tally = CommunityFacilities.Tally

    @Test func needsTwoAgreeingPeople() {
        #expect(CommunityFacilities.status(of: Tally(yes: 1, no: 0)) == .mixed(Tally(yes: 1, no: 0)))
        #expect(CommunityFacilities.status(of: Tally(yes: 2, no: 0)) == .confirmedYes(2))
        #expect(CommunityFacilities.status(of: Tally(yes: 0, no: 3)) == .confirmedNo(3))
    }

    @Test func disagreementStaysOpen() {
        #expect(CommunityFacilities.status(of: Tally(yes: 3, no: 2)) == .mixed(Tally(yes: 3, no: 2)))
        #expect(CommunityFacilities.status(of: Tally(yes: 4, no: 2)) == .confirmedYes(4))
        #expect(CommunityFacilities.status(of: Tally()) == .unknown)
    }

    @Test func facilityKeysRoundTrip() {
        for tag in Spot.Tag.allCases { #expect(Spot.Tag(key: tag.key) == tag) }
    }

    @Test @MainActor func mappedFacilitiesAreNotAskedAbout() {
        let community = CommunityFacilities(isEnabled: false)
        let spot = Spot(id: "osmw-test-\(UUID())", name: "Bark", country: .unitedStates, region: "CA", subregion: "",
                        address: "", tags: [.water], latitude: 33.6, longitude: -117.8)
        #expect(community.status(of: .water, at: spot) == .mapped)
        #expect(!community.unanswered(at: spot, visited: true).contains(.water))
        #expect(community.unanswered(at: spot, visited: true).contains(.fence))
        #expect(community.unanswered(at: spot, visited: false).isEmpty)
    }

    private var park: Spot {
        Spot(id: "osmw-park", name: "Bark", country: .unitedStates, region: "CA", subregion: "", address: "",
             tags: [], latitude: 33.65, longitude: -117.83)
    }

    @Test func onlyVisitorsCanReport() {
        #expect(!CommunityFacilities.hasVisited(park, walks: [], current: nil))
        // Standing nearby now.
        #expect(CommunityFacilities.hasVisited(park, walks: [], current: CLLocation(latitude: 33.651, longitude: -117.83)))
        // Far away now.
        #expect(!CommunityFacilities.hasVisited(park, walks: [], current: CLLocation(latitude: 33.70, longitude: -117.83)))
    }

    @Test func aPastWalkCountsNoMatterWhen() {
        var linked = Walk(startedAt: Date(timeIntervalSince1970: 0))
        linked.spotID = park.id
        #expect(CommunityFacilities.hasVisited(park, walks: [linked], current: nil))

        var passedBy = Walk(startedAt: Date(timeIntervalSince1970: 0))
        passedBy.route = [RoutePoint(latitude: 33.6505, longitude: -117.83, timestamp: .now)]
        #expect(CommunityFacilities.hasVisited(park, walks: [passedBy], current: nil))

        var elsewhere = Walk(startedAt: Date(timeIntervalSince1970: 0))
        elsewhere.route = [RoutePoint(latitude: 33.70, longitude: -117.83, timestamp: .now)]
        #expect(!CommunityFacilities.hasVisited(park, walks: [elsewhere], current: nil))
    }
}
