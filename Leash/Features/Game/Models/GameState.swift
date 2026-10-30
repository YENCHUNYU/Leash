import Foundation

/// Encounter results and spending. Everything else in progress is derived from history.
struct GameState: Codable, Equatable {
    enum Outcome: String, Codable { case befriended, fled, left }

    /// Keyed by encounter id.
    var outcomes: [String: Outcome] = [:]
    /// Missed treats per encounter; three misses and the dog runs off.
    var attempts: [String: Int] = [:]
    var treatsSpent = 0
    /// Befriended count per breed id.
    var friends: [String: Int] = [:]
    /// Last values announced, so level-ups and hatches are celebrated once.
    var announcedLevel = 0
    var announcedEggs = 0

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        outcomes = try container.decodeIfPresent([String: Outcome].self, forKey: .outcomes) ?? [:]
        attempts = try container.decodeIfPresent([String: Int].self, forKey: .attempts) ?? [:]
        treatsSpent = try container.decodeIfPresent(Int.self, forKey: .treatsSpent) ?? 0
        friends = try container.decodeIfPresent([String: Int].self, forKey: .friends) ?? [:]
        announcedLevel = try container.decodeIfPresent(Int.self, forKey: .announcedLevel) ?? 0
        announcedEggs = try container.decodeIfPresent(Int.self, forKey: .announcedEggs) ?? 0
    }
}

/// One of the user's dogs: its name, look (a breed coat or read from a photo) and collar.
struct DogProfile: Codable, Equatable, Identifiable {
    var id = UUID()
    var name = ""
    var breedID = "mixy"
    /// Collar color (stored as "scarf" from when it was a bandana).
    var scarf: UInt32 = Self.scarves[0]
    /// The user's own dog read from a photo, and whether it's the current look instead of `breedID`.
    var photoLook: DogLook?
    var usesPhoto = false
    /// What the dog is wearing, if anything.
    var accessory: Accessory?
    /// How much it moves around on screen.
    var personality = Personality.balanced

    static let scarves: [UInt32] = [0xE2574C, 0x4E8FD8, 0xF4B63F, 0x5BAF6A, 0xB06FD0, 0xF28CA0, 0x2B2533, 0xFFFFFF, 0x3FB8B0, 0xF07B3F]
    /// Three colors to start, one more every two levels.
    static func unlockedScarves(level: Int) -> Int { min(scarves.count, 3 + level / 2) }

    func displayName(in language: AppLanguage) -> String {
        name.isEmpty ? language.text("My dog", "我的狗狗") : name
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        breedID = try container.decodeIfPresent(String.self, forKey: .breedID) ?? "mixy"
        scarf = try container.decodeIfPresent(UInt32.self, forKey: .scarf) ?? Self.scarves[0]
        photoLook = try? container.decodeIfPresent(DogLook.self, forKey: .photoLook)
        accessory = try? container.decodeIfPresent(Accessory.self, forKey: .accessory)
        personality = (try? container.decodeIfPresent(Personality.self, forKey: .personality)) ?? .balanced
        usesPhoto = (try? container.decodeIfPresent(Bool.self, forKey: .usesPhoto)) ?? false
    }
}

/// How a dog behaves on screen: calm dogs mostly stay put, active ones pace and run.
nonisolated enum Personality: String, Codable, CaseIterable, Identifiable, Sendable {
    case calm, balanced, active

    var id: String { rawValue }

    func name(in language: AppLanguage) -> String {
        switch self {
        case .calm: language.text("Calm", "安靜")
        case .balanced: language.text("Easygoing", "普通")
        case .active: language.text("Active", "好動")
        }
    }

    /// Seconds to rest between moves.
    func pause(outdoors: Bool) -> ClosedRange<Double> {
        switch self {
        case .calm: outdoors ? 4...8 : 6...12
        case .balanced: outdoors ? 1.2...3 : 1.5...3.5
        case .active: outdoors ? 0.1...0.5 : 0.3...1
        }
    }

    /// Seconds per move; active dogs run, faster still outside.
    func moveDuration(outdoors: Bool) -> Double {
        switch self {
        case .calm: 3
        case .balanced: 2.2
        case .active: outdoors ? 0.8 : 1.1
        }
    }

    /// Furthest one move goes, as a fraction of the scene width.
    var reach: Double {
        switch self {
        case .calm: 0.15
        case .balanced: 0.4
        case .active: 0.7
        }
    }
}

extension DogProfile {
    var breed: Breed { Breed.named(breedID) }
    /// The look read from a photo, when it's chosen over the breed coat.
    var look: DogLook? { usesPhoto ? photoLook : nil }
}

/// All of the user's dogs, which one is the main dog, and who goes on walks.
struct DogRoster: Codable, Equatable {
    var dogs: [DogProfile]
    var activeID: UUID
    /// The dogs last chosen to go on walks; nil until the user picks.
    var walkingIDs: [UUID]?

    init(dogs: [DogProfile] = [DogProfile()]) {
        self.dogs = dogs.isEmpty ? [DogProfile()] : dogs
        activeID = self.dogs[0].id
    }

    var active: DogProfile { dogs.first { $0.id == activeID } ?? dogs[0] }

    /// Who goes on the next walk: the last choice, or every dog.
    var walking: [DogProfile] {
        let chosen = dogs.filter { walkingIDs?.contains($0.id) ?? true }
        return chosen.isEmpty ? [active] : chosen
    }

    /// Reads the roster file, or a file from before there could be several dogs.
    static func decode(_ data: Data) throws -> DogRoster {
        if let roster = try? JSONDecoder().decode(DogRoster.self, from: data), !roster.dogs.isEmpty { return roster }
        return DogRoster(dogs: [try JSONDecoder().decode(DogProfile.self, from: data)])
    }
}

struct Photo: Codable, Identifiable, Equatable {
    var id = UUID()
    var takenAt = Date()
    var walkID: UUID?
    var spotID: String?
}

/// Summer midday pavement can burn paws. Seasons follow the reference app's regions.
enum Heat {
    static func isHot(_ date: Date, language: AppLanguage, calendar: Calendar = .current) -> Bool {
        let hour = calendar.component(.hour, from: date), month = calendar.component(.month, from: date)
        return language == .english
            ? (6...9).contains(month) && (11..<16).contains(hour)
            : (5...10).contains(month) && (10..<16).contains(hour)
    }
}
