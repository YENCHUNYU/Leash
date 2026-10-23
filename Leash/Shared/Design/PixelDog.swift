import SwiftUI

struct PixelDog: View {
    private let rows = [
        "................", "..OO........OO..", ".OCCO......OCCO.",
        ".OCCCOOOOOOCCCO.", ".OCCCCCCCCCCCCO.", "OCCCCCCCCCCCCCCO",
        "OCCWECCCCCCWECCO", "OCCEECCCCCCEECCO", "OCKCCMMMMMMCCKCO",
        ".OCCMMMNNMMMCCO.", ".OCCMMMMMMMMCCO.", "..OOSSSSSSSSOO..",
        "..OCSSSSSSSSCO..", "..OCCCCCCCCCCO..", "..OCCO....OCCO..", "..OOOO....OOOO.."
    ]
    var body: some View {
        Canvas { context, size in
            let colors: [Character: UInt32] = ["O": 0x2B2533, "C": 0xD9A35B, "M": 0xF1D7AE,
                "E": 0x2B2533, "W": 0xFFFFFF, "N": 0x2B2533, "K": 0xF2A6A0, "S": 0xE2574C]
            for (y, row) in rows.enumerated() {
                for (x, character) in row.enumerated() {
                    if let color = colors[character] {
                        context.fill(Path(CGRect(x: Double(x) * size.width / 16,
                            y: Double(y) * size.height / 16, width: size.width / 16 + 0.2,
                            height: size.height / 16 + 0.2)), with: .color(Color(leashHex: color)))
                    }
                }
            }
        }.accessibilityHidden(true)
    }
}
