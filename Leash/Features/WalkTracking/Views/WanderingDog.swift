import SwiftUI

struct WanderingDog: View {
    let outdoors: Bool
    let name: String
    var breed = Breed.named("mixy")
    var scarf: UInt32 = DogProfile.scarves[0]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var position = CGPoint(x: 0.4, y: 0.66)
    @State private var facingLeft = false
    @State private var walking = false

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width * 0.20, 100)
            VStack(spacing: 4) {
                TimelineView(.animation(minimumInterval: 0.15, paused: reduceMotion || scenePhase != .active)) { context in
                    let beat = Int(context.date.timeIntervalSinceReferenceDate * (walking ? 4 : 1.25)) % 2
                    PixelDog(breed: breed, scarf: scarf).frame(width: side, height: side)
                        .scaleEffect(x: facingLeft ? -1 : 1, y: 1)
                        .offset(y: reduceMotion ? 0 : (beat == 0 ? 0 : -3))
                }
                Text(name).font(.system(.caption, design: .monospaced))
                    .padding(.horizontal, 9).padding(.vertical, 2)
                    .foregroundStyle(.white)
                    .background(Theme.overlay, in: RoundedRectangle(cornerRadius: 7))
            }
            .position(x: geometry.size.width * position.x, y: geometry.size.height * position.y)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task(id: "\(outdoors)-\(reduceMotion)-\(scenePhase)") {
            guard !reduceMotion, scenePhase == .active else { walking = false; return }
            do {
                while !Task.isCancelled {
                    try await Task.sleep(for: .seconds(Double.random(in: 1.5...3.5)))
                    let target = CGPoint(x: Double.random(in: 0.18...0.80), y: Double.random(in: 0.58...0.72))
                    facingLeft = target.x < position.x
                    walking = true
                    withAnimation(.linear(duration: 2.2)) { position = target }
                    try await Task.sleep(for: .seconds(2.2))
                    walking = false
                }
            } catch { walking = false }
        }
    }
}
