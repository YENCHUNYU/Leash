import SwiftUI

struct WalkDiaryView: View {
    let walks: [Walk]
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.appLanguage) private var language

    var body: some View {
        List {
            if walks.isEmpty {
                ContentUnavailableView(language.text("Your first walk starts here", "一起寫下第一篇散步日記"), systemImage: "pawprint", description: Text(language.text("Completed walks, routes, and little moments will appear here.", "完成散步後，時間、路線與小紀錄會留在這裡。")))
            }
            ForEach(walks) { walk in
                NavigationLink {
                    WalkSummaryView(walk: walk).navigationTitle(language.text("Walk memories", "散步回憶"))
                } label: {
                    row(walk)
                }
            }
        }.scrollContentBackground(.hidden).background(Theme.background(colorScheme))
    }

    private func row(_ walk: Walk) -> some View {
        HStack(spacing: 14) {
            VStack {
                Text(walk.startedAt, format: .dateTime.day()).font(.system(.title, design: .monospaced))
                Text(walk.startedAt, format: .dateTime.month(.abbreviated)).font(.caption).foregroundStyle(.secondary)
            }.frame(width: 45)
            VStack(alignment: .leading, spacing: 5) {
                Text(walk.startedAt, format: .dateTime.hour().minute()).font(.headline)
                Text("⏱ \(WalkFormat.duration(walk.duration(at: .now)))   ·   \(WalkFormat.distance(walk, locale: language.locale))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text("🐾")
        }.padding(.vertical, 7)
    }
}
