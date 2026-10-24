import Foundation

@MainActor
protocol WalkStoring {
    func load() throws -> WalkArchive
    /// Called for every accepted GPS fix, so it must stay cheap regardless of history size.
    func saveActive(_ walk: Walk?) throws
    func saveCompleted(_ walks: [Walk]) throws
}

/// The active walk and history are separate atomic files, so GPS updates never rewrite history.
/// Finishing writes history before clearing the active walk; `load` drops an active walk already
/// in history, so exiting between the two writes cannot duplicate or lose a walk.
@MainActor
final class FileWalkStore: WalkStoring {
    private let activeURL: URL
    private let completedURL: URL
    /// Single-snapshot format used before history was split out.
    private let legacyURL: URL
    private let fileManager = FileManager.default

    init(directory: URL? = nil) throws {
        let directory = try directory ?? LeashDirectory.url()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        activeURL = directory.appendingPathComponent("active-walk.json")
        completedURL = directory.appendingPathComponent("completed-walks.json")
        legacyURL = directory.appendingPathComponent("walks.json")
    }

    func load() throws -> WalkArchive {
        try migrateLegacySnapshot()
        let completed = try read([Walk].self, from: completedURL) ?? []
        var active = try read(Walk.self, from: activeURL)
        if let walk = active, completed.contains(where: { $0.id == walk.id }) { active = nil }
        return WalkArchive(active: active, completed: completed)
    }

    func saveActive(_ walk: Walk?) throws {
        if let walk {
            try JSONEncoder().encode(walk).write(to: activeURL, options: .atomic)
        } else if fileManager.fileExists(atPath: activeURL.path) {
            try fileManager.removeItem(at: activeURL)
        }
    }

    func saveCompleted(_ walks: [Walk]) throws {
        try JSONEncoder().encode(walks).write(to: completedURL, options: .atomic)
    }

    private func read<T: Decodable>(_ type: T.Type, from url: URL) throws -> T? {
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return try JSONDecoder().decode(type, from: Data(contentsOf: url))
    }

    /// History is written last, so its presence marks a finished migration.
    private func migrateLegacySnapshot() throws {
        guard fileManager.fileExists(atPath: legacyURL.path) else { return }
        if !fileManager.fileExists(atPath: completedURL.path) {
            guard let legacy = try read(WalkArchive.self, from: legacyURL) else { return }
            try saveActive(legacy.active)
            try saveCompleted(legacy.completed)
        }
        try? fileManager.removeItem(at: legacyURL)
    }
}
