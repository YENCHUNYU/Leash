import SwiftUI
import CoreLocation

/// Discover dog parks near you on a map or list. Selecting one opens details with directions.
struct SpotsView: View {
    let model: WalkViewModel
    /// Opens with the search field focused, when reached from the home search bar.
    var startSearching = false
    /// Called when a walk starts or its spot changes, so the caller can close the sheet.
    let onChosen: () -> Void
    @Environment(SpotCatalog.self) private var spots
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.appLanguage) private var language
    @Environment(\.openURL) private var openURL
    @AppStorage(Spot.plannedStorageKey) private var plannedID = ""
    @State private var query = ParkQuery()
    @State private var showingMap = true
    @State private var selectedID: String?
    @State private var limit = 30
    @State private var addingSpot = false
    @State private var searching = false

    var body: some View {
        let user = model.currentLocation
        let origin = sortOrigin(user: user)
        let parks = query.apply(to: spots.all, origin: origin.location)
        VStack(spacing: 8) {
            Picker(language.text("View", "檢視"), selection: $showingMap) {
                Label(language.text("Map", "地圖"), systemImage: "map").tag(true)
                Label(language.text("List", "列表"), systemImage: "list.bullet").tag(false)
            }
            .pickerStyle(.segmented).padding(.horizontal, 16)
            filterChips
            locationBanner(user: user)
            if showingMap {
                ParkMapView(parks: parks, userLocation: user, fallbackCenter: origin.location,
                            plannedID: plannedID.isEmpty ? nil : plannedID, selection: $selectedID)
            } else {
                list(parks, user: user, originLabel: origin.label)
            }
        }
        .searchable(text: $query.text, isPresented: $searching, placement: .navigationBarDrawer(displayMode: .always), prompt: language.text("Park, city or area", "地點、城市或區域"))
        .background(Theme.background(colorScheme))
        .onAppear {
            model.locateUser()
            if startSearching { searching = true }
        }
        .onChange(of: query) { limit = 30 }
        .sheet(item: Binding(get: { selectedID.flatMap(spots.spot(id:)) }, set: { selectedID = $0?.id })) { spot in
            NavigationStack {
                ParkDetailView(spot: spot, distance: spot.distance(from: user), model: model, onWalkChanged: onChosen)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button(language.text("Close", "關閉")) { selectedID = nil } } }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $addingSpot) { AddSpotView() }
    }

    // MARK: Sorting origin

    /// Where "nearest" is measured from: a chosen region, the user, or a default city.
    private func sortOrigin(user: CLLocation?) -> (location: CLLocation, label: String) {
        if let region = query.region {
            let inRegion = spots.all.filter { $0.region == region && (query.subregion == nil || $0.subregion == query.subregion) }.compactMap(\.location)
            if !inRegion.isEmpty {
                let latitude = inRegion.map(\.coordinate.latitude).reduce(0, +) / Double(inRegion.count)
                let longitude = inRegion.map(\.coordinate.longitude).reduce(0, +) / Double(inRegion.count)
                let place = [query.subregion, Regions.displayName(region)].compactMap { $0 }.joined(separator: ", ")
                return (CLLocation(latitude: latitude, longitude: longitude), language.text("Around \(place)", "\(place)周邊"))
            }
        }
        if let user { return (user, language.text("Nearest to you", "離你最近")) }
        return language == .english
            ? (CLLocation(latitude: 33.6846, longitude: -117.8265), "Around Irvine, CA (location off)")
            : (CLLocation(latitude: 25.0478, longitude: 121.517), "以台北為中心（未開啟定位）")
    }

    // MARK: Controls

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(ParkFilter.allCases, id: \.self) { filter in
                    let on = query.filters.contains(filter)
                    Button {
                        if on { query.filters.remove(filter) } else { query.filters.insert(filter) }
                    } label: {
                        Label(filter.label(in: language), systemImage: filter.systemImage)
                            .font(.caption).padding(.horizontal, 10).padding(.vertical, 7)
                            .foregroundStyle(on ? Theme.ink : .primary)
                            .background(on ? Theme.accent : Theme.surface(colorScheme), in: Capsule())
                    }
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder private func locationBanner(user: CLLocation?) -> some View {
        switch model.authorization {
        case .denied, .restricted:
            banner(language.text("Location is off, so distances are hidden.", "未開啟定位，無法顯示距離。"),
                   action: language.text("Settings", "設定")) {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
        case .notDetermined:
            banner(language.text("Show parks near you?", "顯示你附近的地點？"), action: language.text("Use my location", "使用我的位置")) {
                model.locateUser()
            }
        default:
            if user == nil {
                Label(language.text("Finding your location…", "正在取得你的位置…"), systemImage: "location")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func banner(_ text: String, action: String, perform: @escaping () -> Void) -> some View {
        HStack {
            Image(systemName: "location.slash")
            Text(text).font(.footnote)
            Spacer()
            Button(action, action: perform).font(.footnote.weight(.semibold))
        }
        .padding(10)
        .background(Theme.surface(colorScheme), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
    }

    // MARK: List

    private func list(_ parks: [Spot], user: CLLocation?, originLabel: String) -> some View {
        List {
            Section {
                ForEach(parks.prefix(limit)) { spot in
                    Button { selectedID = spot.id } label: {
                        ParkRow(spot: spot, distance: spot.distance(from: user), isPlanned: spot.id == plannedID)
                    }
                    .buttonStyle(.plain)
                }
                if parks.isEmpty && spots.isLoaded {
                    Text(language.text("Nothing found, try fewer filters", "找不到，少選幾個條件")).foregroundStyle(.secondary)
                }
                if parks.count > limit {
                    Button(language.text("Show more", "顯示更多")) { limit += 30 }
                }
            } header: {
                Text(spots.isLoaded ? "\(language.text("\(parks.count.formatted()) parks", "\(parks.count.formatted()) 個地點")) · \(originLabel)"
                                    : language.text("Loading dog parks…", "載入地點中…"))
            }
            Section {
                Button(language.text("+ Add a spot", "＋ 新增地點")) { addingSpot = true }
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                if let fetched = spots.fetchedOn {
                    Text(language.text("Data fetched \(fetched). ", "資料擷取於 \(fetched)。"))
                }
                Text(language.text("Dog parks from a bundled OpenStreetMap snapshot (© OpenStreetMap contributors). It may be incomplete or out of date; most facilities aren't mapped, so they show as \"Not verified\". Every mapped dog park counts as an off-leash area, so that filter won't narrow results much.",
                                   "地點來自內建的 OpenStreetMap 快照（© OpenStreetMap contributors），可能不完整或過時；多數設施沒有標註，因此顯示為「未確認」。所有狗公園都標示為可放繩區，所以這個篩選條件影響不大。"))
                }
            }
        }
        .scrollContentBackground(.hidden)
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
