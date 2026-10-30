import SwiftUI
import CoreLocation

/// Bottom sheet for one park: leash rules, hours, facilities, where the data came from, and Go.
struct ParkDetailView: View {
    let spot: Spot
    let distance: CLLocationDistance?
    let model: WalkViewModel
    let onWalkChanged: () -> Void
    @AppStorage(Spot.plannedStorageKey) private var plannedID = ""
    @Environment(Toaster.self) private var toaster
    @Environment(SpotCatalog.self) private var catalog
    @Environment(GameModel.self) private var game
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.appLanguage) private var language

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(spot.name).font(.system(.title2, design: .monospaced))
                    if !spot.address.isEmpty { Text(spot.address).font(.subheadline).foregroundStyle(.secondary) }
                    Label(distanceText, systemImage: "location.fill").font(.subheadline).foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 10) {
                    infoRow(icon: "figure.run", title: language.text("Leash rules", "放繩規定"), value: leashText,
                            verified: spot.leashPolicy != .unknown)
                    infoRow(icon: "clock.fill", title: language.text("Opening hours", "開放時間"),
                            value: spot.hoursDescription ?? notVerified, verified: spot.hoursDescription != nil)
                    ForEach(Spot.keyFacilities, id: \.self) { facilityRow($0) }
                }
                .card()

                VStack(alignment: .leading, spacing: 10) {
                    Text(language.text("Other facilities", "其他設施")).font(.headline)
                    ForEach(Spot.otherFacilities, id: \.self) { facilityRow($0) }
                }
                .card()

                Label(language.text("\"Not verified\" means the source has no record of it, not that the park lacks it.",
                                    "「未確認」表示資料來源沒有記錄，不代表沒有。"), systemImage: "questionmark.circle")
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
    }

    private var distanceText: String {
        distance.map { WalkFormat.distance(meters: $0, locale: language.locale) + language.text(" away", "") }
            ?? language.text("Distance unknown: location is off", "距離未知：未開啟定位")
    }

    private var notVerified: String { language.text("Not verified", "未確認") }

    private var leashText: String {
        switch spot.leashPolicy {
        case .offLeashArea: language.text("Off-leash area (mapped as a dog park)", "可放繩區（標示為狗公園）")
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

    private func facilityRow(_ tag: Spot.Tag) -> some View {
        let status = spot.status(tag)
        return HStack {
            Label(tag.label(in: language), systemImage: tag.systemImage)
            Spacer()
            Label(status.label(in: language), systemImage: status == .available ? "checkmark.circle.fill" : "questionmark.circle")
                .labelStyle(.titleAndIcon)
                .foregroundStyle(status == .available ? Theme.good : Theme.muted)
        }
        .font(.subheadline)
        .accessibilityElement(children: .combine)
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
        if model.activeWalk != nil {
            model.setSpot(spot.id)
        } else {
            plannedID = spot.id
            toaster.show(language.text("📍 Saved. Tap Start walk when you arrive", "📍 已記住，抵達後點「開始散步」"))
        }
        MapsLauncher.directions(to: spot)
    }

    private func walkHere() {
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
