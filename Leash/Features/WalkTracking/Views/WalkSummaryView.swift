import SwiftUI
import MapKit

struct WalkSummaryView: View {
    let walk: Walk
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.appLanguage) private var language

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                RouteMap(walk: walk).frame(height: 300).clipShape(RoundedRectangle(cornerRadius: 24))
                HStack {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        metric(language.text("Duration", "散步時間"), value: WalkFormat.duration(walk.duration(at: context.date)))
                    }
                    metric(language.text("Distance", "散步距離"), value: WalkFormat.distance(walk, locale: language.locale))
                }
                HStack {
                    metric(language.text("💩 Poop", "💩 便便"), value: "\(walk.count(of: .poop))")
                    metric(language.text("💧 Pee", "💧 尿尿"), value: "\(walk.count(of: .pee))")
                }
                Text(walk.startedAt.formatted(.dateTime.locale(language.locale))).font(.caption).foregroundStyle(.secondary)
            }.padding(16)
        }.background(Theme.background(colorScheme))
    }

    private func metric(_ title: String, value: String) -> some View {
        VStack(spacing: 5) {
            Text(value).font(.system(.title2, design: .monospaced))
            Text(title).font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity).padding(14).background(Theme.surface(colorScheme), in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct RouteMap: View {
    let walk: Walk
    @Environment(\.appLanguage) private var language

    var body: some View {
        let segments = walk.segments
        Map {
            ForEach(segments.indices, id: \.self) { index in
                MapPolyline(coordinates: segments[index].map(\.coordinate)).stroke(.orange, lineWidth: 5)
            }
            if let point = walk.route.last {
                Marker(language.text("Current location", "目前位置"), coordinate: point.coordinate)
            }
        }
        .overlay {
            if walk.route.isEmpty {
                Text(language.text("Your route will appear when GPS is available.", "取得 GPS 位置後，路線會顯示在這裡。"))
                    .padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}
