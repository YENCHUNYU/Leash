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

    func duration(at date: Date) -> TimeInterval {
        max(0, (endedAt ?? date).timeIntervalSince(startedAt))
    }

    func count(of kind: WalkEvent.Kind) -> Int {
        events.lazy.filter { $0.kind == kind }.count
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

struct WalkEvent: Codable, Identifiable, Equatable {
    enum Kind: String, Codable { case pee, poop }
    var id = UUID()
    let kind: Kind
    var timestamp = Date()
}

struct WalkArchive: Codable, Equatable {
    var active: Walk?
    var completed: [Walk] = []
}
