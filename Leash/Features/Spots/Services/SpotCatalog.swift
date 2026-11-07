import Foundation
import CoreLocation
import Observation

/// Bundled OpenStreetMap dog parks, parks and trails found with Apple Maps, and spots the user added.
@MainActor @Observable
final class SpotCatalog {
    private(set) var bundled: [Spot] = []
    private(set) var custom: [CustomSpot] = []
    /// Apple Maps parks and trails found this session, by id.
    private(set) var nearby: [String: Spot] = [:]
    /// Apple Maps places the user went to or walked at, kept so walks and the Dex can still find them.
    private(set) var saved: [Spot] = []
    private var bundledPosition: [String: Int] = [:]
    /// Map areas already searched this session, so panning back doesn't search again.
    private var searchedCells: Set<String> = []
    private var searchedTexts: Set<String> = []
    private var namingTried: Set<String> = []
    private let savedFile: JSONFile<[SavedPlace]>?
    /// Names found for unnamed dog parks, so they show on the next launch too.
    private static let namesKey = "leash.dogParkNames"
    private var foundNames: [String: String] = UserDefaults.standard.dictionary(forKey: namesKey) as? [String: String] ?? [:]
    private(set) var isLoaded = false
    /// "YYYY-MM-DD" of the OSM data the edit dates were read from.
    private(set) var fetchedOn: String?
    private var index: [String: Spot] = [:]
    private let customFile: JSONFile<[CustomSpot]>?

    var all: [Spot] {
        let savedIDs = Set(saved.map(\.id))
        return bundled + saved + nearby.values.filter { !savedIDs.contains($0.id) } + custom.map(\.spot)
    }

    init(directory: URL?) {
        customFile = directory.map { JSONFile("custom-spots.json", in: $0) }
        savedFile = directory.map { JSONFile("saved-places.json", in: $0) }
        custom = (try? customFile?.load()) ?? []
        saved = ((try? savedFile?.load()) ?? []).map(\.spot)
        reindex()
    }

    /// Decodes the bundled files off the main actor; about 8,500 spots.
    func loadBundled(from bundle: Bundle = .main) async {
        guard !isLoaded else { return }
        let urls = ["spots_tw", "spots_us"].compactMap { bundle.url(forResource: $0, withExtension: "json") }
        let datesURL = bundle.url(forResource: "spots_edited", withExtension: "json")
        let (spots, dates) = await Task.detached(priority: .utility) {
            let dates = datesURL.flatMap(Self.decodeDates)
            return (urls.flatMap { Self.decode($0, edited: dates?.edited ?? [:]) }, dates)
        }.value
        bundled = spots.map { spot in
            var spot = spot
            if spot.hasGenericName, let name = foundNames[spot.id] { spot.name = name }
            return spot
        }
        bundledPosition = Dictionary(bundled.enumerated().map { ($1.id, $0) }, uniquingKeysWith: { first, _ in first })
        fetchedOn = dates.map { String($0.fetched.prefix(10)) }
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

    // MARK: Apple Maps

    /// Adds Apple Maps parks and trails around `center`, and names unnamed dog parks there.
    /// Each ~2 km map cell is searched once per session; Apple Maps limits how often an app may search.
    func loadNearby(around center: CLLocationCoordinate2D) async {
        let cell = String(format: "%.2f,%.2f", (center.latitude * 50).rounded() / 50, (center.longitude * 50).rounded() / 50)
        guard !searchedCells.contains(cell) else { return }
        searchedCells.insert(cell)
        let parks = await ApplePlaces.nearby(center, radius: 2500)
        add(parks + (await ApplePlaces.dogParks(near: center, radius: 2500)))
    }

    /// Adds Apple Maps parks and trails matching typed text, for parks the bundled data doesn't have.
    func search(_ text: String, near center: CLLocationCoordinate2D) async {
        let key = text.trimmingCharacters(in: .whitespaces).lowercased()
        guard key.count >= 2, !searchedTexts.contains(key) else { return }
        searchedTexts.insert(key)
        add(await ApplePlaces.search(key, near: center))
    }

    /// Looks up the park around an unnamed dog park, e.g. when its details are opened.
    func findName(for spot: Spot) async {
        guard spot.hasGenericName, !Self.hasRealName(foundNames[spot.id]), !namingTried.contains(spot.id),
              let coordinate = spot.coordinate else { return }
        namingTried.insert(spot.id)
        let parks = await ApplePlaces.nearby(coordinate, radius: 500)
        add(parks + (await ApplePlaces.dogParks(near: coordinate, radius: 300)))
    }

    /// Keeps an Apple Maps place on the device once the user goes there or walks at it.
    func keep(_ spot: Spot) {
        guard spot.source == .appleMaps, !saved.contains(where: { $0.id == spot.id }) else { return }
        let next = saved + [spot]
        try? savedFile?.save(next.map(SavedPlace.init))
        saved = next
        reindex()
    }

    private func add(_ places: [Spot]) {
        guard !places.isEmpty else { return }
        let dogParks = bundled.filter { $0.location != nil }
        for place in places {
            guard let location = place.location else { continue }
            // Skip Apple's copy of a dog park we already have from OpenStreetMap.
            let duplicate = dogParks.contains { park in
                guard let distance = park.distance(from: location) else { return false }
                return distance < 60 || (distance < 300 && ApplePlaces.looksLikeDogPark(place.name))
            }
            if !duplicate { nearby[place.id] = place }
        }
        nameDogParks(using: places)
        reindex()
    }

    /// Names given from the surrounding park start with this; they describe where the dog park is,
    /// and give way to a real name when Apple Maps has one.
    static let borrowedPrefix = "Dog Park · "
    private static func hasRealName(_ name: String?) -> Bool { name.map { !$0.hasPrefix(borrowedPrefix) } ?? false }

    /// Names unnamed OSM dog parks. Best: Apple's own dog park within 120 m, which has the real name.
    /// Otherwise the park it sits in (nearest Apple park within 350 m), shown as "Dog Park · <park>".
    private func nameDogParks(using places: [Spot]) {
        let named = places.filter { ApplePlaces.looksLikeDogPark($0.name) }
        let parks = places.filter { $0.kind == .park && !ApplePlaces.looksLikeDogPark($0.name) }
        func nearest(_ candidates: [Spot], to location: CLLocation, within meters: Double) -> Spot? {
            candidates.compactMap { place in place.distance(from: location).map { (place, $0) } }
                .filter { $0.1 < meters }.min { $0.1 < $1.1 }?.0
        }
        var changed = false
        for (index, spot) in bundled.enumerated() where spot.hasGenericName && !Self.hasRealName(foundNames[spot.id]) {
            guard let location = spot.location else { continue }
            let name: String
            if let match = nearest(named, to: location, within: 120) {
                name = match.name
            } else if foundNames[spot.id] == nil, let park = nearest(parks, to: location, within: 350) {
                name = Self.borrowedPrefix + park.name
            } else { continue }
            bundled[index].name = name
            foundNames[spot.id] = name
            changed = true
        }
        if changed { UserDefaults.standard.set(foundNames, forKey: Self.namesKey) }
    }

    private func reindex() {
        index = Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    nonisolated struct EditDates: Decodable, Sendable {
        /// When the OSM data was read, as an ISO 8601 timestamp.
        let fetched: String
        /// Raw OSM id (e.g. "w123") to "YYYY-MM-DD".
        let edited: [String: String]
    }

    /// Made by scripts/fetch_spot_dates.py.
    nonisolated static func decodeDates(_ url: URL) -> EditDates? {
        (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode(EditDates.self, from: $0) }
    }

    /// Rows are [id, name, county, area, tagBits, lat, lon, openingHours] plus a US county column.
    nonisolated static func decode(_ url: URL, edited: [String: String] = [:]) -> [Spot] {
        guard let data = try? Data(contentsOf: url),
              let rows = try? JSONSerialization.jsonObject(with: data) as? [[Any]] else { return [] }
        return rows.compactMap { row in
            guard row.count >= 8, let id = row[0] as? String, let rawName = row[1] as? String,
                  let locality = row[2] as? String, let area = row[3] as? String, let bits = row[4] as? Int else { return nil }
            let tags = Set(Spot.Tag.allCases.filter { bits >> $0.rawValue & 1 == 1 })
            let latitude = row[5] as? Double, longitude = row[6] as? Double
            let generic = rawName.hasPrefix("Dog Park · ")
            let name = generic ? "Dog Park" : rawName
            let hours = (row[7] as? String).flatMap { $0.isEmpty ? nil : $0 }
            if row.count >= 9 {
                let state = locality.split(separator: " ").last.map(String.init) ?? ""
                return Spot(id: "osm" + id, name: name, country: .unitedStates, region: state,
                            subregion: row[8] as? String ?? "", address: [area, locality].filter { !$0.isEmpty }.joined(separator: ", "),
                            tags: tags, latitude: latitude, longitude: longitude, openingHours: hours, lastUpdated: edited[id],
                            hasGenericName: generic)
            }
            return Spot(id: "osm" + id, name: name, country: .taiwan, region: locality, subregion: area,
                        address: locality + area, tags: tags, latitude: latitude, longitude: longitude, openingHours: hours,
                        lastUpdated: edited[id])
        }
    }
}

/// An Apple Maps place as kept on the device.
struct SavedPlace: Codable {
    let id: String
    let name: String
    let kind: Spot.Kind
    let country: Spot.Country
    let region: String
    let address: String
    let latitude: Double
    let longitude: Double

    init(_ spot: Spot) {
        id = spot.id; name = spot.name; kind = spot.kind; country = spot.country; region = spot.region
        address = spot.address; latitude = spot.latitude ?? 0; longitude = spot.longitude ?? 0
    }

    var spot: Spot {
        Spot(id: id, name: name, country: country, region: region, subregion: "", address: address, tags: [],
             latitude: latitude, longitude: longitude, source: .appleMaps, kind: kind)
    }
}
