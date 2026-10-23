import SwiftUI

enum Theme {
    static let ink = Color(leashHex: 0x2B2533)
    static let accent = Color(leashHex: 0xF4B63F)
    static let overlay = ink.opacity(0.74)
    static let muted = Color(leashHex: 0x7A7385)
    static let good = Color(leashHex: 0x5BAF6A)

    static func line(_ scheme: ColorScheme) -> Color {
        Color(leashHex: scheme == .dark ? 0x342E3D : 0xE4DFEA)
    }

    static func background(_ scheme: ColorScheme) -> Color {
        Color(leashHex: scheme == .dark ? 0x17141C : 0xF3F0F7)
    }
    static func surface(_ scheme: ColorScheme) -> Color {
        Color(leashHex: scheme == .dark ? 0x231F2A : 0xFFFFFF)
    }
}

/// Rounded surface used by sheet sections.
struct CardStyle: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    func body(content: Content) -> some View {
        content.padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface(colorScheme), in: RoundedRectangle(cornerRadius: 18))
    }
}

extension View {
    func card() -> some View { modifier(CardStyle()) }
}

extension Color {
    init(leashHex hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, opacity: 1)
    }
}
