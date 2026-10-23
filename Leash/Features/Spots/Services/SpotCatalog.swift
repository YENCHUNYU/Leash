import Foundation
import CoreLocation
import Observation

/// Bundled OpenStreetMap dog parks plus spots the user added.
@MainActor @Observable
final class SpotCatalog {
    private(set) var bundled: [Spot] = []
    private(set) var custom: [CustomSpot] = []
    private(set) var isLoaded = false
    private var index: [String: Spot] = [:]
    private let customFile: JSONFile<[CustomSpot]>?

    var all: [Spot] { bundled + custom.map(\.spot) }

    init(directory: URL?) {
        customFile = directory.map { JSONFile("custom-spots.json", in: $0) }
        custom = (try? customFile?.load()) ?? []
        reindex()
    }

    /// Decodes the bundled files off the main actor; about 8,500 spots.
    func loadBundled(from bundle: Bundle = .main) async {
        guard !isLoaded else { return }
        let urls = ["spots_tw", "spots_us"].compactMap { bundle.url(forResource: $0, withExtension: "json") }
        bundled = await Task.detached(priority: .utility) { urls.flatMap(Self.decode) }.value
        isLoaded = true
        reindex()
    }

    func spot(id: String?) -> Spot? { id.flatMap { index[$0] } }

    func add(_ spot: CustomSpot) throws {
        let next = custom + [spot]
        try customFile?.save(next)
        custom = next
        reindex()
    }

    private func reindex() {
        index = Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    /// Rows are [id, name, county, area, tagBits, lat, lon, note] plus a US county column.
    nonisolated static func decode(_ url: URL) -> [Spot] {
        guard let data = try? Data(contentsOf: url),
              let rows = try? JSONSerialization.jsonObject(with: data) as? [[Any]] else { return [] }
        return rows.compactMap { row in
            guard row.count >= 8, let id = row[0] as? String, let rawName = row[1] as? String,
                  let locality = row[2] as? String, let area = row[3] as? String, let bits = row[4] as? Int else { return nil }
            let tags = Set(Spot.Tag.allCases.filter { bits >> $0.rawValue & 1 == 1 })
            let latitude = row[5] as? Double, longitude = row[6] as? Double
            let name = rawName.hasPrefix("Dog Park · ") ? "Dog Park" : rawName
            if row.count >= 9 {
                let state = locality.split(separator: " ").last.map(String.init) ?? ""
                return Spot(id: "osm" + id, name: name, country: .unitedStates, region: state,
                            subregion: row[8] as? String ?? "", detail: [locality, area].filter { !$0.isEmpty }.joined(separator: " · "),
                            tags: tags, latitude: latitude, longitude: longitude)
            }
            return Spot(id: "osm" + id, name: name, country: .taiwan, region: locality, subregion: area,
                        detail: area, tags: tags, latitude: latitude, longitude: longitude)
        }
    }
}
