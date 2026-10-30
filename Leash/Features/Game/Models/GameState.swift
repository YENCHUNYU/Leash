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
        usesPhoto = (try? container.decodeIfPresent(Bool.self, forKey: .usesPhoto)) ?? false
    }
}

/// All of the user's dogs, and which one is out on screen and on walks.
struct DogRoster: Codable, Equatable {
    var dogs: [DogProfile]
    var activeID: UUID

    init(dogs: [DogProfile] = [DogProfile()]) {
        self.dogs = dogs.isEmpty ? [DogProfile()] : dogs
        activeID = self.dogs[0].id
    }

    var active: DogProfile { dogs.first { $0.id == activeID } ?? dogs[0] }

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
