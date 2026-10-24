import SwiftUI
import CoreLocation

/// Small pill for one facility. Unverified facilities are never shown as "no".
struct FacilityBadge: View {
    let tag: Spot.Tag
    let status: Spot.FacilityStatus
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.appLanguage) private var language

    var body: some View {
        Label(tag.label(in: language), systemImage: tag.systemImage)
            .font(.caption2)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .foregroundStyle(status == .available ? Theme.ink : Theme.muted)
            .background(status == .available ? Theme.good.opacity(0.35) : Theme.line(colorScheme), in: Capsule())
            .accessibilityLabel("\(tag.label(in: language)), \(status.label(in: language))")
    }
}

extension Spot.FacilityStatus {
    func label(in language: AppLanguage) -> String {
        switch self {
        case .available: language.text("Available", "有")
        case .notVerified: language.text("Not verified", "未確認")
        }
    }
}

extension Spot.LeashPolicy {
    func label(in language: AppLanguage) -> String {
        switch self {
        case .offLeashArea: language.text("Off-leash area", "可放繩區")
        case .unknown: language.text("Leash rules not verified", "牽繩規定未確認")
        }
    }
}

/// Park row for the list: name, address, distance and mapped facilities.
struct ParkRow: View {
    let spot: Spot
    let distance: CLLocationDistance?
    let isPlanned: Bool
    @Environment(\.appLanguage) private var language

    var body: some View {
        let available = Spot.facilities.filter { spot.status($0) == .available }
        HStack(alignment: .top, spacing: 12) {
            PixelIcon(glyph: .map).frame(width: 24, height: 24).padding(.top, 2)
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text(spot.name).font(.headline).lineLimit(2)
                    Spacer(minLength: 4)
                    if let distance {
                        Text(WalkFormat.distance(meters: distance, locale: language.locale))
                            .font(.system(.subheadline, design: .monospaced)).foregroundStyle(.secondary)
                    }
                }
                if !spot.address.isEmpty {
                    Text(spot.address).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        if isPlanned {
                            Label(language.text("Next walk", "下次散步"), systemImage: "flag.fill")
                                .font(.caption2).padding(.horizontal, 8).padding(.vertical, 4)
                                .foregroundStyle(Theme.ink).background(Theme.accent, in: Capsule())
                        }
                        if spot.leashPolicy == .offLeashArea { FacilityBadge(tag: .offLeash, status: .available) }
                        ForEach(available, id: \.self) { FacilityBadge(tag: $0, status: .available) }
                        if available.isEmpty {
                            Text(language.text("Facilities not verified", "設施未確認")).font(.caption2).foregroundStyle(Theme.muted)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(language.text("Shows park details", "查看地點詳情"))
    }
}
