import SwiftUI
import PhotosUI

/// The user's dogs: pick which one is out, name it, adjust its look and dress it up. A photo of a real dog
/// becomes a matching pixel dog, as a new dog or for the current one.
struct ProfileView: View {
    /// Reports how tall the content is, so the sheet can fit it instead of filling the screen.
    @Binding var contentHeight: CGFloat
    @Environment(GameModel.self) private var game
    @Environment(Toaster.self) private var toaster
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.appLanguage) private var language
    @State private var name = ""
    @State private var showingCamera = false
    @State private var showingLibrary = false
    @State private var pickedItem: PhotosPickerItem?
    @State private var converting = false
    @State private var editing: EditingLook?
    @State private var dogPhoto: UIImage?
    /// Whether the next photo makes a new dog or updates the current one.
    @State private var photoForNewDog = true
    @State private var removing: DogProfile?
    @FocusState private var editingName: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                dogsRow
                VStack(spacing: 8) {
                    // Only the photo dog flips; breed coats have no photo behind them.
                    DogFlipCard(photo: game.dogLook == nil ? nil : dogPhoto, side: 120) {
                        PixelDog(breed: game.dogBreed, scarf: game.profile.scarf, look: game.dogLook, accessory: game.profile.accessory)
                    }
                        .opacity(converting ? 0.3 : 1)
                        .overlay { if converting { ProgressView() } }
                        .animation(.default, value: game.profile)
                    TextField(language.text("Name your dog", "幫狗狗取名字"), text: $name)
                        .font(.system(.title3, design: .monospaced)).multilineTextAlignment(.center)
                        .focused($editingName).submitLabel(.done)
                        .onSubmit(saveName)
                        .onChange(of: editingName) { _, editing in if !editing { saveName() } }
                        .accessibilityLabel(language.text("Dog's name", "狗狗名字"))
                    if converting {
                        Text(language.text("Looking at your dog…", "正在看你的狗狗…")).font(.caption).foregroundStyle(.secondary)
                    } else {
                        // Dogs without a photo start from their breed's colors.
                        Button(language.text("Adjust look", "調整樣子")) { editing = editCurrent(game.dogLook ?? DogLook(breed: game.dogBreed)) }
                            .font(.caption)
                    }
                }
                .frame(maxWidth: .infinity).card()
                dressUp
            }
            .padding(16)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
        }
        .background(Theme.background(colorScheme))
        .onAppear { name = game.profile.name }
        .onChange(of: game.profile.id) { name = game.profile.name }
        .task(id: "\(game.profile.id)-\(game.dogPhotoVersion)") {
            dogPhoto = game.dogPhotoURL(for: game.profile.id).flatMap { UIImage(contentsOfFile: $0.path) }
        }
        .confirmationDialog(language.text("Remove \(removing?.displayName(in: language) ?? "")?", "移除「\(removing?.displayName(in: language) ?? "")」？"),
                            isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }),
                            titleVisibility: .visible, presenting: removing) { dog in
            Button(language.text("Remove", "移除"), role: .destructive) {
                if !game.removeDog(dog.id) { toaster.show(language.text("Didn't remove, try again", "沒移除，再試一次")) }
            }
        } message: { _ in
            Text(language.text("Its name, look and photo will be deleted.", "牠的名字、樣子和照片都會刪除。"))
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) { photoMenu }
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraPicker { data in readDog(data) }.ignoresSafeArea()
        }
        .sheet(item: $editing) { item in
            NavigationStack {
                DogLookEditor(look: item.look, photo: item.photo, name: item.name,
                              accessory: item.dogID == nil ? nil : game.profile.accessory) { look, name in
                    save(item, look: look, name: name)
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
        let photo: UIImage?
        let name: String
        /// The dog being changed, or nil for a new dog.
        var dogID: UUID? = nil
        /// Set for a newly taken or chosen photo, which is saved when the look is accepted.
        var photoData: Data? = nil
    }

    private func editCurrent(_ look: DogLook) -> EditingLook {
        EditingLook(look: look, photo: dogPhoto, name: game.profile.name, dogID: game.profile.id)
    }

    // MARK: Dogs

    /// All of the user's dogs; tap one to make it the dog on screen and on walks.
    private var dogsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(game.roster.dogs) { dog in
                    let active = dog.id == game.profile.id
                    Button { game.selectDog(dog.id) } label: {
                        VStack(spacing: 4) {
                            PixelDog(breed: Breed.named(dog.breedID), scarf: dog.scarf, look: dog.usesPhoto ? dog.photoLook : nil,
                                     accessory: dog.accessory)
                                .frame(width: 44, height: 44)
                            Text(dog.displayName(in: language)).font(.system(.caption, design: .monospaced)).lineLimit(1)
                        }
                        .frame(width: 76).padding(.vertical, 8)
                        .background(Theme.surface(colorScheme), in: RoundedRectangle(cornerRadius: 14))
                        .overlay { RoundedRectangle(cornerRadius: 14).stroke(active ? Theme.accent : .clear, lineWidth: 3) }
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        if game.roster.dogs.count > 1 {
                            Button(role: .destructive) { removing = dog } label: {
                                Label(language.text("Remove", "移除"), systemImage: "trash")
                            }
                        }
                    }
                    .accessibilityLabel(dog.displayName(in: language))
                    .accessibilityAddTraits(active ? .isSelected : [])
                    .accessibilityHint(language.text("Makes this the dog on screen and on walks", "讓這隻狗狗出現在畫面和散步中"))
                }
                Menu { addDogItems } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "plus").font(.title2.weight(.semibold)).frame(width: 44, height: 44)
                        Text(language.text("Add", "新增")).font(.system(.caption, design: .monospaced))
                    }
                    .foregroundStyle(.secondary)
                    .frame(width: 76).padding(.vertical, 8)
                    .background(Theme.surface(colorScheme).opacity(0.6), in: RoundedRectangle(cornerRadius: 14))
                    .overlay { RoundedRectangle(cornerRadius: 14).stroke(Theme.line(colorScheme), style: StrokeStyle(lineWidth: 1.5, dash: [4])) }
                }
                .disabled(converting)
                .accessibilityLabel(language.text("Add a dog", "新增狗狗"))
            }
            .padding(2)
        }
    }

    @ViewBuilder private var addDogItems: some View {
        photoButtons(newDog: true)
        Button {
            editing = EditingLook(look: DogLook(breed: Breed.named("mixy")), photo: nil, name: "")
        } label: { Label(language.text("Without Photo", "不用照片"), systemImage: "paintpalette") }
    }

    @ViewBuilder private func photoButtons(newDog: Bool) -> some View {
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            Button { photoForNewDog = newDog; showingCamera = true } label: { Label(language.text("Take Photo", "拍照"), systemImage: "camera") }
        }
        Button { photoForNewDog = newDog; showingLibrary = true } label: {
            Label(language.text("Choose Photo", "從相簿選擇"), systemImage: "photo.on.rectangle")
        }
    }

    // MARK: Dress up

    /// Things to wear, shown on the current dog.
    private var dressUp: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(language.text("Dress Up", "裝扮")).font(.system(.headline, design: .monospaced))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                outfitTile(nil)
                ForEach(Accessory.allCases) { outfitTile($0) }
            }
        }
        .card()
    }

    private func outfitTile(_ item: Accessory?) -> some View {
        let selected = game.profile.accessory == item
        let label = item?.name(in: language) ?? language.text("None", "不穿")
        return Button {
            update { $0.accessory = item }
        } label: {
            VStack(spacing: 4) {
                PixelDog(breed: game.dogBreed, scarf: game.profile.scarf, look: game.dogLook, accessory: item)
                    .frame(width: 56, height: 56)
                Text(label).font(.system(.caption, design: .monospaced)).lineLimit(1).minimumScaleFactor(0.8)
                    .foregroundStyle(selected ? .primary : .secondary)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 8)
            .background(Theme.background(colorScheme), in: RoundedRectangle(cornerRadius: 12))
            .overlay { RoundedRectangle(cornerRadius: 12).stroke(selected ? Theme.accent : .clear, lineWidth: 3) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: Photo to pixel dog

    private var photoMenu: some View {
        Menu {
            Section(language.text("Add a Dog", "新增狗狗")) { photoButtons(newDog: true) }
            Section(language.text("New Photo of \(game.profile.displayName(in: language))", "幫「\(game.profile.displayName(in: language))」換照片")) {
                photoButtons(newDog: false)
            }
        } label: {
            Image(systemName: "camera.fill")
        }
        .disabled(converting)
        .accessibilityLabel(language.text("Make a pixel dog from a photo", "用照片變出像素狗狗"))
    }

    /// Reads the dog's traits, then opens the editor so the user can check them before saving.
    private func readDog(_ data: Data) {
        converting = true
        let forNewDog = photoForNewDog
        Task {
            defer { converting = false }
            do {
                let look = try await DogAnalyzer.look(from: data)
                editing = EditingLook(look: look, photo: UIImage(data: data), name: forNewDog ? "" : game.profile.name,
                                      dogID: forNewDog ? nil : game.profile.id, photoData: data)
            } catch {
                toaster.show(language.text("Couldn't find a dog. Try a photo where your dog fills the frame",
                                           "找不到狗狗，試試狗狗佔滿畫面的照片"))
            }
        }
    }

    /// Saves an accepted look: a new dog, or the dog it was made for. The photo is kept only now.
    private func save(_ item: EditingLook, look: DogLook, name: String) {
        guard let dogID = item.dogID else {
            var dog = DogProfile()
            dog.name = name
            dog.photoLook = look
            dog.usesPhoto = true
            if let collar = look.collar { dog.scarf = collar }
            if game.addDog(dog, photo: item.photoData) {
                toaster.show(language.text("✨ Welcome, \(dog.displayName(in: language))!", "✨ 歡迎「\(dog.displayName(in: language))」！"))
            } else {
                toaster.show(language.text("Didn't save, try again", "沒存到，再試一次"))
            }
            return
        }
        if let data = item.photoData, !game.saveDogPhoto(data, for: dogID) {
            toaster.show(language.text("Photo didn't save", "照片沒存到"))
        }
        game.selectDog(dogID)
        if update({ $0.name = name; $0.photoLook = look; $0.usesPhoto = true; if let collar = look.collar { $0.scarf = collar } }) {
            self.name = name
            toaster.show(language.text("✨ Look saved", "✨ 樣子已儲存"))
        }
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
