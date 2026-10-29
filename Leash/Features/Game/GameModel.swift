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
    private(set) var profile: DogProfile
    let walks: WalkViewModel
    let photos: PhotoLibrary
    let spots: SpotCatalog
    private let stateFile: JSONFile<GameState>?
    private let profileFile: JSONFile<DogProfile>?

    init(walks: WalkViewModel, photos: PhotoLibrary, spots: SpotCatalog, directory: URL?) {
        self.walks = walks
        self.photos = photos
        self.spots = spots
        stateFile = directory.map { JSONFile("game.json", in: $0) }
        profileFile = directory.map { JSONFile("profile.json", in: $0) }
        state = (try? stateFile?.load()) ?? GameState()
        profile = (try? profileFile?.load()) ?? DogProfile()
    }

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

    @discardableResult
    func updateProfile(_ change: (inout DogProfile) -> Void) -> Bool {
        var next = profile
        change(&next)
        do {
            try profileFile?.save(next)
            profile = next
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
