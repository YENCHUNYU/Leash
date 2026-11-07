import Foundation
import CoreLocation

/// Turns a recorded route into smooth, heat-colored lines for the map.
/// Heat is how many separate times the walk came by a spot: once is green, four or more is red.
enum RouteDrawing {
    /// A run of the line drawn in one color.
    struct Piece {
        let coordinates: [CLLocationCoordinate2D]
        /// 0 for a single pass, up to 1 for `maxPasses` or more.
        let heat: Double
    }

    /// Points closer than this count as the same place.
    static let passRadius: Double = 15
    static let maxPasses = 4
    /// Spacing of the points passes are counted on.
    private static let spacing: Double = 4
    /// Distinct colors along the line; neighbors with the same step are drawn as one piece.
    private static let heatSteps = 12.0

    private struct Point { var x, y, heat: Double }

    /// Smooth lines per segment, each split where its color changes.
    static func pieces(for walk: Walk) -> (outlines: [[CLLocationCoordinate2D]], pieces: [Piece]) {
        guard let origin = walk.route.first else { return ([], []) }
        let metersPerDegree = 111_320.0
        let lonScale = cos(origin.latitude * .pi / 180) * metersPerDegree
        func local(_ p: RoutePoint) -> (x: Double, y: Double) {
            ((p.longitude - origin.longitude) * lonScale, (p.latitude - origin.latitude) * metersPerDegree)
        }
        func coordinate(_ p: Point) -> CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: origin.latitude + p.y / metersPerDegree,
                                   longitude: origin.longitude + p.x / lonScale)
        }

        // Round the corners per segment, then lay points every few meters so passes are counted
        // along the line itself, not just at GPS fixes that can be far apart.
        let segments = walk.segments.map { segment in
            densify(chaikin(chaikin(segment.map { let p = local($0); return Point(x: p.x, y: p.y, heat: 0) })))
        }
        let visits = passes(segments.flatMap { $0 }.map { (x: $0.x, y: $0.y) })

        var outlines: [[CLLocationCoordinate2D]] = []
        var pieces: [Piece] = []
        var offset = 0
        for segment in segments {
            var heated = segment
            for index in heated.indices {
                heated[index].heat = Double(min(visits[offset + index], maxPasses) - 1) / Double(maxPasses - 1)
            }
            offset += segment.count
            let shaded = blendHeat(heated, window: 4)
            outlines.append(shaded.map(coordinate))

            // Split into pieces of one color, each starting where the last ended so the line stays joined.
            var current: [Point] = []
            var step: Double?
            for point in shaded {
                let pointStep = (point.heat * heatSteps).rounded()
                if let step, step != pointStep, let last = current.last {
                    pieces.append(Piece(coordinates: current.map(coordinate), heat: step / heatSteps))
                    current = [last]
                }
                step = pointStep
                current.append(point)
            }
            if let step, current.count > 1 {
                pieces.append(Piece(coordinates: current.map(coordinate), heat: step / heatSteps))
            }
        }
        return (outlines, pieces)
    }

    /// For each point, how many separate visits the route made within `passRadius` of it, including its own.
    static func passes(_ positions: [(x: Double, y: Double)]) -> [Int] {
        let radius2 = passRadius * passRadius
        return positions.map { here in
            var visits = 0
            var nearby = false
            for there in positions {
                let dx = there.x - here.x, dy = there.y - here.y
                let near = dx * dx + dy * dy <= radius2
                if near && !nearby { visits += 1 }
                nearby = near
            }
            return max(visits, 1)
        }
    }

    /// Blends each point's heat with `window` neighbors each side, so colors change gradually.
    private static func blendHeat(_ points: [Point], window: Int) -> [Point] {
        guard points.count > 2 else { return points }
        return points.indices.map { index in
            let slice = points[max(0, index - window)...min(points.count - 1, index + window)]
            var point = points[index]
            point.heat = slice.reduce(0) { $0 + $1.heat } / Double(slice.count)
            return point
        }
    }

    /// Adds points along straight stretches so none are more than `spacing` apart.
    private static func densify(_ points: [Point]) -> [Point] {
        guard var previous = points.first else { return [] }
        var result = [previous]
        for point in points.dropFirst() {
            let length = hypot(point.x - previous.x, point.y - previous.y)
            let steps = Int((length / spacing).rounded(.up))
            for step in stride(from: 1, through: steps, by: 1) {
                let t = Double(step) / Double(steps)
                result.append(Point(x: previous.x + (point.x - previous.x) * t, y: previous.y + (point.y - previous.y) * t, heat: 0))
            }
            previous = point
        }
        return result
    }

    /// Chaikin corner cutting: replaces each corner with two points a quarter of the way in, rounding it off.
    private static func chaikin(_ points: [Point]) -> [Point] {
        guard points.count > 2 else { return points }
        var result = [points[0]]
        for index in 0..<(points.count - 1) {
            let a = points[index], b = points[index + 1]
            func mix(_ t: Double) -> Point {
                Point(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t, heat: a.heat + (b.heat - a.heat) * t)
            }
            result.append(mix(0.25))
            result.append(mix(0.75))
        }
        result.append(points[points.count - 1])
        return result
    }

    /// Lime green → yellow → orange → red, as 0xRRGGBB.
    static func color(heat: Double) -> UInt32 {
        let stops: [UInt32] = [0x8CD443, 0xF2D33A, 0xF39237, 0xE2453C]
        let scaled = min(max(heat, 0), 1) * Double(stops.count - 1)
        let index = min(Int(scaled), stops.count - 2)
        let t = scaled - Double(index)
        func channel(_ shift: UInt32) -> UInt32 {
            let a = Double((stops[index] >> shift) & 255), b = Double((stops[index + 1] >> shift) & 255)
            return UInt32((a + (b - a) * t).rounded()) << shift
        }
        return channel(16) | channel(8) | channel(0)
    }
}
