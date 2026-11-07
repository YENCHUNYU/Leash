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

struct RouteDrawingTests {
    /// Points every 5 m around a 100 m square, `laps` times.
    private func square(laps: Int) -> [(x: Double, y: Double)] {
        let side = (0..<20).map { Double($0) * 5 }
        let lap = side.map { ($0, 0.0) } + side.map { (100.0, $0) } + side.map { (100 - $0, 100.0) } + side.map { (0.0, 100 - $0) }
        return Array(repeating: lap, count: laps).flatMap { $0 }
    }

    @Test func singleLapIsOnePass() {
        #expect(RouteDrawing.passes(square(laps: 1)).dropFirst(5).dropLast(5).allSatisfy { $0 == 1 })
    }

    @Test func eachLapAddsAPass() {
        let passes = RouteDrawing.passes(square(laps: 3))
        #expect(passes[30] == 3)
    }

    @Test func outAndBackCountsTwiceAwayFromTheTurn() {
        let out = (0..<30).map { (x: Double($0) * 5, y: 0.0) }
        let passes = RouteDrawing.passes(out + out.reversed())
        #expect(passes[5] == 2)
    }

    @Test func colorGoesFromGreenToRed() {
        #expect(RouteDrawing.color(heat: 0) == 0x8CD443)
        #expect(RouteDrawing.color(heat: 1) == 0xE2453C)
    }

    @Test @MainActor func smoothingKeepsStartAndEnd() throws {
        let now = Date()
        var walk = Walk(startedAt: now)
        walk.route = (0..<10).map { RoutePoint(latitude: 25 + Double($0) * 0.0001 * ($0.isMultiple(of: 2) ? 1 : 1.3),
                                               longitude: 121, timestamp: now.addingTimeInterval(Double($0) * 5)) }
        let line = try #require(RouteDrawing.pieces(for: walk).outlines.first)
        #expect(abs(line[0].latitude - 25) < 1e-9)
        #expect(abs(line[line.count - 1].latitude - walk.route[9].latitude) < 1e-9)
    }
}

struct StandingStillTests {
    @Test func pausingDoesNotBreakTheRouteOrLoseDistance() throws {
        let now = Date()
        let walk = Walk(startedAt: now.addingTimeInterval(-600))
        // Last drawn a minute ago, but fixes kept arriving while standing still.
        let previous = fix(secondsAgo: 60, now: now)
        let decision = RouteFilter.evaluate(fix(north: 20, now: now), previous: previous,
                                            lastSeen: now.addingTimeInterval(-5), walk: walk, now: now)
        let meters = try #require({ if case .accept(let d) = decision { d } else { nil } }())
        #expect(abs(meters - 20) < 0.5)
    }

    @Test func gapWithNoFixesAtAllStillBreaksTheLine() {
        let now = Date()
        let walk = Walk(startedAt: now.addingTimeInterval(-600))
        let decision = RouteFilter.evaluate(fix(north: 20, now: now), previous: fix(secondsAgo: 60, now: now),
                                            lastSeen: now.addingTimeInterval(-60), walk: walk, now: now)
        #expect(decision == .accept(distance: 0))
    }

    @Test func lostGpsStillStartsANewSegment() {
        let now = Date()
        var walk = Walk(startedAt: now)
        walk.route = [
            RoutePoint(latitude: 25, longitude: 121, timestamp: now, startsSegment: true),
            RoutePoint(latitude: 25.0001, longitude: 121, timestamp: now.addingTimeInterval(90), startsSegment: false),
            RoutePoint(latitude: 25.01, longitude: 121, timestamp: now.addingTimeInterval(100), startsSegment: true),
        ]
        #expect(walk.segments.map(\.count) == [2, 1])
    }
}
