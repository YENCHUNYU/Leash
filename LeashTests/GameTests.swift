import Foundation
import UIKit
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
        let park = Spot(id: "p1", name: "Park", country: .taiwan, region: "新北市", subregion: "板橋區", address: "",
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

    @Test func savesASmallerCopyOfTheDogPhoto() throws {
        let (game, _) = try makeGame()
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 3000, height: 2000))
        let big = renderer.jpegData(withCompressionQuality: 0.9) { context in
            UIColor.white.setFill(); context.fill(CGRect(x: 0, y: 0, width: 3000, height: 2000))
        }
        #expect(game.saveDogPhoto(big, for: game.profile.id))
        #expect(game.dogPhotoVersion == 1)
        let url = try #require(game.dogPhotoURL(for: game.profile.id))
        let saved = try #require(UIImage(contentsOfFile: url.path))
        #expect(max(saved.size.width, saved.size.height) * saved.scale <= 1024)
    }

    @Test func eachDogKeepsItsOwnNameAndLook() throws {
        let (game, _) = try makeGame()
        game.updateProfile { $0.name = "Mochi"; $0.breedID = "shiba" }
        var kuro = DogProfile()
        kuro.name = "Kuro"
        kuro.photoLook = DogLook(ears: .floppy, coat: 0x1A1A1A, earColor: 0x1A1A1A, muzzle: 0xFFFFFF, chest: 0xFFFFFF, paws: 0x1A1A1A)
        kuro.usesPhoto = true
        #expect(game.addDog(kuro))
        #expect(game.profile.name == "Kuro")          // a new dog becomes the one on screen
        #expect(game.dogLook?.coat == 0x1A1A1A)
        game.updateProfile { $0.scarf = 0x4E8FD8 }

        let mochi = try #require(game.roster.dogs.first { $0.name == "Mochi" })
        #expect(game.selectDog(mochi.id))
        #expect(game.profile.breedID == "shiba")
        #expect(game.dogLook == nil)
        #expect(game.profile.scarf != 0x4E8FD8)       // Kuro's collar stayed with Kuro

        let reloaded = GameModel(walks: WalkViewModel(store: FakeWalkStore(), location: FakeLocation()),
                                 photos: try PhotoLibrary(directory: directory), spots: SpotCatalog(directory: directory), directory: directory)
        #expect(reloaded.roster.dogs.map(\.name) == ["Mochi", "Kuro"])
        #expect(reloaded.profile.name == "Mochi")
    }

    @Test func eachDogWearsItsOwnDecoration() throws {
        let (game, _) = try makeGame()
        let first = game.profile.id
        game.updateProfile { $0.accessory = .santaHat }
        #expect(game.addDog(DogProfile()))
        #expect(game.profile.accessory == nil)
        game.updateProfile { $0.accessory = .pumpkin }
        #expect(game.selectDog(first))
        #expect(game.profile.accessory == .santaHat)
    }

    @Test func removingADogDeletesItsPhotoButKeepsTheLastDog() throws {
        let (game, _) = try makeGame()
        let first = game.profile.id
        #expect(!game.removeDog(first))               // the only dog stays
        var second = DogProfile()
        second.name = "Kuro"
        let photo = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10)).jpegData(withCompressionQuality: 0.9) { _ in }
        #expect(game.addDog(second, photo: photo))
        let url = try #require(game.dogPhotoURL(for: second.id))
        #expect(FileManager.default.fileExists(atPath: url.path))
        #expect(game.removeDog(second.id))
        #expect(!FileManager.default.fileExists(atPath: url.path))
        #expect(game.profile.id == first)
    }

    @Test func oldSingleDogFileBecomesTheFirstDog() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(#"{"name":"Mochi","breedID":"corgi","scarf":1}"#.utf8).write(to: directory.appendingPathComponent("profile.json"))
        try Data([0xFF, 0xD8]).write(to: directory.appendingPathComponent("my-dog.jpg"))
        let (game, _) = try makeGame()
        #expect(game.roster.dogs.count == 1)
        #expect(game.profile.name == "Mochi")
        let moved = try #require(game.dogPhotoURL(for: game.profile.id))
        #expect(FileManager.default.fileExists(atPath: moved.path))
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

struct DogLookTests {
    /// A 40×40 "dog": tan body, cream lower half on the left (snout side), dark ears, transparent border.
    private func bitmap() -> DogAnalyzer.Bitmap {
        let side = 40
        var bytes = [UInt8](repeating: 0, count: side * side * 4)
        for y in 4..<36 {
            for x in 4..<36 {
                let color: [UInt8] = y < 10 ? [60, 40, 30] : (y > 22 && x < 20 ? [245, 235, 215] : [200, 140, 70])
                bytes.replaceSubrange((y * side + x) * 4..<(y * side + x) * 4 + 4, with: color + [255])
            }
        }
        return DogAnalyzer.Bitmap(width: side, height: side, bytes: bytes)
    }

    /// Landmarks in Vision's normalized, bottom-left coordinates.
    private func marks(earTipAboveBase: Bool) -> DogAnalyzer.Landmarks {
        var marks = DogAnalyzer.Landmarks()
        marks.nose = CGPoint(x: 0.2, y: 0.3)
        marks.eyes = [CGPoint(x: 0.3, y: 0.55)]
        let base = CGPoint(x: 0.5, y: 0.82)
        let tip = CGPoint(x: 0.5, y: earTipAboveBase ? 0.88 : 0.76)
        marks.ears = [(top: tip, middle: CGPoint(x: 0.5, y: 0.85), bottom: base)]
        return marks
    }

    @Test func earTipAboveBaseMeansPointyEars() throws {
        #expect(try DogAnalyzer.look(bitmap(), landmarks: marks(earTipAboveBase: true)).ears == .pricked)
        #expect(try DogAnalyzer.look(bitmap(), landmarks: marks(earTipAboveBase: false)).ears == .floppy)
    }

    @Test func readsCoatEarAndMuzzleColors() throws {
        let look = try DogAnalyzer.look(bitmap(), landmarks: marks(earTipAboveBase: true))
        func luminance(_ hex: UInt32) -> Double {
            0.299 * Double(hex >> 16 & 255) + 0.587 * Double(hex >> 8 & 255) + 0.114 * Double(hex & 255)
        }
        #expect(luminance(look.earColor) < 80)                       // dark ears
        #expect(luminance(look.muzzle) > luminance(look.coat) + 30)   // cream snout on a tan dog
        #expect(look.photoColors.count >= 2)
    }

    @Test func findsRedCollarAtTheNeck() throws {
        var image = bitmap()
        // A red band across rows 26–28, where the neck landmark below points.
        for y in 26...28 { for x in 20..<36 { image.bytes.replaceSubrange((y * 40 + x) * 4..<(y * 40 + x) * 4 + 3, with: [200, 30, 40]) } }
        var marks = marks(earTipAboveBase: true)
        marks.nose = CGPoint(x: 0.15, y: 0.6)
        marks.eyes = [CGPoint(x: 0.6, y: 0.7)]
        marks.neck = CGPoint(x: 0.7, y: 0.32)
        let collar = try #require(DogAnalyzer.look(image, landmarks: marks).collar)
        #expect(collar >> 16 & 255 > 150 && collar >> 8 & 255 < 80)   // red
        #expect(try DogAnalyzer.look(bitmap(), landmarks: marks).collar == nil)
    }

    /// A dog of one color, half in light and half in shade (a quarter of it in deep shade).
    private func shadedDog(lit: [UInt8], shade: Double) -> DogAnalyzer.Bitmap {
        let side = 40
        var bytes = [UInt8](repeating: 0, count: side * side * 4)
        for y in 4..<36 {
            for x in 4..<36 {
                let factor = x < 20 ? 1 : (y < 20 ? shade : shade * 0.75)
                let color = lit.map { UInt8(Double($0) * factor) }
                bytes.replaceSubrange((y * side + x) * 4..<(y * side + x) * 4 + 4, with: color + [255])
            }
        }
        return DogAnalyzer.Bitmap(width: side, height: side, bytes: bytes)
    }

    @Test func whiteDogInShadeIsStillWhite() throws {
        let look = try DogAnalyzer.look(shadedDog(lit: [235, 235, 238], shade: 0.7), landmarks: nil)
        #expect(look.coat >> 16 & 255 > 225 && look.coat & 255 > 225)
    }

    @Test func grayDogStaysGray() throws {
        let look = try DogAnalyzer.look(shadedDog(lit: [150, 150, 152], shade: 0.8), landmarks: nil)
        #expect(look.coat >> 16 & 255 < 170)
    }

    @Test func emptyPhotoHasNoDog() {
        let empty = DogAnalyzer.Bitmap(width: 20, height: 20, bytes: [UInt8](repeating: 0, count: 20 * 20 * 4))
        #expect(throws: DogAnalyzer.Failure.self) { try DogAnalyzer.look(empty, landmarks: nil) }
    }

    @Test func spriteUsesLookColors() {
        let look = DogLook(ears: .pricked, coat: 0xC08040, earColor: 0x302020, muzzle: 0xFFF0E0, chest: 0xFFFFFF, paws: 0x101010)
        let pixels = DogSprite.pixels(look: look, scarf: 0xE2574C)
        func color(_ x: Int, _ y: Int) -> UInt32? { pixels.first { $0.x == x && $0.y == y }?.color }
        #expect(color(2, 2) == 0x302020)    // ear flap
        #expect(color(5, 8) == 0xFFF0E0)    // muzzle
        #expect(color(7, 13) == 0xFFFFFF)   // chest
        #expect(color(5, 11) == 0xE2574C)   // collar
        #expect(color(7, 12) == DogSprite.tag)
        #expect(color(3, 14) == 0x101010)   // paw
        #expect(color(6, 5) == 0xC08040)    // forehead
    }

    @Test func decorationsStayInsideTheSprite() {
        for accessory in Accessory.allCases {
            for ears in DogLook.Ears.allCases {
                let pixels = DogSprite.pixels(for: accessory, ears: ears)
                #expect(!pixels.isEmpty)
                #expect(pixels.allSatisfy { (0..<16).contains($0.x) && (0..<16).contains($0.y) })
            }
        }
    }

    @Test func oldProfilesDecodeWithoutPhotoLook() throws {
        let profile = try JSONDecoder().decode(DogProfile.self, from: Data(#"{"name":"Mochi","breedID":"corgi","scarf":1}"#.utf8))
        #expect(profile.photoLook == nil)
        #expect(profile.usesPhoto == false)
    }
}
