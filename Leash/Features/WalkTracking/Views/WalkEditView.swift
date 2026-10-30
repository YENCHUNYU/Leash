import SwiftUI
import CoreLocation

/// Edits a diary entry: note, place, times, dogs and pee/poop counts. The route and distance stay as recorded.
struct WalkEditView: View {
    let model: WalkViewModel
    @State private var walk: Walk
    @Environment(GameModel.self) private var game
    @Environment(SpotCatalog.self) private var spots
    @Environment(Toaster.self) private var toaster
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appLanguage) private var language

    init(walk: Walk, model: WalkViewModel) {
        self.model = model
        _walk = State(initialValue: walk)
    }

    var body: some View {
        Form {
            Section(language.text("Note", "備註")) {
                TextField(language.text("How was the walk?", "這次散步怎麼樣？"),
                          text: Binding(get: { walk.note ?? "" }, set: { walk.note = $0 }), axis: .vertical)
                    .lineLimit(3...8)
            }
            Section(language.text("When", "時間")) {
                DatePicker(language.text("Started", "開始"), selection: $walk.startedAt, in: ...Date.now)
                DatePicker(language.text("Ended", "結束"), selection: Binding(
                    get: { walk.endedAt ?? walk.startedAt },
                    set: { walk.endedAt = max($0, walk.startedAt) }), in: walk.startedAt...Date.now)
            }
            if !walk.isIndoor {
                Section(language.text("Where", "地點")) {
                    Picker(language.text("Place", "地點"), selection: $walk.spotID) {
                        Text(language.text("Around the block", "附近散步")).tag(String?.none)
                        ForEach(placeChoices) { Text($0.name).tag(Optional($0.id)) }
                    }
                }
                if game.roster.dogs.count > 1 { dogsSection }
                countsSection
            }
        }
        .onAppear {
            // Walks from before there could be several dogs were with the main dog.
            if walk.dogIDs.isEmpty && !walk.isIndoor { walk.dogIDs = [game.profile.id] }
        }
        .navigationTitle(language.text("Edit entry", "編輯日記"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button(language.text("Cancel", "取消")) { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button(language.text("Save", "儲存"), action: save).fontWeight(.bold)
            }
        }
    }

    /// The walk's current place, then parks within 3 km of where it started.
    private var placeChoices: [Spot] {
        let current = spots.spot(id: walk.spotID).map { [$0] } ?? []
        guard let first = walk.route.first else { return current }
        let start = CLLocation(latitude: first.latitude, longitude: first.longitude)
        let nearby = spots.all
            .compactMap { spot in spot.distance(from: start).map { (spot, $0) } }
            .filter { $0.1 < 3000 && $0.0.id != walk.spotID }
            .sorted { $0.1 < $1.1 }
            .prefix(15)
            .map(\.0)
        return current + nearby
    }

    private var walkDogs: [DogProfile] { game.roster.dogs.filter { walk.dogIDs.contains($0.id) } }

    private var dogsSection: some View {
        Section(language.text("Dogs", "狗狗")) {
            ForEach(game.roster.dogs) { dog in
                Toggle(isOn: Binding(
                    get: { walk.dogIDs.contains(dog.id) },
                    set: { on in
                        if on {
                            // Going from one dog to several: what was logged belongs to the first dog.
                            if walk.dogIDs.count == 1 {
                                for index in walk.events.indices where walk.events[index].dogID == nil {
                                    walk.events[index].dogID = walk.dogIDs[0]
                                }
                            }
                            walk.dogIDs.append(dog.id)
                        } else if walk.dogIDs.count > 1 {
                            walk.dogIDs.removeAll { $0 == dog.id }
                            walk.events.removeAll { $0.dogID == dog.id }
                        }
                    })) {
                    HStack {
                        PixelDog(breed: dog.breed, scarf: dog.scarf, look: dog.look).frame(width: 28, height: 28)
                        Text(dog.displayName(in: language))
                    }
                }
            }
        }
    }

    @ViewBuilder private var countsSection: some View {
        // With several dogs, counts are per dog; otherwise one total.
        if walkDogs.count > 1 {
            ForEach(walkDogs) { dog in
                Section(dog.displayName(in: language)) { counters(dog: dog.id) }
            }
        } else {
            Section(language.text("Pee & poop", "尿尿與便便")) { counters(dog: nil) }
        }
    }

    @ViewBuilder private func counters(dog: UUID?) -> some View {
        ForEach([WalkEvent.Kind.poop, .pee], id: \.self) { kind in
            let count = dog.map { walk.count(of: kind, dog: $0) } ?? walk.count(of: kind)
            Stepper(value: Binding(get: { count }, set: { walk.setCount(of: kind, dog: dog, to: $0) }), in: 0...30) {
                Text("\(kind == .poop ? language.text("💩 Poop", "💩 便便") : language.text("💧 Pee", "💧 尿尿"))  \(count)")
            }
        }
    }

    private func save() {
        let trimmed = walk.note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        walk.note = trimmed.isEmpty ? nil : String(trimmed.prefix(500))
        if model.update(walk) {
            dismiss()
        } else {
            toaster.show(language.text("Didn't save, try again", "沒存到，再試一次"))
        }
    }
}
