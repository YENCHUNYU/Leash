import SwiftUI

/// 16×16 sprite for any breed, or the user's own dog when `look` is set. `scarf` is the collar color.
/// `silhouette` draws a locked, undiscovered dog.
struct PixelDog: View {
    var breed = Breed.named("mixy")
    var scarf: UInt32 = 0xE2574C
    var silhouette = false
    var look: DogLook? = nil
    var accessory: Accessory? = nil

    var body: some View {
        let ears = look?.ears ?? (breed.ears == .pricked ? .pricked : .floppy)
        let pixels = (look.map { DogSprite.pixels(look: $0, scarf: scarf) }
            ?? Self.pixels(breed: breed, scarf: scarf, silhouette: silhouette))
            + (accessory.map { DogSprite.pixels(for: $0, ears: ears) } ?? [])
        Canvas { context, size in
            let cell = CGSize(width: size.width / 16, height: size.height / 16)
            for pixel in pixels {
                context.fill(Path(CGRect(x: Double(pixel.x) * cell.width, y: Double(pixel.y) * cell.height,
                                         width: cell.width + 0.2, height: cell.height + 0.2)),
                             with: .color(Color(leashHex: pixel.color)))
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }

    private typealias Pixel = DogSprite.Pixel

    private static func pixels(breed: Breed, scarf: UInt32, silhouette: Bool) -> [Pixel] {
        let map = breed.ears == .pricked ? DogSprite.prickedEars : DogSprite.floppyEars
        let light = [0xFFFFFF, 0xF7F4EE, 0xF4ECDF].contains(breed.coat)
        let palette: [Character: UInt32] = [
            "O": 0x2B2533, "E": 0x2B2533, "N": 0x2B2533, "W": 0xFFFFFF, "K": 0xF2A6A0,
            "C": breed.coat, "D": DogSprite.shade(breed.coat, light ? 0.86 : 0.78), "M": breed.muzzle, "S": scarf, "G": DogSprite.tag,
        ]
        var result: [Pixel] = []
        for (y, row) in map.enumerated() {
            for (x, symbol) in row.enumerated() {
                guard var color = palette[symbol] else { continue }
                if silhouette {
                    color = "OEN".contains(symbol) ? 0x7A7385 : 0xE4DFEA
                } else if symbol == "C" {
                    color = markings(breed, x: x, y: y) ?? color
                }
                result.append(Pixel(x: x, y: y, color: color))
            }
        }
        return result
    }

    /// Per-breed coat patterns from the reference sprites.
    private static func markings(_ breed: Breed, x: Int, y: Int) -> UInt32? {
        switch breed.id {
        case "brindle" where (x + y) % 3 == 0: DogSprite.shade(breed.coat, 0.62)
        case "calico" where y < 9 && x < 7: 0xD9853B
        case "calico" where y < 9 && x > 9: 0x3A322C
        case "socks" where y >= 13: 0xFFFFFF
        case "corgi" where y >= 12 && x > 4 && x < 11: 0xFFFFFF
        case "husky" where (4...7).contains(y) && (5...10).contains(x): 0xFFFFFF
        case "bc" where (7...8).contains(x) && y >= 3: 0xFFFFFF
        case "bernese" where y == 5 && (x == 4 || x == 11): 0xC9773A
        default: nil
        }
    }
}
