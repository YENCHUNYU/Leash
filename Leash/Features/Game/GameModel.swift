import Foundation
import Observation

/// Game layer over walk history: progress, quests, encounters and the dog's look.
@MainActor @Observable
final class GameModel {
    enum TossResult: Equatable {
        case befriended(firstOfBreed: Bool)
        case missed(triesLeft: Int)
        case ranOff
        case noTreats
        case saveFailed
    }

    private(set) var state: GameState
    private(set) var roster: DogRoster
    let walks: WalkViewModel
    let photos: PhotoLibrary
    let spots: SpotCatalog
    private let stateFile: JSONFile<GameState>?
    private let profileFile: JSONFile<DogRoster>?
    /// Each dog's photo, named by its id, kept on this device only.
    private let dogPhotoDirectory: URL?
    /// Bumped when a dog photo changes, so views reload it.
    private(set) var dogPhotoVersion = 0

    init(walks: WalkViewModel, photos: PhotoLibrary, spots: SpotCatalog, directory: URL?) {
        self.walks = walks
        self.photos = photos
        self.spots = spots
        stateFile = directory.map { JSONFile("game.json", in: $0) }
        let profileFile = directory.map { JSONFile<DogRoster>("profile.json", in: $0) }
        self.profileFile = profileFile
        dogPhotoDirectory = directory?.appendingPathComponent("dog-photos", isDirectory: true)
        state = (try? stateFile?.load()) ?? GameState()
        roster = (try? profileFile.flatMap { try? Data(contentsOf: $0.url) }.map(DogRoster.decode)) ?? DogRoster()
        moveSingleDogPhoto(from: directory)
    }

    /// Before there could be several dogs, the one photo was "my-dog.jpg"; it belongs to the first dog.
    private func moveSingleDogPhoto(from directory: URL?) {
        guard let old = directory?.appendingPathComponent("my-dog.jpg"), FileManager.default.fileExists(atPath: old.path),
              let new = dogPhotoURL(for: roster.dogs[0].id) else { return }
        try? FileManager.default.createDirectory(at: new.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? FileManager.default.moveItem(at: old, to: new)
    }

    /// The dog that's on screen and on walks.
    var profile: DogProfile { roster.active }

    var progress: GameProgress {
        GameProgress(walks: walks.archive.completed, photos: photos.photos, customSpotCount: spots.custom.count,
                 game: state, spot: spots.spot(id:))
    }

    var dogBreed: Breed { Breed.named(profile.breedID) }
    /// The user's own dog from a photo, when it's the chosen look.
    var dogLook: DogLook? { profile.usesPhoto ? profile.photoLook : nil }

    func quests(language: AppLanguage) -> [Quest] { Quest.daily(progress, language: language) }

    func badges(language: AppLanguage) -> [Badge] {
        Badge.all(progress, walks: walks.archive.completed, customSpotCount: spots.custom.count, language: language)
    }

    func pendingEncounters(at date: Date = .now, language: AppLanguage) -> [Encounter] {
        let walk = walks.activeWalk
        return EncounterRules.pending(walk: walk, spot: spots.spot(id: walk?.spotID), hatchedEggs: progress.hatchedEggs,
                                      game: state, language: language, now: date)
    }

    func isUnlocked(_ breed: Breed) -> Bool {
        Breed.starterIDs.contains(breed.id) || (state.friends[breed.id] ?? 0) > 0
    }

    func toss(to encounter: Encounter) -> TossResult {
        guard progress.treats > 0 else { return .noTreats }
        var next = state
        let attempt = next.attempts[encounter.id] ?? 0
        let result: TossResult
        if EncounterRules.befriends(encounter, attempt: attempt) {
            next.outcomes[encounter.id] = .befriended
            next.friends[encounter.breed.id, default: 0] += 1
            result = .befriended(firstOfBreed: next.friends[encounter.breed.id] == 1)
        } else if attempt + 1 >= EncounterRules.triesPerDog {
            next.outcomes[encounter.id] = .fled
            result = .ranOff
        } else {
            next.attempts[encounter.id] = attempt + 1
            result = .missed(triesLeft: EncounterRules.triesPerDog - attempt - 1)
        }
        next.treatsSpent += 1
        return save(next) ? result : .saveFailed
    }

    @discardableResult
    func sayBye(to encounter: Encounter) -> Bool {
        var next = state
        next.outcomes[encounter.id] = .left
        return save(next)
    }

    func dogPhotoURL(for id: UUID) -> URL? {
        dogPhotoDirectory?.appendingPathComponent("\(id.uuidString).jpg")
    }

    /// Saves a smaller copy of the photo a dog's pixel look was made from.
    func saveDogPhoto(_ data: Data, for id: UUID) -> Bool {
        guard let url = dogPhotoURL(for: id), let small = DogAnalyzer.smallJPEG(data) else { return false }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try small.write(to: url, options: .atomic)
            dogPhotoVersion += 1
            return true
        } catch {
            return false
        }
    }

    /// Changes the active dog.
    @discardableResult
    func updateProfile(_ change: (inout DogProfile) -> Void) -> Bool {
        let id = profile.id
        return saveRoster { roster in
            guard let index = roster.dogs.firstIndex(where: { $0.id == id }) else { return }
            change(&roster.dogs[index])
        }
    }

    /// Adds a dog and makes it the active one. Its photo is saved too, when there is one.
    @discardableResult
    func addDog(_ dog: DogProfile, photo: Data? = nil) -> Bool {
        guard saveRoster({ $0.dogs.append(dog); $0.activeID = dog.id }) else { return false }
        if let photo { _ = saveDogPhoto(photo, for: dog.id) }
        return true
    }

    @discardableResult
    func selectDog(_ id: UUID) -> Bool {
        saveRoster { roster in if roster.dogs.contains(where: { $0.id == id }) { roster.activeID = id } }
    }

    /// Removes a dog and its photo. The last dog can't be removed.
    @discardableResult
    func removeDog(_ id: UUID) -> Bool {
        guard roster.dogs.count > 1 else { return false }
        let saved = saveRoster { roster in
            roster.dogs.removeAll { $0.id == id }
            if roster.activeID == id { roster.activeID = roster.dogs[0].id }
        }
        if saved, let url = dogPhotoURL(for: id) { try? FileManager.default.removeItem(at: url) }
        return saved
    }

    private func saveRoster(_ change: (inout DogRoster) -> Void) -> Bool {
        var next = roster
        change(&next)
        do {
            try profileFile?.save(next)
            roster = next
            return true
        } catch {
            return false
        }
    }

    /// Level-ups and hatched eggs not yet announced; recording them so each is shown once.
    func newMilestones(language: AppLanguage) -> [String] {
        let current = progress
        var messages: [String] = []
        var next = state
        if next.announcedLevel > 0 && current.level > next.announcedLevel {
            messages.append(language.text("⭐ Level \(current.level)!", "⭐ 升到 \(current.level) 級！"))
        }
        if current.hatchedEggs > next.announcedEggs {
            messages.append(language.text("🥚 Your egg hatched! Meet it on your next walk", "🥚 散步蛋孵化了！散步時會遇到牠"))
        }
        next.announcedLevel = current.level
        next.announcedEggs = current.hatchedEggs
        if next != state { save(next) }
        return messages
    }

    @discardableResult
    private func save(_ next: GameState) -> Bool {
        do {
            try stateFile?.save(next)
            state = next
            return true
        } catch {
            return false
        }
    }
}
