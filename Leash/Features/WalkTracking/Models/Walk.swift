import Foundation
import CoreLocation

struct RoutePoint: Codable, Identifiable, Equatable {
    var id = UUID()
    let latitude: Double
    let longitude: Double
    let timestamp: Date

    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
}

struct Walk: Codable, Identifiable, Equatable {
    var id = UUID()
    var startedAt = Date()
    var endedAt: Date?
    var distanceMeters: Double = 0
    var route: [RoutePoint] = []
    var events: [WalkEvent] = []
    var spotID: String?
    var photoIDs: [UUID] = []
    /// Set for indoor-play quest entries, which have no route.
    var indoorActivity: String?
    /// The dogs that came along. Empty on walks from before there could be several dogs.
    var dogIDs: [UUID] = []
    /// The user's own words about the walk.
    var note: String?

    var isIndoor: Bool { indoorActivity != nil }

    func duration(at date: Date) -> TimeInterval {
        max(0, (endedAt ?? date).timeIntervalSince(startedAt))
    }

    /// Whole minutes, at least one, as used for game progress.
    func minutes(at date: Date = .now) -> Int {
        max(1, Int((duration(at: date) / 60).rounded()))
    }

    func count(of kind: WalkEvent.Kind) -> Int {
        events.lazy.filter { $0.kind == kind }.count
    }

    func count(of kind: WalkEvent.Kind, dog: UUID) -> Int {
        events.lazy.filter { $0.kind == kind && $0.dogID == dog }.count
    }

    /// Sets how many of `kind` were logged, for one dog or (with nil) in total. New events are timed at the end of the walk.
    mutating func setCount(of kind: WalkEvent.Kind, dog: UUID? = nil, to target: Int) {
        let matches = { (event: WalkEvent) in event.kind == kind && (dog == nil || event.dogID == dog) }
        var current = events.filter(matches).count
        while current > target, let index = events.lastIndex(where: matches) {
            events.remove(at: index)
            current -= 1
        }
        while current < target {
            events.append(WalkEvent(kind: kind, timestamp: endedAt ?? startedAt, dogID: dog))
            current += 1
        }
    }

    /// Route split at the same gaps RouteFilter excludes from distance.
    var segments: [[RoutePoint]] {
        var result: [[RoutePoint]] = []
        var previous: Date?
        for point in route {
            if let previous, point.timestamp.timeIntervalSince(previous) <= RouteFilter.maxSegmentGap {
                result[result.count - 1].append(point)
            } else {
                result.append([point])
            }
            previous = point.timestamp
        }
        return result
    }
}

extension Walk {
    private enum CodingKeys: String, CodingKey {
        case id, startedAt, endedAt, distanceMeters, route, events, spotID, photoIDs, indoorActivity, dogIDs, note
    }

    /// Tolerates fields added after a walk was saved.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        endedAt = try container.decodeIfPresent(Date.self, forKey: .endedAt)
        distanceMeters = try container.decodeIfPresent(Double.self, forKey: .distanceMeters) ?? 0
        route = try container.decodeIfPresent([RoutePoint].self, forKey: .route) ?? []
        events = try container.decodeIfPresent([WalkEvent].self, forKey: .events) ?? []
        spotID = try container.decodeIfPresent(String.self, forKey: .spotID)
        photoIDs = try container.decodeIfPresent([UUID].self, forKey: .photoIDs) ?? []
        indoorActivity = try container.decodeIfPresent(String.self, forKey: .indoorActivity)
        dogIDs = try container.decodeIfPresent([UUID].self, forKey: .dogIDs) ?? []
        note = try container.decodeIfPresent(String.self, forKey: .note)
    }
}

struct WalkEvent: Codable, Identifiable, Equatable {
    enum Kind: String, Codable { case pee, poop }
    var id = UUID()
    let kind: Kind
    var timestamp = Date()
    /// Which dog, when several were on the walk.
    var dogID: UUID?
}

struct WalkArchive: Codable, Equatable {
    var active: Walk?
    var completed: [Walk] = []
}
