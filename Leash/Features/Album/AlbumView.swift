import SwiftUI
import PhotosUI

struct AlbumView: View {
    @Environment(PhotoLibrary.self) private var photos
    @Environment(Toaster.self) private var toaster
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.appLanguage) private var language
    @State private var picked: [PhotosPickerItem] = []

    var body: some View {
        let tileColor = Theme.surface(colorScheme)
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                PhotosPicker(selection: $picked, matching: .images) {
                    Image(systemName: "plus").font(.title)
                        .frame(maxWidth: .infinity).aspectRatio(1, contentMode: .fit)
                        .background(tileColor, in: RoundedRectangle(cornerRadius: 12))
                }
                .accessibilityLabel(language.text("Add photos", "加入照片"))
                ForEach(photos.photos) { photo in
                    NavigationLink { PhotoDetailView(photo: photo) } label: { PhotoThumbnail(photo: photo) }
                }
            }
            .padding(12)
            if photos.photos.isEmpty {
                Text(language.text("Take photos on walks, or add them here.", "散步時拍照，或從這裡加入照片。"))
                    .font(.footnote).foregroundStyle(.secondary).padding()
            }
        }
        .background(Theme.background(colorScheme))
        .onChange(of: picked) { _, items in
            guard !items.isEmpty else { return }
            picked = []
            Task {
                for item in items {
                    guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
                    do { _ = try await photos.add(imageData: data) }
                    catch { toaster.show(language.text("Photo didn't save", "照片沒存到")) }
                }
            }
        }
    }
}

struct PhotoThumbnail: View {
    let photo: Photo
    @Environment(PhotoLibrary.self) private var photos

    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let image = photos.image(for: photo, thumbnail: true) {
                    Image(uiImage: image).resizable().scaledToFill()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .accessibilityLabel(photo.takenAt.formatted(date: .abbreviated, time: .shortened))
    }
}

private struct PhotoDetailView: View {
    let photo: Photo
    @Environment(PhotoLibrary.self) private var photos
    @Environment(SpotCatalog.self) private var spots
    @Environment(Toaster.self) private var toaster
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appLanguage) private var language
    @State private var confirmingDelete = false

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                if let image = photos.image(for: photo) {
                    Image(uiImage: image).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 18))
                }
                Text([photo.takenAt.formatted(.dateTime.locale(language.locale)), spots.spot(id: photo.spotID)?.name]
                    .compactMap { $0 }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(16)
        }
        .toolbar {
            Button(language.text("Delete", "刪除"), systemImage: "trash", role: .destructive) { confirmingDelete = true }
        }
        .confirmationDialog(language.text("Delete this photo?", "刪除這張？"), isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button(language.text("Delete", "刪除"), role: .destructive) {
                do {
                    try photos.delete(photo)
                    dismiss()
                } catch {
                    toaster.show(language.text("Couldn't delete", "沒刪掉"))
                }
            }
        }
    }
}
