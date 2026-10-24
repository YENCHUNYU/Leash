import SwiftUI

struct WalkDiaryView: View {
    let model: WalkViewModel
    @Environment(GameModel.self) private var game
    @Environment(SpotCatalog.self) private var spots
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.appLanguage) private var language
    @State private var pendingDelete: Walk?
    private var walks: [Walk] { model.archive.completed }

    var body: some View {
        List {
            Section { weekSummary }
                .listRowBackground(Color.clear).listRowInsets(EdgeInsets())
            if walks.isEmpty {
                ContentUnavailableView(language.text("Your first walk starts here", "一起寫下第一篇散步日記"), systemImage: "pawprint",
                                       description: Text(language.text("Tap the door to write your first entry", "點門出門，寫下第一篇")))
            }
            ForEach(walks) { walk in
                NavigationLink {
                    WalkSummaryView(walk: walk).navigationTitle(language.text("Walk", "散步紀錄"))
                } label: {
                    row(walk)
                }
                .swipeActions {
                    Button(language.text("Delete", "刪除"), role: .destructive) { pendingDelete = walk }
                }
            }
        }
        .scrollContentBackground(.hidden).background(Theme.background(colorScheme))
        .confirmationDialog(language.text("Delete this entry?", "刪除這筆？"), isPresented: Binding(
            get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }), titleVisibility: .visible, presenting: pendingDelete) { walk in
            Button(language.text("Delete", "刪除"), role: .destructive) { model.delete(walk) }
        }
    }

    private var weekSummary: some View {
        let calendar = Calendar.current
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        let week = walks.filter { !$0.isIndoor && $0.startedAt >= weekStart }
        return HStack {
            summaryValue("\(week.count)", language.text("This week", "本週"))
            summaryValue(WalkFormat.distance(meters: week.reduce(0) { $0 + $1.distanceMeters }, locale: language.locale),
                         language.text("Distance", "距離"))
            summaryValue("\(game.progress.currentStreak)", language.text("Day streak", "連續天"))
        }
        .padding(.vertical, 6)
    }

    private func summaryValue(_ value: String, _ title: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(.title3, design: .monospaced)).lineLimit(1).minimumScaleFactor(0.6)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12)
        .background(Theme.surface(colorScheme), in: RoundedRectangle(cornerRadius: 16))
    }

    private func row(_ walk: Walk) -> some View {
        HStack(spacing: 14) {
            VStack {
                Text(walk.startedAt, format: .dateTime.day()).font(.system(.title, design: .monospaced))
                Text(walk.startedAt, format: .dateTime.month(.abbreviated)).font(.caption).foregroundStyle(.secondary)
            }.frame(width: 45)
            VStack(alignment: .leading, spacing: 5) {
                Text(WalkFormat.spotName(walk, spots: spots, language: language)).font(.headline).lineLimit(1)
                HStack(spacing: 10) {
                    Text(walk.startedAt, format: .dateTime.hour().minute())
                    Label("\(walk.minutes())", systemImage: "stopwatch").labelStyle(.titleAndIcon)
                    if walk.distanceMeters > 0 { Text(WalkFormat.distance(walk, locale: language.locale)) }
                    if walk.count(of: .poop) > 0 { iconCount(.poop, walk.count(of: .poop)) }
                    if walk.count(of: .pee) > 0 { iconCount(.drop, walk.count(of: .pee)) }
                }
                .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(walk.isIndoor ? "🏠" : "🐾")
        }.padding(.vertical, 5)
    }

    private func iconCount(_ glyph: PixelIcon.Glyph, _ count: Int) -> some View {
        HStack(spacing: 2) { PixelIcon(glyph: glyph).frame(width: 12, height: 12); Text("\(count)") }
    }
}
