import SwiftUI
import CoreLocation

/// Bottom sheet for one park: facilities, leash rules, hours, and Go.
struct ParkDetailView: View {
    let spot: Spot
    let distance: CLLocationDistance?
    let model: WalkViewModel
    let onWalkChanged: () -> Void
    @AppStorage(Spot.plannedStorageKey) private var plannedID = ""
    @Environment(Toaster.self) private var toaster
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
                    infoRow(icon: "figure.run", title: language.text("Leash rules", "牽繩規定"), value: leashText,
                            verified: spot.leashPolicy != .unknown)
                    infoRow(icon: "clock.fill", title: language.text("Opening hours", "開放時間"),
                            value: spot.hoursDescription ?? language.text("Unknown", "未知"), verified: spot.hoursDescription != nil)
                }
                .card()

                VStack(alignment: .leading, spacing: 10) {
                    Text(language.text("Facilities", "設施")).font(.headline)
                    ForEach(Spot.facilities, id: \.self) { tag in
                        let status = spot.status(tag)
                        HStack {
                            Label(tag.label(in: language), systemImage: tag.systemImage)
                            Spacer()
                            Label(status.label(in: language), systemImage: status == .available ? "checkmark.circle.fill" : "questionmark.circle")
                                .labelStyle(.titleAndIcon)
                                .foregroundStyle(status == .available ? Theme.good : Theme.muted)
                        }
                        .font(.subheadline)
                        .accessibilityElement(children: .combine)
                    }
                }
                .card()

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

                Text(sourceNote).font(.footnote).foregroundStyle(.secondary)
            }
            .padding(16)
        }
        .background(Theme.background(colorScheme))
    }

    private var distanceText: String {
        distance.map { WalkFormat.distance(meters: $0, locale: language.locale) + language.text(" away", "") }
            ?? language.text("Distance unknown: location is off", "距離未知：未開啟定位")
    }

    private var leashText: String {
        switch spot.leashPolicy {
        case .offLeashArea: language.text("Off-leash area (mapped as a dog park)", "可放繩區（標示為狗公園）")
        case .unknown: language.text("Not verified", "未確認")
        }
    }

    private var sourceNote: String {
        switch spot.source {
        case .openStreetMap:
            language.text("From a bundled OpenStreetMap snapshot (© OpenStreetMap contributors). Facilities marked \"Not verified\" may still exist; hours and rules can change, so check signs at the park.",
                          "資料來自內建的 OpenStreetMap 快照（© OpenStreetMap contributors）。標示「未確認」的設施仍可能存在；開放時間與規定可能變動，請以現場告示為準。")
        case .userAdded:
            language.text("Added by you on this device. Directions search Apple Maps by name.", "你在這台裝置新增的地點。路線會以名稱在 Apple 地圖搜尋。")
        }
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
            model.start(at: spot.id)
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
