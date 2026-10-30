import SwiftUI

/// Shows the dog read from a photo and lets the user name it and fix ears, colors and collar before saving.
struct DogLookEditor: View {
    let onSave: (DogLook, String) -> Void
    /// The photo it was read from, shown on the back of the card.
    let photo: UIImage?
    /// What the dog is wearing, shown in the preview.
    let accessory: Accessory?
    @State private var look: DogLook
    @State private var name: String
    /// The collar found in the photo, kept as an option even if the user picks another.
    private let detectedCollar: UInt32?
    @Environment(GameModel.self) private var game
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.appLanguage) private var language

    init(look: DogLook, photo: UIImage?, name: String, accessory: Accessory? = nil, onSave: @escaping (DogLook, String) -> Void) {
        self.accessory = accessory
        _look = State(initialValue: look)
        _name = State(initialValue: name)
        self.photo = photo
        detectedCollar = look.collar
        self.onSave = onSave
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                VStack(spacing: 6) {
                    DogFlipCard(photo: photo, side: 140) {
                        PixelDog(scarf: look.collar ?? game.profile.scarf, look: look, accessory: accessory).animation(.default, value: look)
                    }
                    TextField(language.text("Name your dog", "幫狗狗取名字"), text: $name)
                        .font(.system(.title3, design: .monospaced)).multilineTextAlignment(.center)
                        .submitLabel(.done)
                        .accessibilityLabel(language.text("Dog's name", "狗狗名字"))
                    Text(photo == nil ? language.text("Here's your dog! Tap to fix anything we got wrong.", "這是你的狗狗！哪裡不像可以點選修改。")
                         : language.text("Here's your dog! Tap the card to compare with the photo, and fix anything we got wrong below.",
                                         "這是你的狗狗！點卡片可以翻面對照照片，哪裡不像可以在下面修改。"))
                        .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity).card()

                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(language.text("Ears", "耳朵")).font(.system(.subheadline, design: .monospaced))
                        Picker(language.text("Ears", "耳朵"), selection: $look.ears) {
                            Text(language.text("Pointy", "立耳")).tag(DogLook.Ears.pricked)
                            Text(language.text("Floppy", "垂耳")).tag(DogLook.Ears.floppy)
                        }
                        .pickerStyle(.segmented)
                    }
                    colorRow(language.text("Fur", "毛色"), $look.coat)
                    colorRow(language.text("Ear color", "耳朵顏色"), $look.earColor)
                    colorRow(language.text("Muzzle", "嘴邊"), $look.muzzle)
                    colorRow(language.text("Chest", "胸口"), $look.chest)
                    colorRow(language.text("Paws", "腳掌"), $look.paws)
                    colorRow(detectedCollar == nil ? language.text("Collar (none found in photo)", "項圈（照片裡沒看到）")
                                                   : language.text("Collar", "項圈"),
                             Binding(get: { look.collar ?? game.profile.scarf }, set: { look.collar = $0 }),
                             options: collarSwatches)
                }
                .card()
            }
            .padding(16)
        }
        .background(Theme.background(colorScheme))
        .navigationTitle(language.text("My Dog", "我的狗狗"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button(language.text("Cancel", "取消")) { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button(language.text("Use", "使用")) {
                    onSave(look, String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(20)))
                    dismiss()
                }
                .fontWeight(.bold)
            }
        }
    }

    /// Colors found in the photo first, then a few common fur colors.
    private var swatches: [UInt32] {
        var seen = Set<UInt32>()
        return (look.photoColors + [0xFFFFFF, 0xF4E3C3, 0xD9A066, 0x8B5A2B, 0x7A7385, 0x1E1B22])
            .filter { seen.insert($0).inserted }
    }

    /// The photo's collar first, then the collar colors unlocked so far.
    private var collarSwatches: [UInt32] {
        let unlocked = DogProfile.scarves.prefix(DogProfile.unlockedScarves(level: game.progress.level))
        var seen = Set<UInt32>()
        return ([detectedCollar].compactMap { $0 } + unlocked).filter { seen.insert($0).inserted }
    }

    private func colorRow(_ title: String, _ value: Binding<UInt32>, options: [UInt32]? = nil) -> some View {
        let swatches = options ?? self.swatches
        return VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(.subheadline, design: .monospaced))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // Keep the current color visible even if it isn't one of the swatches.
                    ForEach(swatches.contains(value.wrappedValue) ? swatches : [value.wrappedValue] + swatches, id: \.self) { color in
                        let selected = color == value.wrappedValue
                        Button { value.wrappedValue = color } label: {
                            Circle().fill(Color(leashHex: color))
                                .overlay { Circle().stroke(.black.opacity(0.15)) }
                                .padding(4)
                                .overlay { Circle().stroke(selected ? Theme.accent : .clear, lineWidth: 3) }
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(String(format: "#%06X", color))
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                    // Any color at all, from the system color picker.
                    ColorPicker(language.text("More colors", "更多顏色"), selection: Binding(
                        get: { Color(leashHex: value.wrappedValue) }, set: { value.wrappedValue = $0.leashHex }), supportsOpacity: false)
                        .labelsHidden()
                        .frame(width: 44, height: 44)
                        .accessibilityLabel(language.text("\(title): more colors", "\(title)：更多顏色"))
                }
            }
        }
    }
}
