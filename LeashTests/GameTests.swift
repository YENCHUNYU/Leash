import Foundation
import Testing
@testable import Leash

struct SeededRandomTests {
    /// Reference values from the HTML app's hashStr, computed in Node.
    @Test(arguments: [("egg#0", 0.6415743248071522, 0.16072946367785335),
                      ("abc", 0.41744336066767573, 0.7136264541186392),
                      ("散步#1", 0.048067941097542644, 0.4262067957315594)])
    func matchesReferenceImplementation(seed: String, first: Double, second: Double) {
        var random = SeededRandom(seed)
        #expect(random.next() == first)
        #expect(random.next() == second)
    }
}

struct ProgressTests {
    let calendar = Calendar(identifier: .gregorian)
    let noon = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 3, day: 10, hour: 12))!

    private func walk(minutes: Double, daysAgo: Int = 0, poop: Bool = false, spot: String? = nil) -> Walk {
        let start = calendar.date(byAdding: .day, value: -daysAgo, to: noon)!
        return Walk(startedAt: start, endedAt: start.addingTimeInterval(minutes * 60),
                    events: poop ? [WalkEvent(kind: .poop)] : [], spotID: spot)
    }

    private func progress(_ walks: [Walk], photos: [Photo] = [], game: GameState = GameState(), spots: [Spot] = []) -> GameProgress {
        GameProgress(walks: walks, photos: photos, customSpotCount: 0, game: game,
                 spot: { id in spots.first { $0.id == id } }, now: noon, calendar: calendar)
    }

    @Test func newPlayerStartsAtLevelOneWithFiveTreats() {
        let empty = progress([])
        #expect(empty.level == 1)
        #expect(empty.treats == 5)
        #expect(empty.xp == 0)
    }

    @Test func walkEarnsXPAndTreats() {
        // 30 min: 10 + 30 XP, +5 for logging; 3 + 3 treats on top of the starting 5.
        let result = progress([walk(minutes: 30, poop: true)])
        #expect(result.xp == 45)
        #expect(result.treats == 11)
        #expect(result.outdoorMinutes == 30)
    }

    @Test func completingDailyQuestsAddsBonus() {
        let walks = [walk(minutes: 25, poop: true)]
        let photo = Photo(takenAt: noon)
        let without = progress(walks)
        let with = progress(walks, photos: [photo])
        // Photo is +5 XP / +1 treat, and all three quests add +20 XP / +5 treats.
        #expect(with.xp - without.xp == 25)
        #expect(with.treats - without.treats == 6)
        #expect(with.day(noon, calendar: calendar).allQuestsDone)
    }

    @Test func levelCurveIsQuadratic() {
        var state = GameProgress()
        state.xp = 59
        #expect(state.level == 1)
        state.xp = 60
        #expect(state.level == 2)
        #expect(state.nextLevelXP == 240)
    }

    @Test func streaksCountConsecutiveDays() {
        let result = progress([walk(minutes: 10, daysAgo: 0), walk(minutes: 10, daysAgo: 1), walk(minutes: 10, daysAgo: 2),
                               walk(minutes: 10, daysAgo: 5)])
        #expect(result.currentStreak == 3)
        #expect(result.bestStreak == 3)
    }

    @Test func eggsHatchEveryTwoHoursOfWalking() {
        let result = progress([walk(minutes: 100), walk(minutes: 50, daysAgo: 1)])
        #expect(result.hatchedEggs == 1)
        #expect(result.eggMinutesLeft == 90)
    }

    @Test func firstVisitToSpotIsCollected() {
        let park = Spot(id: "p1", name: "Park", country: .taiwan, region: "新北市", subregion: "板橋區", detail: "",
                        tags: [.water], latitude: 25, longitude: 121.5)
        let result = progress([walk(minutes: 10, spot: "p1"), walk(minutes: 10, daysAgo: 1, spot: "p1")], spots: [park])
        #expect(result.visitedSpotIDs == ["p1"])
        #expect(result.visitedRegions == ["新北市"])
        // Two walks (10 + 10 XP each) plus one first-visit bonus of 30.
        #expect(result.xp == 70)
    }

    @Test func spentTreatsAndFriendsAffectTotals() {
        var game = GameState()
        game.treatsSpent = 3
        game.friends = ["husky": 2]
        let result = progress([], game: game)
        #expect(result.treats == 2)
        #expect(result.xp == Breed.Rarity.rare.xp + 10)
        #expect(result.friendKinds == 1)
    }
}

struct EncounterTests {
    let start = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func visitorsArriveOverTime() {
        let walk = Walk(startedAt: start)
        func count(after minutes: Double) -> Int {
            EncounterRules.pending(walk: walk, spot: nil, hatchedEggs: 0, game: GameState(), language: .english,
                                   now: start.addingTimeInterval(minutes * 60)).count
        }
        #expect(count(after: 0.5) == 0)
        #expect(count(after: 1) == 1)
        #expect(count(after: 9) == 2)
        #expect(count(after: 120) == 4)
    }

    @Test func resolvedEncountersAndIndoorWalksAreExcluded() {
        let walk = Walk(startedAt: start)
        let now = start.addingTimeInterval(600)
        let all = EncounterRules.pending(walk: walk, spot: nil, hatchedEggs: 1, game: GameState(), language: .english, now: now)
        #expect(all.count == 3)
        #expect(all.filter(\.fromEgg).count == 1)
        #expect(all.filter(\.fromEgg).allSatisfy { $0.breed.rarity != .common })

        var game = GameState()
        game.outcomes[all[0].id] = .befriended
        #expect(EncounterRules.pending(walk: walk, spot: nil, hatchedEggs: 1, game: game, language: .english, now: now).count == 2)

        let indoor = Walk(startedAt: start, indoorActivity: "Snuffle")
        #expect(EncounterRules.pending(walk: indoor, spot: nil, hatchedEggs: 1, game: GameState(), language: .english, now: now).isEmpty)
    }

    @Test func breedsAreStablePerSeed() {
        let context = EncounterRules.Context()
        #expect(EncounterRules.breed(seed: "walk#0", context: context) == EncounterRules.breed(seed: "walk#0", context: context))
    }

    @Test func eggsNeverHatchCommonDogs() {
        for index in 0..<200 {
            #expect(EncounterRules.breed(seed: "egg#\(index)", context: .init(), minimumRarity: .uncommon).rarity != .common)
        }
    }
}

struct GameModelTests {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)

    private func makeGame() throws -> (GameModel, WalkViewModel) {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let walks = WalkViewModel(store: FakeWalkStore(), location: FakeLocation())
        let game = GameModel(walks: walks, photos: try PhotoLibrary(directory: directory),
                             spots: SpotCatalog(directory: directory), directory: directory)
        return (game, walks)
    }

    @Test func tossingSpendsTreatsUntilResolved() throws {
        let (game, _) = try makeGame()
        let encounter = Encounter(id: "test#0", breed: Breed.named("formosan"), fromEgg: false)
        var results: [GameModel.TossResult] = []
        for _ in 0..<EncounterRules.triesPerDog {
            let result = game.toss(to: encounter)
            results.append(result)
            if case .missed = result { continue }
            break
        }
        #expect(game.state.treatsSpent == results.count)
        #expect(game.state.outcomes[encounter.id] != nil)
        if case .befriended = results.last { #expect(game.state.friends["formosan"] == 1) }
        else { #expect(results.last == .ranOff) }
    }

    @Test func stateAndProfilePersist() throws {
        let (game, _) = try makeGame()
        game.sayBye(to: Encounter(id: "x#0", breed: Breed.named("mixy"), fromEgg: false))
        game.updateProfile { $0.name = "Mochi" }
        let (reloaded, _) = try makeGame()
        #expect(reloaded.state.outcomes["x#0"] == .left)
        #expect(reloaded.profile.name == "Mochi")
    }

    @Test func noTreatsMeansNoToss() throws {
        let (game, _) = try makeGame()
        let encounter = Encounter(id: "y#0", breed: Breed.named("mixy"), fromEgg: false)
        for index in 0..<GameProgress.startingTreats {
            _ = game.toss(to: Encounter(id: "spend#\(index)", breed: Breed.named("formosan"), fromEgg: false))
        }
        #expect(game.progress.treats == 0)
        #expect(game.toss(to: encounter) == .noTreats)
    }

    @Test func indoorPlayCompletesWalkQuest() throws {
        let (game, walks) = try makeGame()
        #expect(walks.logIndoorPlay("Snuffle"))
        let walkQuest = game.quests(language: .english).first
        #expect(walkQuest?.isDone == true)
    }

    @Test func coatsUnlockByFriendship() throws {
        let (game, _) = try makeGame()
        #expect(game.isUnlocked(Breed.named("shiba")))
        #expect(!game.isUnlocked(Breed.named("husky")))
    }
}

struct SpotAndWalkDataTests {
    @Test func bundledSpotsDecode() async {
        let catalog = SpotCatalog(directory: nil)
        await catalog.loadBundled()
        #expect(catalog.bundled.count == 8_544)
        let taiwan = catalog.bundled.filter { $0.country == .taiwan }
        #expect(taiwan.count == 56)
        #expect(taiwan.allSatisfy { Regions.taiwan.contains($0.region) })
        #expect(catalog.bundled.filter { $0.country == .unitedStates }.allSatisfy { Regions.unitedStates[$0.region] != nil })
        #expect(catalog.spot(id: "osmw1557260053")?.region == "嘉義市")
    }

    @Test func walksSavedBeforeGameFieldsStillDecode() throws {
        let legacy = #"{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","startedAt":800000000,"distanceMeters":12,"route":[],"events":[]}"#
        let walk = try JSONDecoder().decode(Walk.self, from: Data(legacy.utf8))
        #expect(walk.distanceMeters == 12)
        #expect(walk.photoIDs.isEmpty)
        #expect(walk.spotID == nil)
        #expect(!walk.isIndoor)
    }
}
