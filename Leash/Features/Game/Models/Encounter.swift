import Foundation

/// A dog met during a walk, or hatched from a walk egg.
struct Encounter: Identifiable, Equatable {
    let id: String
    let breed: Breed
    let fromEgg: Bool
}

enum EncounterRules {
    /// First dog after one minute, then another every eight, up to four per walk.
    static let firstAfter: TimeInterval = 60
    static let interval: TimeInterval = 8 * 60
    static let maxPerWalk = 4
    static let triesPerDog = 3

    struct Context {
        var night = false
        var morning = false
        var hot = false
        var field = false
        var outsideTaipei = false
        var unitedStates = false
    }

    /// Dogs currently around: this walk's visitors plus hatched eggs, minus any already resolved.
    static func pending(walk: Walk?, spot: Spot?, hatchedEggs: Int, game: GameState,
                        language: AppLanguage, now: Date = .now, calendar: Calendar = .current) -> [Encounter] {
        guard let walk, !walk.isIndoor else { return [] }
        var result: [Encounter] = []
        let elapsed = now.timeIntervalSince(walk.startedAt)
        let visitors = elapsed >= firstAfter ? min(maxPerWalk, 1 + Int((elapsed - firstAfter) / interval)) : 0
        let hour = calendar.component(.hour, from: walk.startedAt)
        let context = Context(night: hour >= 19 || hour < 6, morning: (5..<8).contains(hour),
                              hot: Heat.isHot(walk.startedAt, language: language, calendar: calendar),
                              field: spot?.isField ?? false,
                              outsideTaipei: spot.map { $0.region != "臺北市" } ?? false,
                              unitedStates: language == .english || spot?.country == .unitedStates)
        for index in 0..<visitors {
            let id = "\(walk.id.uuidString)#\(index)"
            result.append(Encounter(id: id, breed: breed(seed: id, context: context), fromEgg: false))
        }
        for index in 0..<hatchedEggs {
            let id = "egg#\(index)"
            result.append(Encounter(id: id, breed: breed(seed: id, context: Context(unitedStates: language == .english),
                                                         minimumRarity: .uncommon), fromEgg: true))
        }
        return result.filter { game.outcomes[$0.id] == nil }
    }

    /// Picks a rarity by weight, then a breed weighted by time of day, place and heat.
    static func breed(seed: String, context: Context, minimumRarity: Breed.Rarity = .common) -> Breed {
        var random = SeededRandom(seed)
        let rarityWeights = Breed.Rarity.allCases.map { $0.rawValue < minimumRarity.rawValue ? 0 : $0.weight }
        let rarity = Breed.Rarity(rawValue: pick(weights: rarityWeights, random.next())) ?? .common
        let pool = Breed.all.filter { $0.rarity == rarity }
        let weights = pool.map { breed -> Double in
            var weight = 1.0
            if context.night && breed.traits.contains(.dark) { weight *= 2.5 }
            if context.field && breed.traits.contains(.big) { weight *= 2.5 }
            if context.hot && breed.traits.contains(.flatFaced) { weight *= 0.25 }
            if breed.traits.contains(.taiwanese) { weight *= context.unitedStates ? 0.4 : (context.outsideTaipei ? 3 : 1) }
            if context.morning && (breed.id == "shiba" || breed.id.hasPrefix("mix")) { weight *= 1.5 }
            return weight
        }
        return pool[pick(weights: weights, random.next())]
    }

    /// Deterministic per attempt, so reopening the sheet cannot reroll a toss.
    static func befriends(_ encounter: Encounter, attempt: Int) -> Bool {
        var random = SeededRandom("\(encounter.id)/\(attempt)")
        return random.next() < encounter.breed.rarity.befriendChance
    }

    private static func pick(weights: [Double], _ roll: Double) -> Int {
        var remaining = roll * weights.reduce(0, +)
        for (index, weight) in weights.enumerated() {
            if remaining < weight { return index }
            remaining -= weight
        }
        return weights.lastIndex { $0 > 0 } ?? 0
    }
}

/// Port of the reference app's string-seeded generator (MurmurHash3-style mixing).
struct SeededRandom {
    private var state: UInt32

    init(_ seed: String) {
        let units = Array(seed.utf16)
        var hash: UInt32 = 1_779_033_703 ^ UInt32(truncatingIfNeeded: units.count)
        for unit in units {
            hash = (hash ^ UInt32(unit)) &* 3_432_918_353
            hash = hash << 13 | hash >> 19
        }
        state = hash
    }

    /// Uniform in [0, 1).
    mutating func next() -> Double {
        state = (state ^ state >> 16) &* 2_246_822_507
        state = (state ^ state >> 13) &* 3_266_489_909
        state ^= state >> 16
        return Double(state) / 4_294_967_296
    }
}
