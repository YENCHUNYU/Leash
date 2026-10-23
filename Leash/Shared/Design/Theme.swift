import SwiftUI

enum Theme {
    static let ink = Color(leashHex: 0x2B2533)
    static let accent = Color(leashHex: 0xF4B63F)
    static let overlay = ink.opacity(0.74)

    static func background(_ scheme: ColorScheme) -> Color {
        Color(leashHex: scheme == .dark ? 0x17141C : 0xF3F0F7)
    }
    static func surface(_ scheme: ColorScheme) -> Color {
        Color(leashHex: scheme == .dark ? 0x231F2A : 0xFFFFFF)
    }
}

extension Color {
    init(leashHex hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, opacity: 1)
    }
}
