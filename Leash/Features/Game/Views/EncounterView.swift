import SwiftUI

/// Meet the first waiting dog: toss a treat to make friends, or wave goodbye.
struct EncounterView: View {
    let onFinished: () -> Void
    @Environment(GameModel.self) private var game
    @Environment(SpotCatalog.self) private var spots
    @Environment(Toaster.self) private var toaster
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.appLanguage) private var language
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var reaction: Reaction?
    @State private var busy = false
    /// The dog just befriended or lost, kept on screen while its reaction plays.
    @State private var resolving: Encounter?

    private enum Reaction { case hop, shake }

    var body: some View {
        let pending = game.pendingEncounters(language: language)
        ScrollView {
            if let encounter = resolving ?? pending.first {
                content(encounter, remaining: max(0, pending.count - (resolving == nil ? 1 : 0)))
            } else {
                ContentUnavailableView(language.text("Everyone went home", "狗狗都走了"), systemImage: "pawprint")
            }
        }
        .background(Theme.background(colorScheme))
    }

    private func content(_ encounter: Encounter, remaining: Int) -> some View {
        let breed = encounter.breed
        let progress = game.progress
        let tries = game.state.attempts[encounter.id] ?? 0
        let isFriend = (progress.friends[breed.id] ?? 0) > 0
        let place = spots.spot(id: game.walks.activeWalk?.spotID)?.name
        var details = encounter.fromEgg ? language.text("🥚 Hatched from your egg", "🥚 從散步蛋出來的")
            : place.map { language.text("Met at \($0)", "在 \($0) 遇到") } ?? language.text("Met around the block", "在附近遇到")
        details += isFriend ? language.text(" · already friends", "・已是朋友") : language.text(" · new friend!", "・新朋友！")
        if tries > 0 {
            let left = EncounterRules.triesPerDog - tries
            details += language.text(" · \(left) tries left", "・剩 \(left) 次機會")
        }
        return VStack(spacing: 12) {
            PixelDog(breed: breed, scarf: 0x7A7385)
                .frame(width: 150, height: 150)
                .offset(y: reaction == .hop ? -24 : 0)
                .rotationEffect(.degrees(reaction == .shake ? 8 : 0))
                .padding(.vertical, 20).frame(maxWidth: .infinity)
                .background(Color(leashHex: 0x8CC46E), in: RoundedRectangle(cornerRadius: 24))
            Text(breed.name(in: language)).font(.system(.title2, design: .monospaced))
            Text(String(repeating: "★", count: breed.rarity.rawValue + 1) + String(repeating: "☆", count: 3 - breed.rarity.rawValue))
                .foregroundStyle(Theme.accent)
                .accessibilityLabel(breed.rarity.name(in: language))
            Text(details).font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
            HStack {
                Button(language.text("Bye", "掰掰")) { bye(encounter) }
                    .buttonStyle(.bordered)
                Button { toss(encounter) } label: {
                    Label { Text(language.text("Toss a treat ×\(progress.treats)", "丟零食 ×\(progress.treats)")) }
                        icon: { PixelIcon(glyph: .bone).frame(width: 24) }
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).foregroundStyle(Theme.ink)
            }
            .controlSize(.large).disabled(busy)
            if remaining > 0 {
                Text(language.text("\(remaining) more nearby", "附近還有 \(remaining) 隻")).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .sensoryFeedback(.success, trigger: reaction == .hop)
    }

    private func toss(_ encounter: Encounter) {
        let name = encounter.breed.name(in: language)
        let result = game.toss(to: encounter)
        switch result {
        case .noTreats:
            toaster.show(language.text("Out of treats, walk more to earn some", "零食吃完了，去散步補充"))
            return
        case .saveFailed:
            toaster.show(language.text("GameProgress didn't save", "進度沒存到"))
            return
        case .befriended(let first):
            toaster.show(first ? language.text("🎉 You and the \(name) are friends!", "🎉 和\(name)變朋友了！")
                               : language.text("♥ Another \(name)!", "♥ 又一隻\(name)"))
            animate(.hop)
        case .missed:
            toaster.show(language.text("So close! Try again", "差一點！再試試"))
            animate(.shake)
            return
        case .ranOff:
            toaster.show(language.text("💨 The \(name) ran off", "💨 \(name)跑走了"))
        }
        resolving = encounter
        advance()
    }

    private func bye(_ encounter: Encounter) {
        game.sayBye(to: encounter)
        if game.pendingEncounters(language: language).isEmpty { onFinished() }
    }

    private func animate(_ next: Reaction) {
        guard !reduceMotion else { return }
        withAnimation(.spring(duration: 0.25)) { reaction = next }
        Task {
            try? await Task.sleep(for: .seconds(0.35))
            withAnimation(.spring(duration: 0.25)) { reaction = nil }
        }
    }

    /// Pauses on the result, then shows the next dog or closes.
    private func advance() {
        busy = true
        Task {
            try? await Task.sleep(for: .seconds(reduceMotion ? 0.3 : 1.1))
            busy = false
            resolving = nil
            if game.pendingEncounters(language: language).isEmpty { onFinished() }
        }
    }
}
