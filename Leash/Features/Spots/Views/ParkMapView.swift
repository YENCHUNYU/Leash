import SwiftUI
import MapKit

/// Parks as tappable markers around the user. Only parks in view are drawn, nearest to the center first.
struct ParkMapView: View {
    let parks: [Spot]
    let userLocation: CLLocation?
    let fallbackCenter: CLLocation
    let plannedID: String?
    @Binding var selection: String?
    @Environment(\.appLanguage) private var language
    @State private var position = MapCameraPosition.automatic
    @State private var region: MKCoordinateRegion?
    @State private var centeredOnUser = false

    static let markerLimit = 150

    var body: some View {
        let visible = visibleParks
        Map(position: $position, selection: $selection) {
            UserAnnotation()
            ForEach(visible) { park in
                if let coordinate = park.coordinate {
                    Marker(park.name, systemImage: park.id == plannedID ? "flag.fill" : "pawprint.fill", coordinate: coordinate)
                        .tint(park.id == plannedID ? Theme.good : Theme.accent)
                        .tag(park.id)
                }
            }
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass()
            MapScaleView()
        }
        .onMapCameraChange(frequency: .onEnd) { region = $0.region }
        .overlay(alignment: .bottom) {
            if visible.count >= Self.markerLimit {
                Text(language.text("Showing the \(Self.markerLimit) parks nearest the map center. Zoom in for more.",
                                   "顯示離地圖中心最近的 \(Self.markerLimit) 個地點，放大可看更多。"))
                    .font(.caption).padding(.horizontal, 12).padding(.vertical, 6)
                    .background(.regularMaterial, in: Capsule()).padding(.bottom, 10)
            }
        }
        .onAppear { recenter() }
        .onChange(of: userLocation == nil) { recenter() }
        .onChange(of: fallbackCenter.coordinate.latitude) { centeredOnUser = false; recenter() }
    }

    private var visibleParks: [Spot] {
        let center = region?.center ?? (userLocation ?? fallbackCenter).coordinate
        let span = region?.span ?? MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        let origin = CLLocation(latitude: center.latitude, longitude: center.longitude)
        return parks
            .filter { park in
                guard let coordinate = park.coordinate else { return false }
                return abs(coordinate.latitude - center.latitude) <= span.latitudeDelta * 0.6
                    && abs(coordinate.longitude - center.longitude) <= span.longitudeDelta * 0.6
            }
            .map { ($0, $0.distance(from: origin) ?? .infinity) }
            .sorted { $0.1 < $1.1 }
            .prefix(Self.markerLimit)
            .map(\.0)
    }

    /// Centers on the user once their location is known, otherwise on the fallback point.
    private func recenter() {
        guard !centeredOnUser else { return }
        if let userLocation {
            centeredOnUser = true
            position = .region(MKCoordinateRegion(center: userLocation.coordinate, latitudinalMeters: 6000, longitudinalMeters: 6000))
        } else {
            position = .region(MKCoordinateRegion(center: fallbackCenter.coordinate, latitudinalMeters: 30000, longitudinalMeters: 30000))
        }
    }
}
