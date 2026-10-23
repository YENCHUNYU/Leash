import SwiftUI

/// Name the dog and pick a coat (unlocked by befriending that breed) and a bandana (unlocked by level).
struct ProfileView: View {
    private enum Tab { case coat, scarf }

    @Environment(GameModel.self) private var game
    @Environment(Toaster.self) private var toaster
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.appLanguage) private var language
    @State private var name = ""
    @State private var tab = Tab.coat
    @FocusState private var editingName: Bool
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                VStack(spacing: 8) {
                    PixelDog(breed: game.dogBreed, scarf: game.profile.scarf).frame(width: 120, height: 120)
                    TextField(language.text("Name your dog", "幫狗狗取名字"), text: $name)
                        .font(.system(.title3, design: .monospaced)).multilineTextAlignment(.center)
                        .focused($editingName).submitLabel(.done)
                        .onSubmit(saveName)
                        .onChange(of: editingName) { _, editing in if !editing { saveName() } }
                        .accessibilityLabel(language.text("Dog's name", "狗狗名字"))
                    Text(game.dogBreed.name(in: language)).font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity).card()

                Picker("", selection: $tab) {
                    Label(language.text("Coat", "毛色"), systemImage: "pawprint.fill").tag(Tab.coat)
                    Label(language.text("Bandana", "領巾"), systemImage: "paintpalette.fill").tag(Tab.scarf)
                }
                .pickerStyle(.segmented)

                LazyVGrid(columns: columns, spacing: 8) {
                    switch tab {
                    case .coat: ForEach(Breed.all) { coatTile($0) }
                    case .scarf: ForEach(Array(DogProfile.scarves.enumerated()), id: \.offset) { scarfTile(index: $0, color: $1) }
                    }
                }
                Text(tab == .coat ? language.text("Make new friends to unlock their look", "交到新朋友就能解鎖牠的樣子")
                                  : language.text("Level up for more colors", "升級解鎖更多顏色"))
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .padding(16)
        }
        .background(Theme.background(colorScheme))
        .onAppear { name = game.profile.name }
    }

    private func tile(selected: Bool, locked: Bool, @ViewBuilder content: () -> some View) -> some View {
        content()
            .padding(10).frame(maxWidth: .infinity).aspectRatio(1, contentMode: .fit)
            .background(Theme.surface(colorScheme), in: RoundedRectangle(cornerRadius: 14))
            .overlay { RoundedRectangle(cornerRadius: 14).stroke(selected ? Theme.accent : .clear, lineWidth: 3) }
            .overlay(alignment: .bottomTrailing) {
                if locked { PixelIcon(glyph: .lock).frame(width: 16).padding(6) }
                else if selected { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent).padding(4) }
            }
    }

    private func coatTile(_ breed: Breed) -> some View {
        let unlocked = game.isUnlocked(breed)
        return Button {
            update { $0.breedID = breed.id }
        } label: {
            tile(selected: game.profile.breedID == breed.id, locked: !unlocked) {
                PixelDog(breed: breed, scarf: game.profile.scarf, silhouette: !unlocked)
            }
        }
        .buttonStyle(.plain).disabled(!unlocked)
        .accessibilityLabel(unlocked ? breed.name(in: language) : language.text("Locked", "未解鎖"))
        .accessibilityAddTraits(game.profile.breedID == breed.id ? .isSelected : [])
    }

    private func scarfTile(index: Int, color: UInt32) -> some View {
        let unlocked = index < DogProfile.unlockedScarves(level: game.progress.level)
        return Button {
            update { $0.scarf = color }
        } label: {
            tile(selected: game.profile.scarf == color, locked: !unlocked) {
                RoundedRectangle(cornerRadius: 6).fill(unlocked ? Color(leashHex: color) : Theme.line(colorScheme))
                    .overlay { RoundedRectangle(cornerRadius: 6).stroke(.black.opacity(0.15)) }
                    .padding(8)
            }
        }
        .buttonStyle(.plain).disabled(!unlocked)
        .accessibilityLabel(unlocked ? language.text("Bandana color \(index + 1)", "領巾顏色 \(index + 1)") : language.text("Locked", "未解鎖"))
        .accessibilityAddTraits(game.profile.scarf == color ? .isSelected : [])
    }

    private func saveName() {
        let trimmed = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(20))
        guard trimmed != game.profile.name else { return }
        if update({ $0.name = trimmed }) {
            toaster.show(language.text("✏️ Renamed to \(trimmed.isEmpty ? "My dog" : trimmed)", "✏️ 改名為「\(trimmed.isEmpty ? "我的狗狗" : trimmed)」"))
        }
    }

    @discardableResult
    private func update(_ change: (inout DogProfile) -> Void) -> Bool {
        let saved = game.updateProfile(change)
        if !saved { toaster.show(language.text("Didn't save, tap again", "沒存到，再按一次")) }
        return saved
    }
}
