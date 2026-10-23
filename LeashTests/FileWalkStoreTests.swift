import Foundation
import Testing
@testable import Leash

struct FileWalkStoreTests {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)

    @Test func emptyDirectoryLoadsEmptyArchive() throws {
        #expect(try FileWalkStore(directory: directory).load() == WalkArchive())
    }

    @Test func roundTripsActiveAndCompletedWalks() throws {
        let store = try FileWalkStore(directory: directory)
        let done = Walk(endedAt: .now, events: [WalkEvent(kind: .poop)])
        let active = Walk(route: [RoutePoint(latitude: 1, longitude: 2, timestamp: .now)])
        try store.saveCompleted([done])
        try store.saveActive(active)
        #expect(try FileWalkStore(directory: directory).load() == WalkArchive(active: active, completed: [done]))

        try store.saveActive(nil)
        #expect(try store.load().active == nil)
    }

    @Test func activeWalkAlreadyInHistoryIsDropped() throws {
        // Simulates exiting after history was written but before the active walk was cleared.
        let store = try FileWalkStore(directory: directory)
        var walk = Walk()
        try store.saveActive(walk)
        walk.endedAt = .now
        try store.saveCompleted([walk])
        #expect(try store.load() == WalkArchive(active: nil, completed: [walk]))
    }

    @Test func migratesLegacySnapshot() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let legacy = WalkArchive(active: Walk(), completed: [Walk(endedAt: .now), Walk(endedAt: .now)])
        let legacyURL = directory.appendingPathComponent("walks.json")
        try JSONEncoder().encode(legacy).write(to: legacyURL)

        #expect(try FileWalkStore(directory: directory).load() == legacy)
        #expect(!FileManager.default.fileExists(atPath: legacyURL.path))
        #expect(try FileWalkStore(directory: directory).load() == legacy)
    }

    @Test func corruptHistoryThrowsAndIsPreserved() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("completed-walks.json")
        let garbage = Data("not json".utf8)
        try garbage.write(to: url)

        #expect(throws: (any Error).self) { try FileWalkStore(directory: directory).load() }
        #expect(try Data(contentsOf: url) == garbage)
    }
}
