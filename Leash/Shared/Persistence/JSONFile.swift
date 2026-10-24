import Foundation

enum LeashDirectory {
    /// Application Support/Leash, created on first use.
    static func url() throws -> URL {
        let directory = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        ).appendingPathComponent("Leash", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

/// One Codable value stored as an atomic JSON file.
struct JSONFile<Value: Codable> {
    let url: URL

    init(_ name: String, in directory: URL) {
        url = directory.appendingPathComponent(name)
    }

    /// Nil when the file does not exist yet; throws when it exists but cannot be read.
    func load() throws -> Value? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try JSONDecoder().decode(Value.self, from: Data(contentsOf: url))
    }

    func save(_ value: Value) throws {
        try JSONEncoder().encode(value).write(to: url, options: .atomic)
    }
}
