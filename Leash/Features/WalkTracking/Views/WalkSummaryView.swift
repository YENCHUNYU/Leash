import SwiftUI
import MapKit

struct WalkSummaryView<Footer: View>: View {
    let walk: Walk
    @ViewBuilder var footer: Footer
    @Environment(PhotoLibrary.self) private var photos
    @Environment(SpotCatalog.self) private var spots
    @Environment(GameModel.self) private var game
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.appLanguage) private var language

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if walk.isIndoor {
                    Label(walk.indoorActivity ?? "", systemImage: "house.fill").card()
                } else {
                    RouteMap(walk: walk).frame(height: 280).clipShape(RoundedRectangle(cornerRadius: 24))
                }
                Text("\(walk.startedAt.formatted(.dateTime.locale(language.locale))) · \(WalkFormat.spotName(walk, spots: spots, language: language))")
                    .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                // After a walk at a park: a quiet, collapsed way to tell others what's there.
                if walk.endedAt != nil, let spot = spots.spot(id: walk.spotID), spot.coordinate != nil {
                    FacilityPrompt(spot: spot)
                }
                HStack {
                    metric(language.text("Distance", "距離"), value: WalkFormat.distance(walk, locale: language.locale))
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        metric(language.text("Time", "時間"), value: WalkFormat.duration(walk.duration(at: context.date)))
                    }
                    metric(language.text("Pace", "配速"), value: WalkFormat.pace(walk, locale: language.locale))
                }
                HStack {
                    metric(language.text("💩 Poop", "💩 便便"), value: "\(walk.count(of: .poop))")
                    metric(language.text("💧 Pee", "💧 尿尿"), value: "\(walk.count(of: .pee))")
                    metric(language.text("📷 Photo", "📷 拍照"), value: "\(walk.photoIDs.count)")
                }
                if !walk.isIndoor { dogs }
                if let note = walk.note {
                    Text(note).frame(maxWidth: .infinity, alignment: .leading).card()
                }
                let walkPhotos = walk.photoIDs.compactMap(photos.photo(id:))
                if !walkPhotos.isEmpty {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                        ForEach(walkPhotos) { PhotoThumbnail(photo: $0) }
                    }
                }
                footer
                if !walk.isIndoor {
                    Text(language.text("Routes stay on this device.", "路線只存在這台裝置，不會公開。"))
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }.padding(16)
        }.background(Theme.background(colorScheme))
    }

    /// Who came along; with several dogs, each one's pee and poop.
    private var dogs: some View {
        let dogs = game.dogs(on: walk)
        return VStack(alignment: .leading, spacing: 8) {
            ForEach(dogs) { dog in
                HStack(spacing: 8) {
                    PixelDog(breed: dog.breed, scarf: dog.scarf, look: dog.look, accessory: dog.accessory).frame(width: 32, height: 32)
                    Text(dog.displayName(in: language)).font(.system(.subheadline, design: .monospaced))
                    Spacer()
                    if dogs.count > 1 {
                        Text("💩 \(walk.count(of: .poop, dog: dog.id))  💧 \(walk.count(of: .pee, dog: dog.id))")
                            .font(.system(.subheadline, design: .monospaced)).foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
        .card()
    }

    private func metric(_ title: String, value: String) -> some View {
        VStack(spacing: 5) {
            Text(value).font(.system(.title3, design: .monospaced)).lineLimit(1).minimumScaleFactor(0.5)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity).padding(12).background(Theme.surface(colorScheme), in: RoundedRectangle(cornerRadius: 16))
    }
}

extension WalkSummaryView where Footer == EmptyView {
    init(walk: Walk) { self.init(walk: walk) { EmptyView() } }
}

private struct RouteMap: View {
    let walk: Walk
    @Environment(\.appLanguage) private var language
    @State private var drawing: (outlines: [[CLLocationCoordinate2D]], pieces: [RouteDrawing.Piece]) = ([], [])

    var body: some View {
        let line = StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)
        Map {
            // A soft white edge under the colors keeps the line readable on any map.
            ForEach(drawing.outlines.indices, id: \.self) { index in
                MapPolyline(coordinates: drawing.outlines[index])
                    .stroke(.white.opacity(0.85), style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round))
            }
            ForEach(drawing.pieces.indices, id: \.self) { index in
                let piece = drawing.pieces[index]
                MapPolyline(coordinates: piece.coordinates).stroke(Color(leashHex: RouteDrawing.color(heat: piece.heat)), style: line)
            }
            if let first = walk.route.first, walk.endedAt != nil {
                Annotation(language.text("Start", "起點"), coordinate: first.coordinate, anchor: .center) { dot(0x3DBE4C, label: language.text("Start", "起點")) }
                    .annotationTitles(.hidden)
            }
            if let last = walk.route.last {
                if walk.endedAt != nil {
                    Annotation(language.text("End", "終點"), coordinate: last.coordinate, anchor: .center) { dot(0xE2453C, label: language.text("End", "終點")) }
                        .annotationTitles(.hidden)
                } else {
                    Marker(language.text("Current location", "目前位置"), coordinate: last.coordinate)
                }
            }
        }
        .task(id: walk.route) { drawing = RouteDrawing.pieces(for: walk) }
        .overlay {
            if walk.route.isEmpty {
                Text(language.text("No route this time. Your route appears when GPS is available.", "這次沒有記到路線。取得 GPS 位置後，路線會顯示在這裡。"))
                    .multilineTextAlignment(.center)
                    .padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12)).padding()
            }
        }
    }

    /// A dot centered on the point, with a small label under it that doesn't shift the dot.
    private func dot(_ color: UInt32, label: String) -> some View {
        Circle().fill(Color(leashHex: color)).frame(width: 14, height: 14)
            .overlay(Circle().stroke(.white, lineWidth: 3))
            .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
            .overlay(alignment: .top) {
                Text(label)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(Color(leashHex: color), in: Capsule())
                    .overlay(Capsule().stroke(.white, lineWidth: 1.5))
                    .fixedSize()
                    .offset(y: 18)
            }
    }
}
