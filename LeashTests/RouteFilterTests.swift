import CoreLocation
import Testing
@testable import Leash

struct RouteFilterTests {
    let now = Date()
    var walk: Walk { Walk(startedAt: now.addingTimeInterval(-600)) }

    private func distance(_ decision: RouteFilter.Decision) -> Double? {
        if case .accept(let distance) = decision { distance } else { nil }
    }

    @Test func firstFixStartsRouteWithoutDistance() {
        #expect(RouteFilter.evaluate(fix(now: now), previous: nil, walk: walk, now: now) == .accept(distance: 0))
    }

    @Test func normalWalkingStepAddsDistance() throws {
        let decision = RouteFilter.evaluate(fix(north: 10, now: now), previous: fix(secondsAgo: 5, now: now), walk: walk, now: now)
        let meters = try #require(distance(decision))
        #expect(abs(meters - 10) < 0.5)
    }

    @Test func rejectsInaccurateStaleAndPreWalkFixes() {
        #expect(RouteFilter.evaluate(fix(accuracy: 80, now: now), previous: nil, walk: walk, now: now) == .inaccurate)
        #expect(RouteFilter.evaluate(fix(accuracy: -1, now: now), previous: nil, walk: walk, now: now) == .inaccurate)
        #expect(RouteFilter.evaluate(fix(secondsAgo: 60, now: now), previous: nil, walk: walk, now: now) == .inaccurate)
        let justStarted = Walk(startedAt: now)
        #expect(RouteFilter.evaluate(fix(secondsAgo: 5, now: now), previous: nil, walk: justStarted, now: now) == .inaccurate)
    }

    @Test func rejectsImplausibleJump() {
        let decision = RouteFilter.evaluate(fix(north: 500, now: now), previous: fix(secondsAgo: 5, now: now), walk: walk, now: now)
        #expect(decision == .jump)
    }

    @Test func skipsJitterAndOutOfOrderFixes() {
        #expect(RouteFilter.evaluate(fix(north: 2, now: now), previous: fix(secondsAgo: 5, now: now), walk: walk, now: now) == .skip)

        var tracked = walk
        tracked.route = [RoutePoint(latitude: 25, longitude: 121, timestamp: now)]
        #expect(RouteFilter.evaluate(fix(secondsAgo: 1, now: now), previous: nil, walk: tracked, now: now) == .skip)
    }

    @Test func longGapStartsNewSegmentWithoutBridging() {
        let decision = RouteFilter.evaluate(fix(north: 400, now: now), previous: fix(secondsAgo: 120, now: now), walk: walk, now: now)
        #expect(decision == .accept(distance: 0))

        var tracked = walk
        tracked.route = [0, 10, 20, 100, 110].map {
            RoutePoint(latitude: 25, longitude: 121, timestamp: now.addingTimeInterval($0))
        }
        #expect(tracked.segments.map(\.count) == [3, 2])
    }
}
