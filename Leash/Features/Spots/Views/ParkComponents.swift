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
        case .usuallyLeashed: language.text("Leash usually required", "通常需牽繩")
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
            ParkThumbnail(spot: spot).padding(.top, 2)
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
                Text(updatedText).font(.caption2).foregroundStyle(Theme.muted)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        if isPlanned {
                            Label(language.text("Next walk", "下次散步"), systemImage: "flag.fill")
                                .font(.caption2).padding(.horizontal, 8).padding(.vertical, 4)
                                .foregroundStyle(Theme.ink).background(Theme.accent, in: Capsule())
                        }
                        if spot.leashPolicy == .offLeashArea { FacilityBadge(tag: .offLeash, status: .available) }
                        if !spot.isDogPark {
                            Text(spot.kind == .trail ? language.text("Trail · leash usually required", "步道 · 通常需牽繩")
                                                     : language.text("Park · leash usually required", "公園 · 通常需牽繩"))
                                .font(.caption2).padding(.horizontal, 8).padding(.vertical, 4)
                                .foregroundStyle(Theme.ink).background(Theme.good.opacity(0.25), in: Capsule())
                        }
                        ForEach(available, id: \.self) { FacilityBadge(tag: $0, status: .available) }
                        if available.isEmpty && spot.isDogPark {
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

    private var updatedText: String {
        if spot.source == .appleMaps { return language.text("Apple Maps", "Apple 地圖") }
        let source = spot.isCustom ? language.text("Added by you", "你新增的") : "OpenStreetMap"
        let date = spot.lastUpdated ?? language.text("date unknown", "日期未知")
        return spot.isCustom ? "\(source) · \(date)" : language.text("\(source) · updated \(date)", "\(source) · 更新於 \(date)")
    }
}

/// One facility and what's known about it. Tapping asks "Is there …?" with Yes / No / Don't know;
/// a red dot marks facilities nobody has settled that the user hasn't answered. Nothing pops up on its own.
struct FacilityReportRow: View {
    let spot: Spot
    let tag: Spot.Tag
    /// Whether the user has been there; only they can answer.
    let canAnswer: Bool
    @Environment(CommunityFacilities.self) private var community
    @Environment(Toaster.self) private var toaster
    @Environment(\.appLanguage) private var language

    var body: some View {
        let status = community.status(of: tag, at: spot)
        let mine = community.mine[spot.id]?[tag]
        let row = HStack {
            Label(tag.label(in: language), systemImage: tag.systemImage)
            Spacer()
            if status.isOpen && mine == nil && answerable {
                Circle().fill(.red).frame(width: 8, height: 8)
                    .accessibilityLabel(language.text("Needs checking", "需要確認"))
            }
            Label(text(status, mine: mine), systemImage: icon(status))
                .labelStyle(.titleAndIcon)
                .foregroundStyle(color(status))
        }
        .font(.subheadline)
        .foregroundStyle(.primary)
        .contentShape(Rectangle())

        if answerable {
            Menu {
                Section(tag.question(in: language)) {
                    answerButton(true, language.text("Yes", "有"), mine: mine)
                    answerButton(false, language.text("No", "沒有"), mine: mine)
                    answerButton(nil, language.text("Don't know", "不知道"), mine: mine)
                }
            } label: { row }
            .tint(.primary)
            .accessibilityHint(language.text("Tap to report what's there", "點一下回報現場情況"))
        } else {
            row.accessibilityElement(children: .combine)
        }
    }

    private var answerable: Bool { canAnswer && community.canReport(on: spot) }

    private func answerButton(_ value: Bool?, _ title: String, mine: Bool?) -> some View {
        Button {
            Task {
                switch await community.report(value, tag: tag, at: spot) {
                case .saved:
                    if value != nil { toaster.show(language.text("Thanks! Shared with other dog owners", "謝謝！已分享給其他飼主")) }
                case .needsICloud:
                    toaster.show(language.text("Sign in to iCloud in Settings to share reports", "到「設定」登入 iCloud 才能分享回報"))
                case .failed:
                    toaster.show(language.text("Didn't send, try again", "沒送出，再試一次"))
                }
            }
        } label: {
            if mine == value && value != nil { Label(title, systemImage: "checkmark") } else { Text(title) }
        }
    }

    private func text(_ status: CommunityFacilities.Status, mine: Bool?) -> String {
        switch status {
        case .mapped: return language.text("Yes", "有")
        case .confirmedYes(let count): return language.text("Yes · \(count) confirmed", "有 · \(count) 人確認")
        case .confirmedNo(let count): return language.text("No · \(count) confirmed", "沒有 · \(count) 人確認")
        case .mixed(let tally):
            if tally.yes + tally.no == 1, let mine {
                return mine ? language.text("You said yes", "你說有") : language.text("You said no", "你說沒有")
            }
            return [tally.yes > 0 ? language.text("\(tally.yes) yes", "\(tally.yes) 人說有") : nil,
                    tally.no > 0 ? language.text("\(tally.no) no", "\(tally.no) 人說沒有") : nil]
                .compactMap { $0 }.joined(separator: " · ")
        case .unknown: return language.text("Not verified", "未確認")
        }
    }

    private func icon(_ status: CommunityFacilities.Status) -> String {
        switch status {
        case .mapped, .confirmedYes: "checkmark.circle.fill"
        case .confirmedNo: "xmark.circle"
        case .mixed, .unknown: "questionmark.circle"
        }
    }

    private func color(_ status: CommunityFacilities.Status) -> Color {
        switch status {
        case .mapped, .confirmedYes: Theme.good
        case .confirmedNo, .mixed, .unknown: Theme.muted
        }
    }
}

/// Collapsed "help check this park" row with a red mark. It opens only when tapped.
struct FacilityPrompt: View {
    let spot: Spot
    @Environment(CommunityFacilities.self) private var community
    @Environment(\.appLanguage) private var language
    @State private var open = false

    var body: some View {
        // Shown after a walk at this place, so the user has been there.
        let unanswered = community.unanswered(at: spot, visited: true)
        Group {
            if !unanswered.isEmpty || open {
                VStack(alignment: .leading, spacing: 10) {
                    Button { withAnimation(.snappy) { open.toggle() } } label: {
                        HStack(spacing: 8) {
                            Image(systemName: unanswered.isEmpty ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                .foregroundStyle(unanswered.isEmpty ? Theme.good : .red)
                            Text(language.text("Help check \(spot.name)", "幫忙確認「\(spot.name)」的設施"))
                                .font(.subheadline.weight(.semibold)).multilineTextAlignment(.leading)
                            Spacer(minLength: 4)
                            Image(systemName: "chevron.down").rotationEffect(.degrees(open ? 180 : 0))
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(language.text("Answer a few quick questions for other dog owners", "回答幾個小問題，幫助其他飼主"))
                    if open {
                        ForEach(Spot.facilities, id: \.self) { FacilityReportRow(spot: spot, tag: $0, canAnswer: true) }
                    }
                }
                .card()
            }
        }
        .task(id: spot.id) { await community.load(spot.id) }
    }
}
