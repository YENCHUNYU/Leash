import SwiftUI

/// Before a walk with several dogs: choose who comes along.
struct WalkDogPicker: View {
    let onStart: ([UUID]) -> Void
    @Environment(GameModel.self) private var game
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.appLanguage) private var language
    @State private var chosen: Set<UUID> = []

    var body: some View {
        VStack(spacing: 14) {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 10)], spacing: 10) {
                    ForEach(game.roster.dogs) { dog in
                        let on = chosen.contains(dog.id)
                        Button {
                            if on { chosen.remove(dog.id) } else { chosen.insert(dog.id) }
                        } label: {
                            VStack(spacing: 6) {
                                PixelDog(breed: dog.breed, scarf: dog.scarf, look: dog.look, accessory: dog.accessory)
                                    .frame(width: 56, height: 56)
                                    .opacity(on ? 1 : 0.4)
                                Text(dog.displayName(in: language)).font(.system(.caption, design: .monospaced)).lineLimit(1)
                                Image(systemName: on ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(on ? Theme.good : Theme.muted)
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                            .background(Theme.surface(colorScheme), in: RoundedRectangle(cornerRadius: 14))
                            .overlay { RoundedRectangle(cornerRadius: 14).stroke(on ? Theme.accent : .clear, lineWidth: 3) }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(dog.displayName(in: language))
                        .accessibilityAddTraits(on ? .isSelected : [])
                    }
                }
                .padding(16)
            }
            Button {
                let ids = game.roster.dogs.map(\.id).filter(chosen.contains)
                dismiss()
                onStart(ids)
            } label: {
                Text(chosen.count > 1 ? language.text("Walk \(chosen.count) dogs", "帶 \(chosen.count) 隻出門")
                                      : language.text("Start walk", "開始散步"))
                    .font(.system(.title3, design: .monospaced).weight(.bold))
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(Theme.accent, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(chosen.isEmpty)
            .opacity(chosen.isEmpty ? 0.5 : 1)
            .padding(.horizontal, 16).padding(.bottom, 12)
        }
        .background(Theme.background(colorScheme))
        .onAppear { chosen = Set(game.roster.walking.map(\.id)) }
    }
}
