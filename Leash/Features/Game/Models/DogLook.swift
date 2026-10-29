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
