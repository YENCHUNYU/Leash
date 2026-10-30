import Foundation

/// The user's own dog, described by traits read from a photo and drawn on the same cute template as the breeds.
nonisolated struct DogLook: Codable, Equatable, Sendable {
    enum Ears: String, Codable, CaseIterable, Sendable { case pricked, floppy }

    var ears: Ears
    var coat: UInt32
    var earColor: UInt32
    var muzzle: UInt32
    var chest: UInt32
    var paws: UInt32
    /// The collar color seen in the photo, if any.
    var collar: UInt32? = nil
    /// The main colors found on the dog, offered as swatches when editing.
    var photoColors: [UInt32] = []
}

extension DogLook {
    /// A breed's coat as an editable look, for designing a dog without a photo.
    init(breed: Breed) {
        self.init(ears: breed.ears == .pricked ? .pricked : .floppy, coat: breed.coat,
                  earColor: DogSprite.shade(breed.coat, 0.8), muzzle: breed.muzzle,
                  chest: breed.muzzle, paws: breed.coat)
    }
}

/// The 16×16 dog templates and how a `DogLook` paints them.
nonisolated enum DogSprite {
    struct Pixel: Sendable { let x, y: Int; let color: UInt32 }

    static let outline: UInt32 = 0x2B2533
    static let tag: UInt32 = 0xF4B63F

    // O outline, E eye, W eye shine, N nose, K cheek, C coat, D floppy ear, M muzzle, S collar, G collar tag.
    static let prickedEars = [
        "................", "..OO........OO..", ".OCCO......OCCO.", ".OCCCOOOOOOCCCO.",
        ".OCCCCCCCCCCCCO.", "OCCCCCCCCCCCCCCO", "OCCWECCCCCCWECCO", "OCCEECCCCCCEECCO",
        "OCKCCMMMMMMCCKCO", ".OCCMMMNNMMMCCO.", ".OCCMMMMMMMMCCO.", "..OOSSSSSSSSOO..",
        "..OCCCCGGCCCCO..", "..OCCCCCCCCCCO..", "..OCCO....OCCO..", "..OOOO....OOOO..",
    ]
    static let floppyEars = [
        "................", "................", "....OOOOOOOO....", "...OCCCCCCCCO...",
        ".OOCCCCCCCCCCOO.", "ODDCCCCCCCCCCDDO", "ODDCWECCCCWECDDO", "ODDCEECCCCEECDDO",
        "ODDKCMMMMMMCKDDO", ".OODCMMNNMMCDOO.", "..OCCMMMMMMCCO..", "..OOSSSSSSSSOO..",
        "..OCCCCGGCCCCO..", "..OCCCCCCCCCCO..", "..OCCO....OCCO..", "..OOOO....OOOO..",
    ]

    static func pixels(look: DogLook, scarf: UInt32) -> [Pixel] {
        let map = look.ears == .pricked ? prickedEars : floppyEars
        // Ears the same color as the head get a darker shade, so they still read as ears.
        let ear = look.earColor == look.coat ? shade(look.coat, 0.8) : look.earColor
        let palette: [Character: UInt32] = [
            "O": outline, "E": outline, "N": outline, "W": 0xFFFFFF, "K": 0xF2A6A0,
            "C": look.coat, "D": ear, "M": look.muzzle, "S": scarf, "G": tag,
        ]
        var result: [Pixel] = []
        for (y, row) in map.enumerated() {
            for (x, symbol) in row.enumerated() {
                guard var color = palette[symbol] else { continue }
                if symbol == "C" {
                    switch y {
                    case ...3 where look.ears == .pricked: color = ear      // pointed ear flaps
                    case 12...13 where (5...10).contains(x): color = look.chest   // chest under the collar
                    case 14: color = look.paws
                    default: break
                    }
                }
                result.append(Pixel(x: x, y: y, color: color))
            }
        }
        return result
    }

    static func shade(_ hex: UInt32, _ factor: Double) -> UInt32 {
        func channel(_ shift: UInt32) -> UInt32 {
            UInt32(min(255, max(0, (Double((hex >> shift) & 255) * factor).rounded()))) << shift
        }
        return channel(16) | channel(8) | channel(0)
    }
}

/// Something a dog can wear, drawn over its sprite.
nonisolated enum Accessory: String, Codable, CaseIterable, Identifiable, Sendable {
    case pumpkin, witchHat, mask, santaHat, antlers

    var id: String { rawValue }

    func name(in language: AppLanguage) -> String {
        switch self {
        case .pumpkin: language.text("Pumpkin", "南瓜")
        case .witchHat: language.text("Witch Hat", "巫師帽")
        case .mask: language.text("Mask", "面具")
        case .santaHat: language.text("Santa Hat", "聖誕帽")
        case .antlers: language.text("Antlers", "麋鹿角")
        }
    }

    var isHalloween: Bool { [.pumpkin, .witchHat, .mask].contains(self) }
}

extension DogSprite {
    /// Pixels to draw on top of a dog with the given ears.
    static func pixels(for accessory: Accessory, ears: DogLook.Ears) -> [Pixel] {
        let map = ears == .pricked ? prickedEars : floppyEars
        // The outline row at the top of the head, where hats sit.
        let top = ears == .pricked ? 3 : 2
        let palette: [Character: UInt32] = [
            "O": outline, "R": 0xD9383A, "W": 0xFFFFFF, "B": 0x3B2A4F, "P": 0xF28C28,
            "G": 0x5BAF6A, "A": 0x9A6738, "U": 0x8E44AD, "Y": 0xFFD34D,
        ]
        func art(_ rows: [String], top firstRow: Int, left: Int = 0) -> [Pixel] {
            rows.enumerated().flatMap { dy, row in
                row.enumerated().compactMap { dx, symbol in
                    let x = left + dx, y = firstRow + dy
                    guard let color = palette[symbol], (0..<16).contains(x), (0..<16).contains(y) else { return nil }
                    return Pixel(x: x, y: y, color: color)
                }
            }
        }
        switch accessory {
        case .santaHat:
            return art(["..........WW....",
                        "........RRWW....",
                        ".....RRRRRR.....",
                        "...WWWWWWWWWW..."], top: top - 3)
        case .witchHat:
            return art([".......BB.......",
                        "......BBBB......",
                        "......PPPP......",
                        "..BBBBBBBBBBBB.."], top: top - 3)
        case .antlers:
            // Antlers, plus a red nose.
            return art(["..A.A......A.A..",
                        "...AA......AA...",
                        "....A......A...."], top: top - 3)
                + [Pixel(x: 7, y: 9, color: 0xD9383A), Pixel(x: 8, y: 9, color: 0xD9383A)]
        case .pumpkin:
            // A glowing jack-o'-lantern by the front paw.
            return art(["...G...",
                        ".OOOOO.",
                        "OPYPYPO",
                        "OPPPPPO",
                        "OPYYYPO",
                        ".OOOOO."], top: 10, left: 9)
        case .mask:
            // A solid band across both eyes with pointed tips; the eyes show through.
            var eyes = Set<Int>()
            for (y, row) in map.enumerated() {
                for (x, symbol) in row.enumerated() where symbol == "W" || symbol == "E" { eyes.insert(y * 16 + x) }
            }
            let xs = eyes.map { $0 % 16 }, ys = eyes.map { $0 / 16 }
            guard let left = xs.min(), let right = xs.max(), let upper = ys.min(), let lower = ys.max() else { return [] }
            var cells: [Pixel] = []
            for y in (upper - 1)...(lower + 1) {
                for x in (left - 1)...(right + 1) where !eyes.contains(y * 16 + x) {
                    // Leave the nose bridge open at the bottom so it reads as a mask, not glasses.
                    if y == lower + 1 && x > left + 2 && x < right - 2 { continue }
                    cells.append(Pixel(x: x, y: y, color: palette["U"]!))
                }
            }
            cells += [Pixel(x: left - 2, y: upper - 1, color: palette["U"]!), Pixel(x: right + 2, y: upper - 1, color: palette["U"]!)]
            return cells
        }
    }
}
