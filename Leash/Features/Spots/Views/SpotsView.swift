import SwiftUI
import CoreLocation

/// Dog parks nearest first. "Go" starts a walk there; during a walk, "Here" sets the current spot.
struct SpotsView: View {
    let model: WalkViewModel
    let onChosen: () -> Void
    @Environment(SpotCatalog.self) private var spots
    @Environment(Toaster.self) private var toaster
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.appLanguage) private var language
    @State private var query = ""
    @State private var filters: Set<Spot.Tag> = []
    @State private var region: String?
    @State private var subregion: String?
    @State private var limit = 30
    @State private var addingSpot = false

    private struct Result: Identifiable {
        let spot: Spot
        let meters: CLLocationDistance?
        var id: String { spot.id }
    }

    var body: some View {
        let reference = referencePoint
        let results = filtered(from: reference.location)
        List {
            Section {
                tagChips
                regionPicker
                Text(spots.isLoaded ? "\(language.text("\(results.count.formatted()) spots", "\(results.count.formatted()) 個地點")) · \(reference.label)"
                                    : language.text("Loading dog parks…", "載入地點中…"))
                    .font(.caption).foregroundStyle(.secondary)
            }
            .listRowBackground(Color.clear).listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))

            Section {
                ForEach(results.prefix(limit)) { row($0) }
                if results.isEmpty && spots.isLoaded {
                    Text(language.text("Nothing found, try fewer filters", "找不到，少選幾個條件")).foregroundStyle(.secondary)
                }
                if results.count > limit {
                    Button(language.text("Show more", "顯示更多")) { limit += 30 }
                }
            }

            Section {
                Button(language.text("+ Add a spot", "＋ 新增地點")) { addingSpot = true }
            } footer: {
                Text(language.text("Dog parks from OpenStreetMap (© OpenStreetMap contributors). Data may be incomplete or out of date, so check before you go.",
                                   "地點資料來自 OpenStreetMap（© OpenStreetMap contributors），可能不完整或過時，出發前請再確認現場。"))
            }
        }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: language.text("Park or city", "地名、區域"))
        .scrollContentBackground(.hidden).background(Theme.background(colorScheme))
        .onChange(of: query) { limit = 30 }
        .onChange(of: filters) { limit = 30 }
        .sheet(isPresented: $addingSpot) { AddSpotView() }
    }

    // MARK: Filtering

    private var referencePoint: (location: CLLocation, label: String) {
        if let region {
            let inRegion = spots.all.filter { $0.region == region && (subregion == nil || $0.subregion == subregion) }.compactMap(\.location)
            if !inRegion.isEmpty {
                let latitude = inRegion.map(\.coordinate.latitude).reduce(0, +) / Double(inRegion.count)
                let longitude = inRegion.map(\.coordinate.longitude).reduce(0, +) / Double(inRegion.count)
                return (CLLocation(latitude: latitude, longitude: longitude),
                        language.text("\(placeName) · nearest first", "\(placeName) · 由近到遠"))
            }
        }
        if let location = model.currentLocation {
            return (location, language.text("Nearest to you", "離你最近"))
        }
        return language == .english
            ? (CLLocation(latitude: 33.6846, longitude: -117.8265), "Nearest to Irvine, CA")
            : (CLLocation(latitude: 25.0478, longitude: 121.517), "以台北為中心")
    }

    private var placeName: String {
        [subregion, region.map(Regions.displayName)].compactMap { $0 }.joined(separator: ", ")
    }

    private func filtered(from origin: CLLocation) -> [Result] {
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        return spots.all
            .filter { spot in
                (region == nil || spot.region == region) && (subregion == nil || spot.subregion == subregion)
                    && filters.isSubset(of: spot.tags)
                    && (needle.isEmpty || "\(spot.name) \(spot.detail) \(spot.region) \(spot.subregion)".lowercased().contains(needle))
            }
            .map { Result(spot: $0, meters: $0.location?.distance(from: origin)) }
            .sorted { ($0.meters ?? .infinity) < ($1.meters ?? .infinity) }
    }

    // MARK: Rows and controls

    private func row(_ result: Result) -> some View {
        let spot = result.spot
        let visits = model.archive.completed.filter { $0.spotID == spot.id }.count
        var line = spot.detail.isEmpty ? Regions.displayName(spot.region) : spot.detail
        if let meters = result.meters { line += " · " + WalkFormat.distance(meters: meters, locale: language.locale) }
        if visits > 0 { line += language.text(" · visited \(visits)×", " ・去過 \(visits) 次") }
        return HStack(alignment: .top, spacing: 10) {
            PixelIcon(glyph: .map).frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 4) {
                Text(spot.name).font(.headline)
                Text(line).font(.caption).foregroundStyle(.secondary)
                if !spot.tags.isEmpty {
                    Text(Spot.Tag.allCases.filter(spot.tags.contains).map { $0.label(in: language) }.joined(separator: " · "))
                        .font(.caption2).foregroundStyle(Theme.good)
                }
            }
            Spacer()
            Button(model.activeWalk == nil ? language.text("Go", "出發") : language.text("Here", "在這")) { choose(spot) }
                .buttonStyle(.borderedProminent).foregroundStyle(Theme.ink).disabled(!model.canWrite)
        }
        .padding(.vertical, 2)
    }

    private var tagChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Spot.Tag.allCases, id: \.self) { tag in
                    let on = filters.contains(tag)
                    Button(tag.label(in: language)) {
                        if on { filters.remove(tag) } else { filters.insert(tag) }
                    }
                    .font(.caption).padding(.horizontal, 10).padding(.vertical, 6)
                    .foregroundStyle(on ? Theme.ink : .primary)
                    .background(on ? Theme.accent : Theme.surface(colorScheme), in: Capsule())
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
        }
    }

    private var regionPicker: some View {
        let counts = Dictionary(spots.all.map { ($0.region, 1) }, uniquingKeysWith: +)
        let ordered = (language == .english ? Regions.unitedStates.keys.sorted() + Regions.taiwan
                                            : Regions.taiwan + Regions.unitedStates.keys.sorted()).filter { counts[$0] != nil }
        let subregions = region.map { selected in
            Dictionary(spots.all.filter { $0.region == selected && !$0.subregion.isEmpty }.map { ($0.subregion, 1) }, uniquingKeysWith: +)
        } ?? [:]
        return HStack {
            Menu {
                Button(language.text("Nearest first", "由近到遠")) { region = nil; subregion = nil; limit = 30 }
                ForEach(ordered, id: \.self) { name in
                    Button("\(Regions.displayName(name)) (\(counts[name] ?? 0))") { region = name; subregion = nil; limit = 30 }
                }
            } label: {
                Label(region.map(Regions.displayName) ?? language.text("Choose a region", "選擇地區"), systemImage: "mappin.and.ellipse")
            }
            if subregions.count > 1 {
                Menu {
                    Button(language.text("All areas", "全部鄉鎮市區")) { subregion = nil; limit = 30 }
                    ForEach(subregions.keys.sorted { subregions[$0]! > subregions[$1]! || (subregions[$0] == subregions[$1] && $0 < $1) }, id: \.self) { name in
                        Button("\(name) (\(subregions[name] ?? 0))") { subregion = name; limit = 30 }
                    }
                } label: {
                    Text(subregion ?? language.text("All areas", "全部鄉鎮市區"))
                }
            }
        }
        .font(.subheadline)
    }

    private func choose(_ spot: Spot) {
        if model.activeWalk == nil { model.start(at: spot.id) } else { model.setSpot(spot.id) }
        guard model.activeWalk?.spotID == spot.id else { return }
        toaster.show("📍 \(spot.name)")
        onChosen()
    }
}

private struct AddSpotView: View {
    @Environment(SpotCatalog.self) private var spots
    @Environment(Toaster.self) private var toaster
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appLanguage) private var language
    @State private var name = ""
    @State private var area = ""
    @State private var tags: Set<Spot.Tag> = []

    var body: some View {
        NavigationStack {
            Form {
                TextField(language.text("Name", "名稱"), text: $name)
                TextField(language.text("City, e.g. Irvine", "縣市與區域，例如：臺北市大安區"), text: $area)
                Section(language.text("Facilities", "設施")) {
                    ForEach(Spot.Tag.allCases, id: \.self) { tag in
                        Toggle(tag.label(in: language), isOn: Binding(
                            get: { tags.contains(tag) },
                            set: { if $0 { tags.insert(tag) } else { tags.remove(tag) } }))
                    }
                }
            }
            .navigationTitle(language.text("Add a spot", "新增地點"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(language.text("Cancel", "取消")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(language.text("Add", "加入"), action: save)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        let trimmedArea = String(area.trimmingCharacters(in: .whitespaces).prefix(60))
        let spot = language == .english
            ? CustomSpot(name: String(name.prefix(40)), area: trimmedArea, tags: tags, country: .unitedStates, region: trimmedArea)
            : CustomSpot(name: String(name.prefix(40)), area: trimmedArea, tags: tags, country: .taiwan,
                         region: Regions.taiwanCounty(in: trimmedArea) ?? Regions.taiwan[0])
        do {
            try spots.add(spot)
            toaster.show(language.text("Added!", "加入了！"))
            dismiss()
        } catch {
            toaster.show(language.text("Didn't save, tap again", "沒存到，再按一次"))
        }
    }
}
