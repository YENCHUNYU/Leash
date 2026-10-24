import SwiftUI

/// Collections: dog friends, visited spots, regions and badges.
struct DexView: View {
    private enum Tab: String, CaseIterable { case dogs, spots, regions, badges }

    @Environment(GameModel.self) private var game
    @Environment(SpotCatalog.self) private var spots
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.appLanguage) private var language
    @State private var tab = Tab.dogs
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    var body: some View {
        let progress = game.progress
        ScrollView {
            VStack(spacing: 12) {
                Picker(language.text("Collection", "收藏"), selection: $tab) {
                    ForEach(Tab.allCases, id: \.self) { Text(title($0)).tag($0) }
                }
                .pickerStyle(.segmented)
                switch tab {
                case .dogs: dogs(progress)
                case .spots: visitedSpots(progress)
                case .regions: regions(progress)
                case .badges: badges
                }
            }
            .padding(16)
        }
        .background(Theme.background(colorScheme))
    }

    private func title(_ tab: Tab) -> String {
        switch tab {
        case .dogs: language.text("Dogs", "狗狗")
        case .spots: language.text("Spots", "地點")
        case .regions: language.text("Regions", "地區")
        case .badges: language.text("Badges", "徽章")
        }
    }

    private func counter(_ text: String) -> some View {
        Text(text).font(.system(.subheadline, design: .monospaced)).foregroundStyle(.secondary)
    }

    private func dogs(_ progress: GameProgress) -> some View {
        VStack(spacing: 10) {
            counter("\(progress.friendKinds) / \(Breed.all.count)")
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Array(Breed.all.enumerated()), id: \.element.id) { number, breed in
                    let count = progress.friends[breed.id] ?? 0
                    VStack(spacing: 2) {
                        Text(String(format: "%03d", number + 1)).font(.system(.caption2, design: .monospaced)).foregroundStyle(.secondary)
                        PixelDog(breed: breed, silhouette: count == 0).padding(.horizontal, 8)
                        Text(count > 0 ? "×\(count)" : " ").font(.system(.caption2, design: .monospaced))
                    }
                    .padding(6).background(Theme.surface(colorScheme), in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(count > 0
                        ? "\(breed.name(in: language)), \(breed.rarity.name(in: language)), ×\(count)"
                        : language.text("Not met yet", "還沒遇過"))
                }
            }
            Text(language.text("★ Common　★★ Uncommon　★★★ Rare　★★★★ Legendary", "★ 常見　★★ 少見　★★★ 稀有　★★★★ 傳說"))
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func visitedSpots(_ progress: GameProgress) -> some View {
        let visited = progress.visitedSpotIDs.compactMap(spots.spot(id:)).sorted { $0.name < $1.name }
        return VStack(spacing: 8) {
            counter(language.text("Visited \(visited.count) · \(spots.all.count.formatted()) total",
                                  "去過 \(visited.count) 個 · 全部 \(spots.all.count.formatted()) 個"))
            if visited.isEmpty {
                Text(language.text("Pick a spot from Spots before your walk to collect it.", "出門前在「地點」選一個地方，就能收集它。"))
                    .font(.footnote).foregroundStyle(.secondary).padding()
            }
            ForEach(visited) { spot in
                Label { VStack(alignment: .leading) { Text(spot.name); Text(Regions.displayName(spot.region)).font(.caption).foregroundStyle(.secondary) } }
                    icon: { PixelIcon(glyph: .map).frame(width: 22) }
                    .card()
            }
        }
    }

    private func regions(_ progress: GameProgress) -> some View {
        let all = language == .english ? Regions.unitedStates.keys.sorted() : Regions.taiwan
        return VStack(spacing: 10) {
            counter("\(all.filter(progress.visitedRegions.contains).count) / \(all.count)")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: 6)], spacing: 6) {
                ForEach(all, id: \.self) { region in
                    let visited = progress.visitedRegions.contains(region)
                    Text(language == .english ? region : String(region.dropLast()))
                        .font(.system(.footnote, design: .monospaced))
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                        .foregroundStyle(visited ? .white : .secondary)
                        .background(visited ? Theme.good : Theme.surface(colorScheme), in: RoundedRectangle(cornerRadius: 10))
                        .accessibilityLabel(Regions.displayName(region))
                        .accessibilityValue(visited ? language.text("Visited", "去過") : "")
                }
            }
        }
    }

    private var badges: some View {
        let list = game.badges(language: language)
        return VStack(spacing: 10) {
            counter("\(list.filter(\.earned).count) / \(list.count)")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(list) { badge in
                    VStack(spacing: 6) {
                        Text(badge.emoji).font(.largeTitle).grayscale(badge.earned ? 0 : 1).opacity(badge.earned ? 1 : 0.35)
                        Text(badge.title).font(.caption).multilineTextAlignment(.center).lineLimit(2, reservesSpace: true)
                    }
                    .frame(maxWidth: .infinity).padding(10)
                    .background(Theme.surface(colorScheme), in: RoundedRectangle(cornerRadius: 14))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(badge.title)
                    .accessibilityValue(badge.earned ? language.text("Earned", "已獲得") : language.text("Locked", "未解鎖"))
                }
            }
        }
    }
}
