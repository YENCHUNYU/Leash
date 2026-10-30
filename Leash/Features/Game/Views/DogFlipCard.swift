import SwiftUI

/// The pixel dog on the front; tap to flip it over and see the photo it was made from.
/// Without a photo it's just the pixel dog.
struct DogFlipCard<Front: View>: View {
    let photo: UIImage?
    let side: CGFloat
    @ViewBuilder var front: Front
    @State private var flipped = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.appLanguage) private var language

    var body: some View {
        if let photo {
            Button {
                withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.5)) { flipped.toggle() }
            } label: {
                ZStack {
                    front.frame(width: side, height: side)
                        .opacity(flipped ? 0 : 1)
                    Image(uiImage: photo).resizable().scaledToFill()
                        .frame(width: side, height: side)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        // Pre-flipped so it reads the right way round once the card turns.
                        .rotation3DEffect(.degrees(reduceMotion ? 0 : 180), axis: (x: 0, y: 1, z: 0))
                        .opacity(flipped ? 1 : 0)
                }
                .rotation3DEffect(.degrees(!reduceMotion && flipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.caption.weight(.bold)).foregroundStyle(Theme.ink)
                        .padding(6).background(Theme.accent, in: Circle())
                        .offset(x: 6, y: 6)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(flipped ? language.text("Your dog's photo", "狗狗的照片") : language.text("Your pixel dog", "你的像素狗狗"))
            .accessibilityHint(language.text("Flips to show the other side", "翻面查看另一面"))
        } else {
            front.frame(width: side, height: side)
        }
    }
}
