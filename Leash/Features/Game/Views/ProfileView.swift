import SwiftUI
import PhotosUI

/// Name the dog and pick a coat (unlocked by befriending that breed) and a collar (unlocked by level).
/// The top-right menu reads a photo of the user's own dog (ears, fur colors) into a matching pixel dog.
struct ProfileView: View {
    private enum Tab { case coat, scarf }

    @Environment(GameModel.self) private var game
    @Environment(Toaster.self) private var toaster
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.appLanguage) private var language
    @State private var name = ""
    @State private var tab = Tab.coat
    @State private var showingCamera = false
    @State private var showingLibrary = false
    @State private var pickedItem: PhotosPickerItem?
    @State private var converting = false
    @State private var editing: EditingLook?
    @FocusState private var editingName: Bool
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                VStack(spacing: 8) {
                    PixelDog(breed: game.dogBreed, scarf: game.profile.scarf, look: game.dogLook)
                        .frame(width: 120, height: 120)
                        .opacity(converting ? 0.3 : 1)
                        .overlay { if converting { ProgressView() } }
                        .animation(.default, value: game.profile)
                    TextField(language.text("Name your dog", "幫狗狗取名字"), text: $name)
                        .font(.system(.title3, design: .monospaced)).multilineTextAlignment(.center)
                        .focused($editingName).submitLabel(.done)
                        .onSubmit(saveName)
                        .onChange(of: editingName) { _, editing in if !editing { saveName() } }
                        .accessibilityLabel(language.text("Dog's name", "狗狗名字"))
                    if let look = game.dogLook, !converting {
                        Button(language.text("Adjust look", "調整樣子")) { editing = EditingLook(look: look) }
                            .font(.caption)
                    } else {
                        Text(converting ? language.text("Looking at your dog…", "正在看你的狗狗…") : game.dogBreed.name(in: language))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity).card()

                Picker("", selection: $tab) {
                    Label(language.text("Coat", "毛色"), systemImage: "pawprint.fill").tag(Tab.coat)
                    Label(language.text("Collar", "項圈"), systemImage: "paintpalette.fill").tag(Tab.scarf)
                }
                .pickerStyle(.segmented)

                LazyVGrid(columns: columns, spacing: 8) {
                    switch tab {
                    case .coat:
                        if game.profile.photoLook != nil { photoTile }
                        ForEach(Breed.all) { coatTile($0) }
                    case .scarf:
                        if let collar = game.profile.photoLook?.collar { photoCollarTile(collar) }
                        ForEach(Array(DogProfile.scarves.enumerated()), id: \.offset) { scarfTile(index: $0, color: $1) }
                    }
                }
                Text(tab == .coat ? language.text("Make new friends to unlock their look", "交到新朋友就能解鎖牠的樣子")
                                  : language.text("Level up for more colors", "升級解鎖更多顏色"))
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .padding(16)
        }
        .background(Theme.background(colorScheme))
        .onAppear { name = game.profile.name }
        .toolbar {
            ToolbarItem(placement: .primaryAction) { photoMenu }
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraPicker { data in readDog(data) }.ignoresSafeArea()
        }
        .sheet(item: $editing) { item in
            NavigationStack {
                DogLookEditor(look: item.look) { look in
                    if update({ $0.photoLook = look; $0.usesPhoto = true; if let collar = look.collar { $0.scarf = collar } }) {
                        toaster.show(language.text("✨ Meet your pixel dog", "✨ 像素狗狗完成了"))
                    }
                }
            }
            .presentationDragIndicator(.visible)
        }
        .photosPicker(isPresented: $showingLibrary, selection: $pickedItem, matching: .images)
        .onChange(of: pickedItem) { _, item in
            guard let item else { return }
            pickedItem = nil
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) { readDog(data) }
                else { toaster.show(language.text("Couldn't open that photo", "打不開這張照片")) }
            }
        }
    }

    // MARK: Photo to pixel dog

    private struct EditingLook: Identifiable {
        let id = UUID()
        let look: DogLook
    }

    private var photoMenu: some View {
        Menu {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button { showingCamera = true } label: { Label(language.text("Take Photo", "拍照"), systemImage: "camera") }
            }
            Button { showingLibrary = true } label: { Label(language.text("Choose Photo", "從相簿選擇"), systemImage: "photo.on.rectangle") }
        } label: {
            Image(systemName: "camera.fill")
        }
        .disabled(converting)
        .accessibilityLabel(language.text("Make a pixel dog from a photo", "用照片變出像素狗狗"))
    }

    /// Reads the dog's traits, then opens the editor so the user can check them before saving.
    private func readDog(_ data: Data) {
        converting = true
        Task {
            defer { converting = false }
            do {
                editing = EditingLook(look: try await DogAnalyzer.look(from: data))
            } catch {
                toaster.show(language.text("Couldn't find a dog. Try a photo where your dog fills the frame",
                                           "找不到狗狗，試試狗狗佔滿畫面的照片"))
            }
        }
    }

    private var photoTile: some View {
        Button {
            if game.profile.usesPhoto, let look = game.profile.photoLook { editing = EditingLook(look: look) }
            else { update { $0.usesPhoto = true } }
        } label: {
            tile(selected: game.profile.usesPhoto, locked: false) {
                PixelDog(scarf: game.profile.scarf, look: game.profile.photoLook)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(language.text("My own dog", "我的狗狗本人"))
        .accessibilityAddTraits(game.profile.usesPhoto ? .isSelected : [])
    }

    private func tile(selected: Bool, locked: Bool, @ViewBuilder content: () -> some View) -> some View {
        content()
            .padding(10).frame(maxWidth: .infinity).aspectRatio(1, contentMode: .fit)
            .background(Theme.surface(colorScheme), in: RoundedRectangle(cornerRadius: 14))
            .overlay { RoundedRectangle(cornerRadius: 14).stroke(selected ? Theme.accent : .clear, lineWidth: 3) }
            .overlay(alignment: .bottomTrailing) {
                if locked { PixelIcon(glyph: .lock).frame(width: 16).padding(6) }
                else if selected { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent).padding(4) }
            }
    }

    private func coatTile(_ breed: Breed) -> some View {
        let unlocked = game.isUnlocked(breed)
        return Button {
            update { $0.breedID = breed.id; $0.usesPhoto = false }
        } label: {
            tile(selected: !game.profile.usesPhoto && game.profile.breedID == breed.id, locked: !unlocked) {
                PixelDog(breed: breed, scarf: game.profile.scarf, silhouette: !unlocked)
            }
        }
        .buttonStyle(.plain).disabled(!unlocked)
        .accessibilityLabel(unlocked ? breed.name(in: language) : language.text("Locked", "未解鎖"))
        .accessibilityAddTraits(!game.profile.usesPhoto && game.profile.breedID == breed.id ? .isSelected : [])
    }

    private func scarfTile(index: Int, color: UInt32) -> some View {
        let unlocked = index < DogProfile.unlockedScarves(level: game.progress.level)
        return Button {
            update { $0.scarf = color }
        } label: {
            tile(selected: game.profile.scarf == color, locked: !unlocked) {
                RoundedRectangle(cornerRadius: 6).fill(unlocked ? Color(leashHex: color) : Theme.line(colorScheme))
                    .overlay { RoundedRectangle(cornerRadius: 6).stroke(.black.opacity(0.15)) }
                    .padding(8)
            }
        }
        .buttonStyle(.plain).disabled(!unlocked)
        .accessibilityLabel(unlocked ? language.text("Collar color \(index + 1)", "項圈顏色 \(index + 1)") : language.text("Locked", "未解鎖"))
        .accessibilityAddTraits(game.profile.scarf == color ? .isSelected : [])
    }

    /// The collar seen in the user's photo; always available.
    private func photoCollarTile(_ color: UInt32) -> some View {
        Button {
            update { $0.scarf = color }
        } label: {
            tile(selected: game.profile.scarf == color, locked: false) {
                RoundedRectangle(cornerRadius: 6).fill(Color(leashHex: color))
                    .overlay { RoundedRectangle(cornerRadius: 6).stroke(.black.opacity(0.15)) }
                    .overlay { Image(systemName: "camera.fill").font(.caption).foregroundStyle(.white).shadow(radius: 1) }
                    .padding(8)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(language.text("Collar from your photo", "照片裡的項圈"))
        .accessibilityAddTraits(game.profile.scarf == color ? .isSelected : [])
    }

    private func saveName() {
        let trimmed = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(20))
        guard trimmed != game.profile.name else { return }
        if update({ $0.name = trimmed }) {
            toaster.show(language.text("✏️ Renamed to \(trimmed.isEmpty ? "My dog" : trimmed)", "✏️ 改名為「\(trimmed.isEmpty ? "我的狗狗" : trimmed)」"))
        }
    }

    @discardableResult
    private func update(_ change: (inout DogProfile) -> Void) -> Bool {
        let saved = game.updateProfile(change)
        if !saved { toaster.show(language.text("Didn't save, tap again", "沒存到，再按一次")) }
        return saved
    }
}
