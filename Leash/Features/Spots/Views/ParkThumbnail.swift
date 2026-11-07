import SwiftUI
import MapKit

/// Small preview photo for a park row: Apple's street-level Look Around where it exists,
/// otherwise a satellite image of the park. A badge in the corner says what kind of place it is.
struct ParkThumbnail: View {
    let spot: Spot
    var side: CGFloat = 64
    @Environment(\.colorScheme) private var colorScheme
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12).fill(Theme.line(colorScheme))
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
                    .transition(.opacity)
            } else {
                kindIcon(size: side * 0.4).opacity(0.6)
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(alignment: .bottomTrailing) {
            if image != nil {
                kindIcon(size: 11)
                    .frame(width: 20, height: 20)
                    .background(spot.isDogPark ? Theme.accent : Theme.good, in: Circle())
                    .overlay(Circle().stroke(.white, lineWidth: 1.5))
                    .offset(x: 4, y: 4)
            }
        }
        .animation(.easeOut(duration: 0.2), value: image != nil)
        .task(id: spot.id) { image = await ParkThumbnails.shared.image(for: spot) }
        .accessibilityHidden(true)
    }

    @ViewBuilder private func kindIcon(size: CGFloat) -> some View {
        Image(systemName: ParkMapView.symbol(spot.kind))
            .font(.system(size: size, weight: .bold))
            .foregroundStyle(image == nil ? (spot.isDogPark ? Theme.ink : Theme.good) : .white)
    }
}

/// Renders park previews once per session and shares them between rows.
@MainActor
final class ParkThumbnails {
    static let shared = ParkThumbnails()
    private var images: [String: UIImage] = [:]
    private var loading: [String: Task<UIImage?, Never>] = [:]
    private static let size = CGSize(width: 160, height: 160)

    func image(for spot: Spot) async -> UIImage? {
        if let image = images[spot.id] { return image }
        if let task = loading[spot.id] { return await task.value }
        let task = Task { await Self.render(spot) }
        loading[spot.id] = task
        let image = await task.value
        loading[spot.id] = nil
        if images.count > 400 { images.removeAll() }  // Keep memory small on long scrolls.
        images[spot.id] = image
        return image
    }

    private static func render(_ spot: Spot) async -> UIImage? {
        guard let coordinate = spot.coordinate else { return nil }
        if let scene = await ApplePlaces.lookAround(at: coordinate) {
            let options = MKLookAroundSnapshotter.Options()
            options.size = size
            if let snapshot = try? await MKLookAroundSnapshotter(scene: scene, options: options).snapshot {
                return snapshot.image
            }
        }
        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(center: coordinate, latitudinalMeters: 250, longitudinalMeters: 250)
        options.size = size
        options.preferredConfiguration = MKImageryMapConfiguration()
        return try? await MKMapSnapshotter(options: options).start().image
    }
}
