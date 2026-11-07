import SwiftUI
import CoreLocation
import MapKit

/// Bottom sheet for one park: a street-level or aerial preview, leash rules, hours, facilities,
/// Apple's place card (photos, ratings, hours), where the data came from, and Go.
struct ParkDetailView: View {
    let spot: Spot
    let distance: CLLocationDistance?
    let model: WalkViewModel
    let onWalkChanged: () -> Void
    @AppStorage(Spot.plannedStorageKey) private var plannedID = ""
    @Environment(Toaster.self) private var toaster
    @Environment(SpotCatalog.self) private var catalog
    @Environment(CommunityFacilities.self) private var community
    @Environment(GameModel.self) private var game
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.appLanguage) private var language
    @State private var scene: MKLookAroundScene?
    @State private var lookedAround = false
    @State private var placeItem: MKMapItem?
    @State private var showingPlaceCard = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                preview
                VStack(alignment: .leading, spacing: 4) {
                    Text(spot.name).font(.system(.title2, design: .monospaced))
                    if !spot.address.isEmpty { Text(spot.address).font(.subheadline).foregroundStyle(.secondary) }
                    if spot.hasGenericName {
                        Label(spot.name.hasPrefix(SpotCatalog.borrowedPrefix)
                              ? language.text("No official name on record; named after the park it's in", "沒有正式名稱紀錄，以所在公園命名")
                              : spot.name == "Dog Park" ? language.text("No name on record", "沒有名稱紀錄")
                              : language.text("Name from Apple Maps", "名稱來自 Apple 地圖"),
                              systemImage: "info.circle")
                            .font(.caption).foregroundStyle(Theme.muted)
                    }
                    Label(distanceText, systemImage: "location.fill").font(.subheadline).foregroundStyle(.secondary)
                }

                if placeItem != nil {
                    Button { openPlaceCard() } label: {
                        Label(language.text("Photos, ratings & hours", "照片、評分與營業時間"), systemImage: "photo.on.rectangle.angled")
                            .frame(maxWidth: .infinity).padding(.vertical, 6)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityHint(language.text("Shows this place's Apple Maps card", "顯示這個地點的 Apple 地圖資訊"))
                }

                VStack(alignment: .leading, spacing: 10) {
                    infoRow(icon: "figure.run", title: language.text("Leash rules", "放繩規定"), value: leashText,
                            verified: spot.leashPolicy != .unknown)
                    infoRow(icon: "clock.fill", title: language.text("Opening hours", "開放時間"),
                            value: spot.hoursDescription ?? notVerified, verified: spot.hoursDescription != nil)
                    ForEach(Spot.keyFacilities, id: \.self) { FacilityReportRow(spot: spot, tag: $0, canAnswer: visited) }
                }
                .card()

                VStack(alignment: .leading, spacing: 10) {
                    Text(language.text("Other facilities", "其他設施")).font(.headline)
                    ForEach(Spot.otherFacilities, id: \.self) { FacilityReportRow(spot: spot, tag: $0, canAnswer: visited) }
                }
                .card()

                Label(visited
                      ? language.text("\"Not verified\" means no one has recorded it yet, not that the park lacks it. Tap a facility to tell other dog owners what's there.",
                                      "「未確認」表示還沒有人記錄，不代表沒有。點一下設施，告訴其他飼主現場的情況。")
                      : language.text("\"Not verified\" means no one has recorded it yet. After a walk here, you can tell other dog owners what's there.",
                                      "「未確認」表示還沒有人記錄。在這裡散步過後，就能告訴其他飼主現場的情況。"),
                      systemImage: "questionmark.circle")
                    .font(.footnote).foregroundStyle(.secondary)

                sourceCard

                VStack(spacing: 10) {
                    Button(action: go) {
                        Label(language.text("Go", "出發"), systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                            .font(.system(.title3, design: .monospaced).weight(.bold))
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                    }
                    .foregroundStyle(Theme.ink)
                    .background(Theme.accent, in: RoundedRectangle(cornerRadius: 18))
                    .accessibilityHint(language.text("Opens walking directions in Apple Maps and saves this park for your next walk",
                                                     "在 Apple 地圖開啟步行路線，並記住這個地點"))
                    Button(action: walkHere) {
                        Text(model.activeWalk == nil ? language.text("Start walk here now", "現在在這裡開始散步")
                                                     : language.text("I'm at this park", "我在這個地點"))
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                    }
                    .buttonStyle(.bordered).disabled(!model.canWrite)
                }
            }
            .padding(16)
        }
        .background(Theme.background(colorScheme))
        .task { await catalog.findName(for: spot) }
        .task(id: spot.id) { await loadPreview() }
        .task(id: spot.id) { await community.load(spot.id) }
        .modifier(PlaceCardSheet(isPresented: $showingPlaceCard, item: placeItem))
    }

    /// Look Around where Apple has street imagery; otherwise an aerial view of the park.
    @ViewBuilder private var preview: some View {
        if let scene {
            LookAroundPreview(initialScene: scene)
                .frame(height: 170)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .accessibilityLabel(language.text("Street view of the area. Tap to look around.", "附近街景，點一下可環顧四周"))
        } else if lookedAround, let coordinate = spot.coordinate {
            Map(initialPosition: .camera(MapCamera(centerCoordinate: coordinate, distance: 450)), interactionModes: []) {
                Marker(spot.name, systemImage: ParkMapView.symbol(spot.kind), coordinate: coordinate)
                    .tint(ParkMapView.tint(spot.kind))
            }
            .mapStyle(.hybrid)
            .frame(height: 170)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .accessibilityHidden(true)
        } else if spot.coordinate != nil {
            RoundedRectangle(cornerRadius: 18).fill(Theme.line(colorScheme)).frame(height: 170)
                .overlay { ProgressView() }
        }
    }

    private func loadPreview() async {
        guard let coordinate = spot.coordinate else { return }
        scene = await ApplePlaces.lookAround(at: coordinate)
        lookedAround = true
        placeItem = await ApplePlaces.mapItem(for: spot)
    }

    /// Apple's own card inside the app on iOS 18+; on older systems, the place in Apple Maps.
    private func openPlaceCard() {
        if #available(iOS 18, *) {
            showingPlaceCard = true
        } else {
            placeItem?.openInMaps()
        }
    }

    private var distanceText: String {
        distance.map { WalkFormat.distance(meters: $0, locale: language.locale) + language.text(" away", "") }
            ?? language.text("Distance unknown: location is off", "距離未知：未開啟定位")
    }

    private var notVerified: String { language.text("Not verified", "未確認") }

    /// Only people who've been here can report facilities.
    private var visited: Bool {
        CommunityFacilities.hasVisited(spot, walks: model.archive.completed, current: model.currentLocation)
    }

    private var leashText: String {
        switch spot.leashPolicy {
        case .offLeashArea: language.text("Off-leash area (mapped as a dog park)", "可放繩區（標示為狗公園）")
        case .usuallyLeashed: language.text("Leash usually required; check posted rules", "通常需牽繩，請以現場告示為準")
        case .unknown: notVerified
        }
    }

    /// Where this park's info came from and how fresh it is.
    private var sourceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(language.text("Source", "資料來源")).font(.headline)
            switch spot.source {
            case .openStreetMap:
                infoRow(icon: "map", title: language.text("From", "來源"), value: "OpenStreetMap", verified: true)
                infoRow(icon: "pencil", title: language.text("Park last edited", "此地點最後更新"),
                        value: spot.lastUpdated ?? language.text("Unknown", "未知"), verified: spot.lastUpdated != nil)
                infoRow(icon: "arrow.down.circle", title: language.text("Data fetched", "資料擷取日期"),
                        value: catalog.fetchedOn ?? language.text("Unknown", "未知"), verified: catalog.fetchedOn != nil)
                if let url = spot.sourceURL {
                    Link(destination: url) {
                        Label(language.text("View or correct on OpenStreetMap", "在 OpenStreetMap 查看或更正"), systemImage: "arrow.up.right.square")
                    }
                    .font(.subheadline)
                }
                Text(language.text("© OpenStreetMap contributors. Info may be incomplete or out of date; hours and rules can change, so check signs at the park.",
                                   "© OpenStreetMap contributors。資料可能不完整或過時；開放時間與規定可能變動，請以現場告示為準。"))
                    .font(.footnote).foregroundStyle(.secondary)
            case .appleMaps:
                infoRow(icon: "map", title: language.text("From", "來源"), value: language.text("Apple Maps", "Apple 地圖"), verified: true)
                Text(language.text("A park or trail from Apple Maps. It doesn't list dog rules or facilities, so check signs at the park; some don't allow dogs.",
                                   "來自 Apple 地圖的公園或步道。沒有寵物規定與設施資料，請以現場告示為準；部分地點不開放寵物。"))
                    .font(.footnote).foregroundStyle(.secondary)
            case .userAdded:
                infoRow(icon: "person.fill", title: language.text("From", "來源"), value: language.text("Added by you", "你新增的"), verified: true)
                infoRow(icon: "calendar", title: language.text("Added on", "新增日期"),
                        value: spot.lastUpdated ?? language.text("Unknown", "未知"), verified: spot.lastUpdated != nil)
                Text(language.text("Saved on this device only. Directions search Apple Maps by name.", "只存在這台裝置。路線會以名稱在 Apple 地圖搜尋。"))
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .card()
    }

    private func infoRow(icon: String, title: String, value: String, verified: Bool) -> some View {
        HStack(alignment: .top) {
            Label(title, systemImage: icon)
            Spacer()
            Text(value).multilineTextAlignment(.trailing).foregroundStyle(verified ? .primary : Theme.muted)
        }
        .font(.subheadline)
        .accessibilityElement(children: .combine)
    }

    /// Saves the park for the next walk (or the current one) and opens Apple Maps.
    private func go() {
        catalog.keep(spot)
        if model.activeWalk != nil {
            model.setSpot(spot.id)
        } else {
            plannedID = spot.id
            toaster.show(language.text("📍 Saved. Tap Start walk when you arrive", "📍 已記住，抵達後點「開始散步」"))
        }
        MapsLauncher.directions(to: spot)
    }

    private func walkHere() {
        catalog.keep(spot)
        if model.activeWalk == nil {
            model.start(at: spot.id, dogs: game.roster.walking.map(\.id))
            if model.activeWalk != nil { plannedID = "" }
        } else {
            model.setSpot(spot.id)
        }
        guard model.activeWalk?.spotID == spot.id else { return }
        toaster.show("📍 \(spot.name)")
        dismiss()
        onWalkChanged()
    }
}

/// Apple's place card (photos, ratings, hours, phone) as a sheet, where the system supports it.
private struct PlaceCardSheet: ViewModifier {
    @Binding var isPresented: Bool
    let item: MKMapItem?

    func body(content: Content) -> some View {
        if #available(iOS 18, *) {
            content.mapItemDetailSheet(isPresented: $isPresented, item: item, displaysMap: false)
        } else {
            content
        }
    }
}
