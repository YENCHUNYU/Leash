import SwiftUI

/// Matches the static iOS launch screen, then uses the saved in-app language.
struct LaunchScreenView: View {
    @Environment(\.appLanguage) private var language

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Image("LaunchLawn")
                    .resizable().interpolation(.none)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                Image("LaunchLockup")
                    .resizable().interpolation(.none).scaledToFit()
                    .frame(width: 280, height: 280)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2 - 30)
                Text(language.text("One leash, connecting you and me.", "一條牽繩，牽著你和我。"))
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                    .frame(width: max(0, geometry.size.width - 40), height: 45, alignment: .top)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2 + 140.5)
            }
        }
        .ignoresSafeArea()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(language.text("Leash. One leash, connecting you and me.", "Leash。一條牽繩，牽著你和我。"))
    }
}
