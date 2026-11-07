import SwiftUI

/// A dog walking around the room or park. How much it moves depends on its personality.
/// Tap to pet it (it hops, smiles and hearts float up); drag to pick it up by the scruff and put it somewhere else.
struct WanderingDog: View {
    /// Spreads several dogs across the floor so they don't start on top of each other.
    static func start(_ index: Int, of count: Int) -> CGPoint {
        guard count > 1 else { return CGPoint(x: 0.4, y: 0.66) }
        let x = 0.2 + 0.6 * Double(index) / Double(count - 1)
        return CGPoint(x: x, y: index.isMultiple(of: 2) ? 0.64 : 0.70)
    }

    let outdoors: Bool
    let name: String
    var breed = Breed.named("mixy")
    var scarf: UInt32 = DogProfile.scarves[0]
    var look: DogLook? = nil
    var accessory: Accessory? = nil
    var personality = Personality.balanced
    /// Where it stands before it starts wandering, as a fraction of the scene.
    var start = CGPoint(x: 0.4, y: 0.66)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.appLanguage) private var language
    @State private var position: CGPoint?
    @State private var facingLeft = false
    @State private var walking = false
    /// Set while the user is holding the dog.
    @State private var dragPoint: CGPoint?
    @State private var hop: CGFloat = 0
    @State private var hearts: [Heart] = []
    @State private var pets = 0
    /// Smiling while the hearts float up.
    @State private var happy = false
    /// Pendulum angle while held by the scruff, driven by how fast it's carried sideways.
    @State private var swing: Double = 0
    @State private var restingUntil = Date.distantPast

    /// Where a dog can be put down: on the floor, above the controls.
    private static let xRange = 0.1...0.9
    private static let yRange = 0.48...0.82
    private static let floor = 0.58...0.74

    private struct Heart: Identifiable {
        let id = UUID()
        let dx: CGFloat
        var rising = false
    }

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let side = min(size.width * 0.20, 100)
            let held = dragPoint != nil
            let spot = dragPoint ?? CGPoint(x: size.width * (position ?? start).x, y: size.height * (position ?? start).y)
            VStack(spacing: 4) {
                TimelineView(.animation(minimumInterval: held ? 1.0 / 30 : 0.12, paused: reduceMotion || scenePhase != .active)) { context in
                    let time = context.date.timeIntervalSinceReferenceDate
                    let rate = walking ? (personality == .active ? 6 : 4) : 1.25
                    let beat = Int(time * rate) % 2
                    // Held by the scruff: hangs a little stretched and keeps swinging side to side.
                    let dangle = held && !reduceMotion ? sin(time * 5.5) * 12 : 0
                    PixelDog(breed: breed, scarf: scarf, look: look, accessory: accessory, happy: happy).frame(width: side, height: side)
                        .scaleEffect(x: facingLeft ? -1 : 1, y: 1)
                        .scaleEffect(x: held ? 0.93 : 1, y: held ? 1.1 : 1, anchor: .top)
                        .rotationEffect(.degrees(dangle), anchor: .top)
                        .offset(y: reduceMotion || held ? 0 : (beat == 0 ? 0 : -3))
                }
                .rotationEffect(.degrees(held ? swing : 0), anchor: .top)
                .overlay(alignment: .top) { heartsView(side: side) }
                .offset(y: hop)
                Text(name).font(.system(.caption, design: .monospaced))
                    .padding(.horizontal, 9).padding(.vertical, 2)
                    .foregroundStyle(.white)
                    .background(Theme.overlay, in: RoundedRectangle(cornerRadius: 7))
                    .opacity(held ? 0 : 1)
            }
            // Hang from the finger: the top of the head sits under the touch point.
            .offset(y: held ? side * 0.4 + 10 : 0)
            .shadow(color: .black.opacity(held ? 0.25 : 0), radius: 8, y: 10)
            .contentShape(Rectangle())
            .onTapGesture(perform: pet)
            .gesture(
                DragGesture(minimumDistance: 6, coordinateSpace: .named("floor"))
                    .onChanged { value in
                        if dragPoint == nil { walking = false; position = position ?? start }
                        dragPoint = value.location
                        // Body lags behind the hand: carried right, it swings left.
                        guard !reduceMotion else { return }
                        let target = (value.velocity.width / 45).clamped(to: -30...30)
                        withAnimation(.interpolatingSpring(stiffness: 140, damping: 7)) { swing = target }
                    }
                    .onEnded { value in
                        swing = 0
                        drop(at: value.location, in: size)
                    }
            )
            .animation(.spring(duration: 0.3, bounce: 0.3), value: held)
            .position(spot)
        }
        .coordinateSpace(.named("floor"))
        .sensoryFeedback(.impact(weight: .light), trigger: pets)
        .sensoryFeedback(.impact(weight: .medium), trigger: dragPoint == nil)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(name)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(language.text("Pets your dog", "摸摸狗狗"))
        .accessibilityAction(.default, pet)
        .task(id: "\(outdoors)-\(reduceMotion)-\(scenePhase)-\(personality)") { await wander() }
    }

    private func heartsView(side: CGFloat) -> some View {
        ZStack {
            ForEach(hearts) { heart in
                Image(systemName: "heart.fill")
                    .font(.system(size: side * 0.22))
                    .foregroundStyle(Color(leashHex: 0xF2668B))
                    .offset(x: heart.dx, y: heart.rising && !reduceMotion ? -side * 0.9 : 0)
                    .opacity(heart.rising ? 0 : 1)
                    .scaleEffect(heart.rising ? 1.3 : 0.6)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: Petting and moving

    /// Happy: a couple of hops and a few hearts. It stays put for a moment afterwards.
    private func pet() {
        pets += 1
        let pet = pets
        walking = false
        happy = true
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            if pets == pet { happy = false }  // Another pet keeps the smile going.
        }
        restingUntil = .now.addingTimeInterval(3)
        let side: CGFloat = 40
        let new = (0..<4).map { _ in Heart(dx: .random(in: -side...side)) }
        hearts += new
        withAnimation(.easeOut(duration: 1.2)) {
            for index in hearts.indices where new.contains(where: { $0.id == hearts[index].id }) { hearts[index].rising = true }
        }
        Task {
            try? await Task.sleep(for: .seconds(1.3))
            hearts.removeAll { heart in new.contains { $0.id == heart.id } }
        }
        guard !reduceMotion else { return }
        Task {
            for height in [CGFloat(-26), -14] {
                withAnimation(.easeOut(duration: 0.16)) { hop = height }
                try? await Task.sleep(for: .seconds(0.16))
                withAnimation(.easeIn(duration: 0.16)) { hop = 0 }
                try? await Task.sleep(for: .seconds(0.18))
            }
        }
    }

    /// Puts the dog down where it was let go, kept inside the visible floor.
    private func drop(at location: CGPoint, in size: CGSize) {
        guard size.width > 0, size.height > 0 else { dragPoint = nil; return }
        let point = CGPoint(x: (location.x / size.width).clamped(to: Self.xRange),
                            y: (location.y / size.height).clamped(to: Self.yRange))
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) { position = point }
        dragPoint = nil
        restingUntil = .now.addingTimeInterval(2)
        if !reduceMotion {
            withAnimation(.easeOut(duration: 0.12)) { hop = -8 }
            withAnimation(.easeIn(duration: 0.15).delay(0.12)) { hop = 0 }
        }
    }

    /// Rests, then moves somewhere nearby, at the pace its personality sets. Waits while held or just petted.
    private func wander() async {
        guard !reduceMotion, scenePhase == .active else { walking = false; return }
        do {
            while !Task.isCancelled {
                try await Task.sleep(for: .seconds(Double.random(in: personality.pause(outdoors: outdoors))))
                // Calm dogs often just stay where they are.
                if dragPoint != nil || Date.now < restingUntil || (personality == .calm && Bool.random()) { continue }
                let from = position ?? start
                let reach = personality.reach
                let target = CGPoint(x: (from.x + .random(in: -reach...reach)).clamped(to: 0.15...0.85),
                                     y: Double.random(in: Self.floor))
                let duration = personality.moveDuration(outdoors: outdoors) * max(0.5, abs(target.x - from.x) / max(reach, 0.01) + 0.3)
                facingLeft = target.x < from.x
                walking = true
                withAnimation(.linear(duration: duration)) { position = target }
                try await Task.sleep(for: .seconds(duration))
                walking = false
            }
        } catch { walking = false }
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self { min(max(self, range.lowerBound), range.upperBound) }
}
