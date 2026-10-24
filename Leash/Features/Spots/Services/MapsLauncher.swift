import MapKit
import UIKit

/// Hands navigation to Apple Maps; Leash does not do turn-by-turn itself.
enum MapsLauncher {
    static func directions(to spot: Spot) {
        guard let coordinate = spot.coordinate else {
            // User-added spots have no coordinates, so let Maps search by name and area.
            var components = URLComponents(string: "maps://")!
            components.queryItems = [URLQueryItem(name: "q", value: [spot.name, spot.address].filter { !$0.isEmpty }.joined(separator: " "))]
            if let url = components.url { UIApplication.shared.open(url) }
            return
        }
        let item: MKMapItem
        if #available(iOS 26, *) {
            item = MKMapItem(location: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude), address: nil)
        } else {
            item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        }
        item.name = spot.name
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
    }
}
