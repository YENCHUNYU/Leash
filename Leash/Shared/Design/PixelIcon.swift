import SwiftUI

/// Pixel glyphs translated from the HTML reference, drawn as filled polygons on a grid.
struct PixelIcon: View {
    enum Glyph { case diary, quest, dex, album, map, poop, drop, cam, home, pin, lock, coat, scarf, bone, sun, egg }
    let glyph: Glyph

    var body: some View {
        let art = glyph.art
        Canvas { context, size in
            let cell = CGSize(width: size.width / art.columns, height: size.height / art.rows)
            for layer in art.layers {
                var path = Path()
                for polygon in layer.polygons {
                    path.addLines(stride(from: 0, to: polygon.count, by: 2).map {
                        CGPoint(x: polygon[$0] * cell.width, y: polygon[$0 + 1] * cell.height)
                    })
                    path.closeSubpath()
                }
                context.fill(path, with: .color(Color(leashHex: layer.color).opacity(layer.opacity)))
            }
        }
        .aspectRatio(art.columns / art.rows, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

private struct Art {
    let columns: Double
    let rows: Double
    let layers: [Layer]
}

private struct Layer {
    let color: UInt32
    /// Each polygon is flattened x, y vertex pairs in grid units.
    let polygons: [[Double]]
    let opacity: Double
    init(_ color: UInt32, _ polygons: [[Double]], opacity: Double = 1) {
        self.color = color; self.polygons = polygons; self.opacity = opacity
    }
}

private extension PixelIcon.Glyph {
    var art: Art {
        switch self {
        case .diary: Art(columns: 12, rows: 12, layers: [
            Layer(0xF6E7C8, [[2,1, 9,1, 9,2, 10,2, 10,11, 2,11]]),
            Layer(0x2B2533, [[2,1, 3,1, 3,11, 2,11], [2,1, 9,1, 9,2, 2,2], [9,2, 10,2, 10,11, 9,11], [2,10, 10,10, 10,11, 2,11]]),
            Layer(0xB39C78, [[4,4, 8,4, 8,5, 4,5], [4,6, 8,6, 8,7, 4,7], [4,8, 7,8, 7,9, 4,9]]),
            Layer(0xE2574C, [[3,1, 4,1, 4,11, 3,11]]),
        ])
        case .quest: Art(columns: 12, rows: 12, layers: [
            Layer(0xF4B63F, [[3,1, 9,1, 9,2, 10,2, 10,4, 9,4, 9,5, 8,5, 8,6, 7,6, 7,8, 8,8, 8,9, 9,9, 9,11, 3,11, 3,9, 4,9, 4,8, 5,8, 5,6, 4,6, 4,5, 3,5, 3,4, 2,4, 2,2, 3,2]]),
            Layer(0x2B2533, [[3,1, 9,1, 9,2, 3,2], [2,2, 3,2, 3,4, 2,4], [9,2, 10,2, 10,4, 9,4], [3,10, 9,10, 9,11, 3,11]]),
            Layer(0xFFFFFF, [[5,3, 7,3, 7,4, 5,4]]),
        ])
        case .dex: Art(columns: 12, rows: 12, layers: [
            Layer(0x4E8FD8, [[2,1, 10,1, 10,11, 2,11]]),
            Layer(0x2B2533, [[2,1, 10,1, 10,2, 2,2], [2,10, 10,10, 10,11, 2,11], [2,1, 3,1, 3,11, 2,11], [9,1, 10,1, 10,11, 9,11]]),
            Layer(0xFFFFFF, [[4,4, 5,4, 5,5, 4,5], [7,4, 8,4, 8,5, 7,5], [5,3, 7,3, 7,4, 5,4], [5,6, 7,6, 7,8, 5,8], [4,6, 5,6, 5,7, 4,7], [7,6, 8,6, 8,7, 7,7]]),
        ])
        case .album: Art(columns: 12, rows: 12, layers: [
            Layer(0xBDE3F6, [[1,2, 11,2, 11,10, 1,10]]),
            Layer(0x7FBF6A, [[1,7, 4,7, 4,6, 6,6, 6,7, 7,7, 7,5, 9,5, 9,6, 11,6, 11,10, 1,10]]),
            Layer(0xF4B63F, [[8,3, 10,3, 10,5, 8,5]]),
            Layer(0x2B2533, [[1,2, 11,2, 11,3, 1,3], [1,9, 11,9, 11,10, 1,10], [1,2, 2,2, 2,10, 1,10], [10,2, 11,2, 11,10, 10,10]]),
        ])
        case .map: Art(columns: 12, rows: 12, layers: [
            Layer(0xE2574C, [[4,1, 8,1, 8,2, 9,2, 9,6, 8,6, 8,8, 7,8, 7,10, 5,10, 5,8, 4,8, 4,6, 3,6, 3,2, 4,2]]),
            Layer(0xFFFFFF, [[5,3, 7,3, 7,5, 5,5]]),
            Layer(0x2B2533, [[4,1, 8,1, 8,2, 4,2], [3,2, 4,2, 4,6, 3,6], [8,2, 9,2, 9,6, 8,6], [4,6, 5,6, 5,8, 4,8], [7,6, 8,6, 8,8, 7,8], [5,8, 6,8, 6,10, 5,10], [6,8, 7,8, 7,10, 6,10]]),
        ])
        case .poop: Art(columns: 10, rows: 10, layers: [
            Layer(0x9B6A43, [[4,1, 6,1, 6,2, 7,2, 7,4, 8,4, 8,6, 9,6, 9,9, 1,9, 1,6, 2,6, 2,4, 3,4, 3,2, 4,2]]),
            Layer(0xFFFFFF, [[3,6, 4,6, 4,7, 3,7], [6,6, 7,6, 7,7, 6,7]]),
            Layer(0x2B2533, [[4,7, 6,7, 6,8, 4,8]]),
        ])
        case .drop: Art(columns: 10, rows: 10, layers: [
            Layer(0xF3D65A, [[4,1, 6,1, 6,3, 7,3, 7,5, 8,5, 8,8, 7,8, 7,9, 3,9, 3,8, 2,8, 2,5, 3,5, 3,3, 4,3]]),
            Layer(0xFFFFFF, [[4,4, 5,4, 5,6, 4,6]]),
        ])
        case .cam: Art(columns: 10, rows: 10, layers: [
            Layer(0xFFFFFF, [[1,3, 3,3, 3,2, 7,2, 7,3, 9,3, 9,9, 1,9]]),
            Layer(0x2B2533, [[4,4, 6,4, 6,5, 7,5, 7,7, 6,7, 6,8, 4,8, 4,7, 3,7, 3,5, 4,5]]),
            Layer(0xBDE3F6, [[4,5, 5,5, 5,6, 4,6]]),
        ])
        case .home: Art(columns: 10, rows: 10, layers: [
            Layer(0x2B2533, [[4,1, 6,1, 6,2, 7,2, 7,3, 8,3, 8,4, 9,4, 9,5, 8,5, 8,9, 2,9, 2,5, 1,5, 1,4, 2,4, 2,3, 3,3, 3,2, 4,2]]),
            Layer(0xF4B63F, [[4,6, 6,6, 6,9, 4,9]]),
        ])
        case .pin: Art(columns: 10, rows: 10, layers: [
            Layer(0xFFFFFF, [[3,1, 7,1, 7,2, 8,2, 8,5, 7,5, 7,7, 6,7, 6,9, 4,9, 4,7, 3,7, 3,5, 2,5, 2,2, 3,2]]),
            Layer(0xE2574C, [[4,3, 6,3, 6,5, 4,5]]),
        ])
        case .lock: Art(columns: 8, rows: 8, layers: [
            Layer(0x4A4458, [[2,0, 6,0, 6,1, 7,1, 7,3, 8,3, 8,8, 0,8, 0,3, 1,3, 1,1, 2,1], [3,1, 3,3, 5,3, 5,1]]),
        ])
        case .coat: Art(columns: 10, rows: 10, layers: [
            Layer(0xD9A35B, [[1,1, 3,1, 3,2, 7,2, 7,1, 9,1, 9,5, 10,5, 10,8, 8,8, 8,9, 2,9, 2,8, 0,8, 0,5, 1,5]]),
            Layer(0x2B2533, [[3,4, 4,4, 4,5, 3,5], [6,4, 7,4, 7,5, 6,5], [4,6, 6,6, 6,7, 4,7]]),
        ])
        case .scarf: Art(columns: 10, rows: 10, layers: [
            Layer(0xE2574C, [[1,3, 9,3, 9,5, 7,5, 7,8, 5,8, 5,5, 1,5]]),
            Layer(0xF08A7E, [[1,3, 9,3, 9,4, 1,4]]),
        ])
        case .bone: Art(columns: 10, rows: 6, layers: [
            Layer(0xE8C38A, [[0,1, 1,1, 1,0, 3,0, 3,1, 7,1, 7,0, 9,0, 9,1, 10,1, 10,2, 9,2, 9,4, 10,4, 10,5, 9,5, 9,6, 7,6, 7,5, 3,5, 3,6, 1,6, 1,5, 0,5, 0,4, 1,4, 1,2, 0,2]]),
            Layer(0xFFFFFF, [[1,1, 3,1, 3,2, 1,2], [7,1, 9,1, 9,2, 7,2]], opacity: 0.6),
        ])
        case .sun: Art(columns: 8, rows: 8, layers: [
            Layer(0xF4B63F, [[3,0, 5,0, 5,1, 3,1], [3,7, 5,7, 5,8, 3,8], [0,3, 1,3, 1,5, 0,5], [7,3, 8,3, 8,5, 7,5], [2,2, 6,2, 6,6, 2,6]]),
        ])
        case .egg: Art(columns: 12, rows: 14, layers: [
            Layer(0xF7F3EC, [[5,0, 7,0, 7,1, 8,1, 8,2, 9,2, 9,4, 10,4, 10,7, 11,7, 11,11, 10,11, 10,12, 9,12, 9,13, 3,13, 3,12, 2,12, 2,11, 1,11, 1,7, 2,7, 2,4, 3,4, 3,2, 4,2, 4,1, 5,1]]),
            Layer(0xF4B63F, [[4,6, 6,6, 6,8, 4,8], [7,4, 8,4, 8,5, 7,5], [7,9, 9,9, 9,11, 7,11]]),
            Layer(0x2B2533, [[5,0, 7,0, 7,1, 5,1], [4,1, 5,1, 5,2, 4,2], [7,1, 8,1, 8,2, 7,2], [3,2, 4,2, 4,4, 3,4], [8,2, 9,2, 9,4, 8,4], [2,4, 3,4, 3,7, 2,7], [9,4, 10,4, 10,7, 9,7], [1,7, 2,7, 2,11, 1,11], [10,7, 11,7, 11,11, 10,11], [2,11, 3,11, 3,12, 2,12], [9,11, 10,11, 10,12, 9,12], [3,12, 9,12, 9,13, 3,13]]),
        ])
        }
    }
}
