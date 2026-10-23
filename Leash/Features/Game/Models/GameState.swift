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

struct DogProfile: Codable, Equatable {
    var name = ""
    var breedID = "mixy"
    var scarf: UInt32 = Self.scarves[0]

    static let scarves: [UInt32] = [0xE2574C, 0x4E8FD8, 0xF4B63F, 0x5BAF6A, 0xB06FD0, 0xF28CA0, 0x2B2533, 0xFFFFFF, 0x3FB8B0, 0xF07B3F]
    /// Three colors to start, one more every two levels.
    static func unlockedScarves(level: Int) -> Int { min(scarves.count, 3 + level / 2) }

    func displayName(in language: AppLanguage) -> String {
        name.isEmpty ? language.text("My dog", "我的狗狗") : name
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        breedID = try container.decodeIfPresent(String.self, forKey: .breedID) ?? "mixy"
        scarf = try container.decodeIfPresent(UInt32.self, forKey: .scarf) ?? Self.scarves[0]
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
