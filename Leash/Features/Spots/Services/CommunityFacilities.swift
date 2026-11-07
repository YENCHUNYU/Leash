import Foundation
import CloudKit
import CoreLocation
import Observation

/// What Leash users report about a park's facilities, shared with everyone through the CloudKit public database.
///
/// Each answer is one `FacilityVote` record named "<park>|<facility>|<user>", so a person has one vote per
/// facility and changing it overwrites the old one. Public records can only be edited by whoever made them.
/// Reading needs no account; reporting needs the user signed in to iCloud. Users don't need iCloud storage
/// or a subscription: public data counts against the app's CloudKit quota.
///
/// Before release, in CloudKit Console: make `parkID` Queryable on `FacilityVote`, then deploy the schema to Production.
@MainActor @Observable
final class CommunityFacilities {
    struct Tally: Equatable {
        var yes = 0
        var no = 0
    }

    /// What a facility row shows, combining the map data with community answers.
    enum Status: Equatable {
        /// Recorded in the map data.
        case mapped
        case confirmedYes(Int)
        case confirmedNo(Int)
        /// Some answers, not enough to agree yet.
        case mixed(Tally)
        case unknown

        /// Still worth asking about.
        var isOpen: Bool {
            switch self {
            case .mixed, .unknown: true
            case .mapped, .confirmedYes, .confirmedNo: false
            }
        }
    }

    enum ReportResult { case saved, needsICloud, failed }

    static let containerID = "iCloud.com.Leash.ios"
    static let recordType = "FacilityVote"
    /// At least this many people, and twice as many as disagree, before a facility shows as yes or no.
    nonisolated static let confirmations = 2
    private static let mineKey = "leash.myFacilityAnswers"

    private(set) var tallies: [String: [Spot.Tag: Tally]] = [:]
    /// The user's own answers by park, also kept on the device so they show at once and offline.
    private(set) var mine: [String: [Spot.Tag: Bool]]
    @ObservationIgnored private var loadedAt: [String: Date] = [:]
    @ObservationIgnored private var userName: String?
    @ObservationIgnored private var cachedContainer: CKContainer?
    /// Off in tests and previews, which have no iCloud container.
    private let isEnabled: Bool

    init(isEnabled: Bool = true) {
        self.isEnabled = isEnabled
        mine = Self.loadMine()
    }

    /// Created on first use: a container the app isn't entitled to would crash at launch.
    private var container: CKContainer {
        if let cachedContainer { return cachedContainer }
        let container = CKContainer(identifier: Self.containerID)
        cachedContainer = container
        return container
    }

    func status(of tag: Spot.Tag, at spot: Spot) -> Status {
        if spot.status(tag) == .available { return .mapped }
        var tally = tallies[spot.id]?[tag] ?? Tally()
        if let answer = mine[spot.id]?[tag] {
            if answer { tally.yes += 1 } else { tally.no += 1 }
        }
        return Self.status(of: tally)
    }

    nonisolated static func status(of tally: Tally) -> Status {
        if tally.yes >= confirmations, tally.yes >= 2 * tally.no { return .confirmedYes(tally.yes) }
        if tally.no >= confirmations, tally.no >= 2 * tally.yes { return .confirmedNo(tally.no) }
        return tally.yes + tally.no > 0 ? .mixed(tally) : .unknown
    }

    /// Whether the app may ask about this place: real places, not ones the user typed in.
    func canReport(on spot: Spot) -> Bool { !spot.isCustom && spot.id != Spot.indoorID }

    /// Only people who've been there can report, which keeps answers honest. Being there means:
    /// nearby right now, or a diary walk linked to the place or passing close to it. Walks never expire,
    /// so someone who remembers at home, or days later, can still answer.
    nonisolated static let nearbyNow: CLLocationDistance = 300
    nonisolated static let routeNearby: CLLocationDistance = 150

    nonisolated static func hasVisited(_ spot: Spot, walks: [Walk], current: CLLocation?) -> Bool {
        guard let place = spot.location else { return false }
        if let current, current.distance(from: place) <= nearbyNow { return true }
        if walks.contains(where: { $0.spotID == spot.id }) { return true }
        // Cheap box check first; most walks are nowhere near.
        let margin = 0.002
        return walks.contains { walk in
            walk.route.contains { point in
                abs(point.latitude - place.coordinate.latitude) < margin
                    && abs(point.longitude - place.coordinate.longitude) < margin
                    && CLLocation(latitude: point.latitude, longitude: point.longitude).distance(from: place) <= routeNearby
            }
        }
    }

    /// Facilities still open at `spot` that the user hasn't answered. Only ask people who've been there.
    func unanswered(at spot: Spot, visited: Bool) -> [Spot.Tag] {
        guard visited, canReport(on: spot) else { return [] }
        return Spot.facilities.filter { mine[spot.id]?[$0] == nil && status(of: $0, at: spot).isOpen }
    }

    /// Fetches everyone's answers for one park, at most every ten minutes.
    func load(_ parkID: String) async {
        guard isEnabled else { return }
        if let last = loadedAt[parkID], Date.now.timeIntervalSince(last) < 600 { return }
        loadedAt[parkID] = .now
        if userName == nil { userName = try? await container.userRecordID().recordName }
        let query = CKQuery(recordType: Self.recordType, predicate: NSPredicate(format: "parkID == %@", parkID))
        var counts: [Spot.Tag: Tally] = [:]
        do {
            var page = try await container.publicCloudDatabase.records(matching: query, resultsLimit: 200)
            while true {
                for (id, result) in page.matchResults {
                    // The user's own vote is counted from `mine`, which is always current.
                    if let userName, id.recordName.hasSuffix("|" + userName) { continue }
                    guard let record = try? result.get(), let key = record["facility"] as? String,
                          let tag = Spot.Tag(key: key), let value = record["value"] as? Int64 else { continue }
                    if value == 1 { counts[tag, default: Tally()].yes += 1 } else { counts[tag, default: Tally()].no += 1 }
                }
                guard let cursor = page.queryCursor else { break }
                page = try await container.publicCloudDatabase.records(continuingMatchFrom: cursor, resultsLimit: 200)
            }
            tallies[parkID] = counts
        } catch {
            // Offline, or the record type doesn't exist yet: try again on the next visit after a minute.
            loadedAt[parkID] = Date.now.addingTimeInterval(-540)
        }
    }

    /// Saves the user's answer (`nil` for "don't know", which removes it) and shares it.
    func report(_ answer: Bool?, tag: Spot.Tag, at spot: Spot) async -> ReportResult {
        guard canReport(on: spot) else { return .failed }
        let previous = mine[spot.id]?[tag]
        setMine(answer, tag: tag, park: spot.id)
        guard isEnabled else { return .saved }
        do {
            guard try await container.accountStatus() == .available else {
                setMine(previous, tag: tag, park: spot.id)
                return .needsICloud
            }
            let user: String
            if let userName { user = userName } else {
                user = try await container.userRecordID().recordName
                userName = user
            }
            let id = CKRecord.ID(recordName: "\(spot.id)|\(tag.key)|\(user)")
            if let answer {
                let record = CKRecord(recordType: Self.recordType, recordID: id)
                record["parkID"] = spot.id
                record["facility"] = tag.key
                record["value"] = Int64(answer ? 1 : 0)
                _ = try await container.publicCloudDatabase.modifyRecords(saving: [record], deleting: [], savePolicy: .allKeys)
            } else {
                _ = try await container.publicCloudDatabase.modifyRecords(saving: [], deleting: [id])
            }
            return .saved
        } catch {
            setMine(previous, tag: tag, park: spot.id)
            return .failed
        }
    }

    private func setMine(_ answer: Bool?, tag: Spot.Tag, park: String) {
        var answers = mine[park] ?? [:]
        answers[tag] = answer
        mine[park] = answers.isEmpty ? nil : answers
        let stored = mine.mapValues { Dictionary(uniqueKeysWithValues: $0.map { ($0.key.key, $0.value) }) }
        UserDefaults.standard.set(stored, forKey: Self.mineKey)
    }

    private static func loadMine() -> [String: [Spot.Tag: Bool]] {
        let stored = UserDefaults.standard.dictionary(forKey: mineKey) as? [String: [String: Bool]] ?? [:]
        return stored.mapValues { answers in
            Dictionary(uniqueKeysWithValues: answers.compactMap { key, value in Spot.Tag(key: key).map { ($0, value) } })
        }
    }
}

extension Spot.Tag {
    /// Stable name stored in CloudKit and on the device; the raw value is a bit position in the bundled data.
    var key: String {
        switch self {
        case .fence: "fence"
        case .zone: "zone"
        case .water: "water"
        case .wash: "wash"
        case .bag: "bag"
        case .shade: "shade"
        case .offLeash: "offLeash"
        case .grass: "grass"
        case .allDay: "allDay"
        case .free: "free"
        }
    }

    init?(key: String) {
        guard let tag = Self.allCases.first(where: { $0.key == key }) else { return nil }
        self = tag
    }

    /// The question asked when the user taps an unconfirmed facility.
    func question(in language: AppLanguage) -> String {
        switch self {
        case .water: language.text("Is there drinking water?", "這裡有飲水嗎？")
        case .fence: language.text("Is it fenced?", "這裡有圍欄嗎？")
        case .zone: language.text("Separate small and large dog areas?", "有分大小型犬區嗎？")
        case .bag: language.text("Waste bags or bins?", "有便袋或垃圾桶嗎？")
        case .shade: language.text("Is there shade?", "有遮蔭的地方嗎？")
        case .wash: language.text("Is there a dog wash?", "有洗狗設備嗎？")
        case .offLeash: language.text("Can dogs be off leash?", "可以放繩嗎？")
        case .grass: language.text("Is there grass?", "有草地嗎？")
        case .allDay: language.text("Open 24 hours?", "24 小時開放嗎？")
        case .free: language.text("Is it free?", "免費嗎？")
        }
    }
}
