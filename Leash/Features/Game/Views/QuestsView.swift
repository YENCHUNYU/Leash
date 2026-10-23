import SwiftUI

/// Level, today's quests, walk-egg progress and unlocked tips.
struct QuestsView: View {
    let walks: WalkViewModel
    @Environment(GameModel.self) private var game
    @Environment(Toaster.self) private var toaster
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.appLanguage) private var language

    var body: some View {
        let progress = game.progress
        let quests = game.quests(language: language)
        let allDone = quests.allSatisfy(\.isDone)
        ScrollView {
            VStack(spacing: 10) {
                HStack(spacing: 14) {
                    VStack(spacing: 0) {
                        Text("Lv").font(.caption2)
                        Text("\(progress.level)").font(.system(.title, design: .monospaced))
                    }
                    .foregroundStyle(Theme.ink).frame(width: 56, height: 56).background(Theme.accent, in: RoundedRectangle(cornerRadius: 14))
                    progressColumn(progress.title(in: language), fraction: progress.levelFraction,
                                   caption: "\(progress.xp) / \(progress.nextLevelXP) XP")
                }
                .card()

                VStack(spacing: 0) {
                    ForEach(quests) { quest in
                        questRow(icon: icon(for: quest.kind), title: quest.title, detail: quest.detail, done: quest.isDone) {
                            if quest.canComplete {
                                Button(language.text("Done", "完成")) { completeIndoor() }
                                    .buttonStyle(.borderedProminent).foregroundStyle(Theme.ink)
                            }
                        }
                        Divider()
                    }
                    questRow(icon: .bone, title: language.text("All done", "全部完成"), detail: language.text("+5 treats", "＋5 零食"), done: allDone) {}
                }
                .card()

                HStack(spacing: 14) {
                    PixelIcon(glyph: .egg).frame(width: 44)
                    progressColumn(language.text("Walk egg", "散步蛋"),
                                   fraction: 1 - Double(progress.eggMinutesLeft) / Double(GameProgress.eggMinutes),
                                   caption: language.text("Hatches in \(progress.eggMinutesLeft) min", "再 \(progress.eggMinutesLeft) 分鐘孵化"))
                }
                .card()

                ForEach(WalkTips.unlocked(progress.hatchedEggs, language: language).reversed(), id: \.self) { tip in
                    Text("🥚 \(tip)").font(.callout).card()
                }
            }
            .padding(16)
        }
        .background(Theme.background(colorScheme))
    }

    private func progressColumn(_ title: String, fraction: Double, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(.headline, design: .monospaced))
            ProgressView(value: min(max(fraction, 0), 1)).tint(Theme.accent)
            Text(caption).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func questRow(icon: PixelIcon.Glyph, title: String, detail: String, done: Bool,
                          @ViewBuilder trailing: () -> some View) -> some View {
        HStack(spacing: 12) {
            PixelIcon(glyph: icon).frame(width: 26, height: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).strikethrough(done)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            trailing()
            if done { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.good) }
        }
        .padding(.vertical, 8)
        .opacity(done ? 0.7 : 1)
        .accessibilityElement(children: .combine)
        .accessibilityValue(done ? language.text("Done", "完成") : "")
    }

    private func icon(for kind: Quest.Kind) -> PixelIcon.Glyph {
        switch kind {
        case .walk: .quest
        case .indoor: .home
        case .photo: .album
        case .poop: .poop
        }
    }

    private func completeIndoor() {
        if walks.logIndoorPlay(Quest.indoorActivity(on: .now, language: language)) {
            toaster.show(language.text("Indoor quest done!", "室內任務完成！"))
        }
    }
}
