import Foundation
import MapKit

/// Finds parks and trails with Apple Maps. Free, needs no key, and returns real place names,
/// but has no dog rules or facilities, so results are shown as "usually on leash, check signs".
enum ApplePlaces {
    /// Trails are a category from iOS 18; older systems find parks only.
    static var categories: [MKPointOfInterestCategory] {
        if #available(iOS 18, *) { return [.park, .hiking, .nationalPark] }
        return [.park, .nationalPark]
    }

    /// Parks and trails within `radius` meters of `center`.
    static func nearby(_ center: CLLocationCoordinate2D, radius: CLLocationDistance) async -> [Spot] {
        let request = MKLocalPointsOfInterestRequest(center: center, radius: radius)
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: categories)
        return await run(MKLocalSearch(request: request))
    }

    /// Parks and trails whose name matches `text`, searched around `center`.
    static func search(_ text: String, near center: CLLocationCoordinate2D) async -> [Spot] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = text
        request.resultTypes = .pointOfInterest
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: categories)
        request.region = MKCoordinateRegion(center: center, latitudinalMeters: 60_000, longitudinalMeters: 60_000)
        return await run(MKLocalSearch(request: request))
    }

    /// Places Apple names as dog parks around `center`. Apple often has the real name that OpenStreetMap lacks.
    static func dogParks(near center: CLLocationCoordinate2D, radius: CLLocationDistance) async -> [Spot] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "dog park"
        request.resultTypes = .pointOfInterest
        request.region = MKCoordinateRegion(center: center, latitudinalMeters: radius * 2, longitudinalMeters: radius * 2)
        return await run(MKLocalSearch(request: request)).filter { looksLikeDogPark($0.name) }
    }

    private static func run(_ search: MKLocalSearch) async -> [Spot] {
        // Throttled or offline: just show what we already have.
        guard let response = try? await search.start() else { return [] }
        return response.mapItems.compactMap(spot)
    }

    private static func spot(_ item: MKMapItem) -> Spot? {
        guard let name = item.name, !name.isEmpty else { return nil }
        let coordinate: CLLocationCoordinate2D
        let full: String, city: String, short: String?
        if #available(iOS 26, *) {
            coordinate = item.location.coordinate
            full = item.address?.fullAddress ?? ""
            city = item.addressRepresentations?.cityWithContext ?? ""
            short = item.address?.shortAddress
        } else {
            let place = item.placemark
            coordinate = place.coordinate
            city = [place.locality, place.administrativeArea].compactMap { $0 }.joined(separator: ", ")
            full = [place.administrativeArea, place.locality, place.subLocality, place.thoroughfare].compactMap { $0 }.joined(separator: " ")
            short = [place.thoroughfare, place.locality].compactMap { $0 }.joined(separator: ", ")
        }
        let county = Regions.taiwanCounty(in: full + city)
        // "Irvine, CA" → "CA".
        let state = city.split(separator: ",").last.map { $0.trimmingCharacters(in: .whitespaces) }
            .flatMap { Regions.unitedStates[$0] == nil ? nil : $0 }
        var identifier: String?
        var isTrail = false
        if #available(iOS 18, *) {
            identifier = item.identifier?.rawValue
            isTrail = item.pointOfInterestCategory == .hiking
        }
        let id = identifier ?? String(format: "%.5f,%.5f", coordinate.latitude, coordinate.longitude)
        return Spot(id: "apple:" + id, name: name, country: county == nil ? .unitedStates : .taiwan,
                    region: county ?? state ?? "", subregion: "",
                    address: (short?.isEmpty == false ? short : nil) ?? city, tags: [],
                    latitude: coordinate.latitude, longitude: coordinate.longitude,
                    source: .appleMaps, kind: isTrail ? .trail : .park)
    }

    // MARK: Where the user is

    /// The user's city as typed in an address, plus country and state or county, e.g. ("Irvine, CA", .unitedStates, "CA").
    static func area(at location: CLLocation) async -> (text: String, country: Spot.Country, region: String)? {
        let city: String, full: String, isTaiwan: Bool
        if #available(iOS 26, *) {
            guard let request = MKReverseGeocodingRequest(location: location),
                  let item = try? await request.mapItems.first else { return nil }
            city = item.addressRepresentations?.cityWithContext ?? ""
            full = item.address?.fullAddress ?? ""
            isTaiwan = Regions.taiwanCounty(in: full + city) != nil
        } else {
            guard let place = try? await CLGeocoder().reverseGeocodeLocation(location).first else { return nil }
            isTaiwan = place.isoCountryCode == "TW"
            city = isTaiwan ? [place.administrativeArea, place.locality ?? place.subLocality].compactMap { $0 }.joined()
                            : [place.locality, place.administrativeArea].compactMap { $0 }.joined(separator: ", ")
            full = city
        }
        if isTaiwan {
            let county = Regions.taiwanCounty(in: full + city) ?? ""
            return (city.isEmpty ? county : city, .taiwan, county)
        }
        let state = city.split(separator: ",").last.map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
        return (city, .unitedStates, Regions.unitedStates[state] == nil ? "" : state)
    }

    // MARK: Place card

    /// The Apple Maps place for a spot, whose card has photos, ratings, hours and phone.
    /// Apple places are fetched by id; others are matched by name within 200 m.
    static func mapItem(for spot: Spot) async -> MKMapItem? {
        guard let coordinate = spot.coordinate else { return nil }
        if #available(iOS 18, *), spot.source == .appleMaps,
           let id = MKMapItem.Identifier(rawValue: String(spot.id.dropFirst("apple:".count))),
           let item = try? await MKMapItemRequest(mapItemIdentifier: id).mapItem {
            return item
        }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = spot.hasGenericName ? "dog park" : spot.name
        request.resultTypes = .pointOfInterest
        request.region = MKCoordinateRegion(center: coordinate, latitudinalMeters: 1000, longitudinalMeters: 1000)
        guard let items = try? await MKLocalSearch(request: request).start().mapItems else { return nil }
        let here = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return items.map { ($0, location(of: $0).distance(from: here)) }
            .filter { $0.1 < 200 }
            .min { $0.1 < $1.1 }?.0
    }

    /// A street-level Look Around view near the spot, where Apple has one.
    static func lookAround(at coordinate: CLLocationCoordinate2D) async -> MKLookAroundScene? {
        try? await MKLookAroundSceneRequest(coordinate: coordinate).scene
    }

    private static func location(of item: MKMapItem) -> CLLocation {
        if #available(iOS 26, *) { return item.location }
        return item.placemark.location ?? CLLocation(latitude: item.placemark.coordinate.latitude,
                                                     longitude: item.placemark.coordinate.longitude)
    }

    /// Apple lists many dog parks as plain parks; those duplicate the OpenStreetMap ones.
    static func looksLikeDogPark(_ name: String) -> Bool {
        let lower = name.lowercased()
        return ["dog", "bark", "canine", "狗", "犬", "寵物"].contains { lower.contains($0) }
    }
}
