import SwiftUI
import PhotosUI

/// Full-screen room/park scene. Indoors: stats header and a dock of collections.
/// On a walk: live stats, visiting dogs and the walk controls.
struct WalkHomeView: View {
    @Bindable var model: WalkViewModel
    @Environment(GameModel.self) private var game
    @Environment(PhotoLibrary.self) private var photos
    @Environment(SpotCatalog.self) private var spots
    @Environment(Toaster.self) private var toaster
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.appLanguage) private var language
    @State private var confirmingFinish = false
    @State private var sheet: WalkSheet?
    @State private var showingCamera = false
    @State private var showingLibraryPicker = false
    @State private var pickedItem: PhotosPickerItem?
    @State private var arrivals = 0
    @AppStorage(Spot.plannedStorageKey) private var plannedID = ""
    private func t(_ english: String, _ chinese: String) -> String { language.text(english, chinese) }
    private var surface: Color { Theme.surface(colorScheme) }

    var body: some View {
        GeometryReader { geometry in
            scene(safeArea: geometry.safeAreaInsets)
                .ignoresSafeArea()
        }
        .sheet(item: $sheet, onDismiss: announceMilestones) { selected in
            NavigationStack {
                sheetContent(selected)
                    .navigationTitle(selected.title(in: language))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button(t("Close", "關閉")) { sheet = nil } } }
            }
            .toasts(toaster)
            .presentationDetents([.large]).presentationDragIndicator(.visible)
        }
        .confirmationDialog(t("Finish and save this walk?", "回家並儲存這次散步？"), isPresented: $confirmingFinish, titleVisibility: .visible) {
            Button(t("Finish walk", "回家，結束散步")) { finishWalk() }
        }
        .alert("Leash", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } }), presenting: model.error) { _ in
            Button(t("OK", "好")) { model.error = nil }
        } message: { Text($0.message(in: language)) }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraPicker { data in savePhoto(data) }.ignoresSafeArea()
        }
        .photosPicker(isPresented: $showingLibraryPicker, selection: $pickedItem, matching: .images)
        .onChange(of: pickedItem) { _, item in
            guard let item else { return }
            pickedItem = nil
            Task { if let data = try? await item.loadTransferable(type: Data.self) { savePhoto(data) } }
        }
        .onAppear(perform: announceMilestones)
    }

    // MARK: Sheets

    @ViewBuilder private func sheetContent(_ selected: WalkSheet) -> some View {
        switch selected {
        case .settings: SettingsView()
        case .profile: ProfileView()
        case .diary: WalkDiaryView(model: model)
        case .quests: QuestsView(walks: model)
        case .dex: DexView()
        case .album: AlbumView()
        case .spots: SpotsView(model: model) { sheet = nil }
        case .search: SpotsView(model: model, startSearching: true) { sheet = nil }
        case .encounter: EncounterView { sheet = nil }
        case .finished(let walk):
            WalkSummaryView(walk: walk) {
                Button(t("Save to diary", "收進日記")) { sheet = nil }
                    .buttonStyle(.borderedProminent).foregroundStyle(Theme.ink)
            }
        case .route:
            if let walk = model.activeWalk { WalkSummaryView(walk: walk) }
            else { ContentUnavailableView(t("No route yet", "還沒有散步路線"), systemImage: "map", description: Text(t("Start a walk to record your route.", "出門散步後，就能在這裡查看路線。"))) }
        }
    }

    // MARK: Scene

    private func scene(safeArea: EdgeInsets) -> some View {
        GeometryReader { geometry in
            let size = geometry.size
            let walk = model.activeWalk
            ZStack(alignment: .topLeading) {
                PixelScene(outdoors: walk != nil)
                WanderingDog(outdoors: walk != nil, name: game.profile.displayName(in: language),
                             breed: game.dogBreed, scarf: game.profile.scarf)
                if walk != nil { visitor(in: size) }
                if walk == nil { door(in: size) }
                VStack(spacing: 10) {
                    header
                    if let walk { walkStatus(walk) } else { shortcuts }
                    Spacer()
                    if !model.canWrite {
                        Button(t("Reload walks", "重新載入散步紀錄")) { model.reload() }
                            .padding(10).background(.regularMaterial, in: Capsule())
                    }
                    if let walk { walkBar(walk) } else { startControls }
                }
                .padding(.horizontal, 16)
                .padding(.top, safeArea.top + 12)
                .padding(.bottom, safeArea.bottom + 16)
            }
        }
    }

    private var header: some View {
        let progress = game.progress
        return HStack(spacing: 6) {
            Button { sheet = .profile } label: {
                HStack(spacing: 6) {
                    PixelDog(breed: game.dogBreed, scarf: game.profile.scarf).frame(width: 24, height: 24)
                    Text(game.profile.displayName(in: language)).lineLimit(1)
                }
                .font(.system(.headline, design: .monospaced)).padding(.horizontal, 12).padding(.vertical, 8)
                .background(surface, in: Capsule())
            }
            .layoutPriority(-1)
            .accessibilityLabel(t("\(game.profile.displayName(in: language)), edit your dog", "\(game.profile.displayName(in: language))，編輯狗狗"))
            Spacer(minLength: 0)
            Button { sheet = .quests } label: {
                HStack(spacing: 6) {
                    stat(Image(systemName: "star.fill").foregroundStyle(Theme.accent), "\(progress.level)")
                    stat(PixelIcon(glyph: .bone).frame(width: 18), "\(progress.treats)")
                    stat(Image(systemName: "flame.fill").foregroundStyle(.orange), "\(progress.currentStreak)")
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(t("Level \(progress.level), \(progress.treats) treats, \(progress.currentStreak)-day streak",
                                  "等級 \(progress.level)，\(progress.treats) 個零食，連續 \(progress.currentStreak) 天"))
            .accessibilityHint(t("Opens quests", "打開任務"))
            Button { sheet = .settings } label: {
                Image(systemName: "gearshape.fill").padding(10).background(surface, in: Circle())
            }.accessibilityLabel(t("Settings", "設定"))
        }
        .foregroundStyle(.primary)
        .font(.system(.subheadline, design: .monospaced)).shadow(color: .black.opacity(0.05), radius: 0, y: 2)
    }

    private func stat(_ icon: some View, _ value: String) -> some View {
        HStack(spacing: 4) { icon; Text(value).lineLimit(1) }
            .fixedSize()
            .padding(.horizontal, 9).padding(.vertical, 8).background(surface, in: Capsule())
    }

    // MARK: Indoors

    /// Secondary entries: small, quiet chips under the header, out of the thumb zone.
    private var shortcuts: some View {
        let questsLeft = game.quests(language: language).filter { !$0.isDone }.count
        return HStack(spacing: 6) {
            shortcut(.diary, t("Diary", "日記")) { sheet = .diary }
            shortcut(.quest, t("Quests", "任務"), badge: questsLeft > 0 ? "\(3 - questsLeft)/3" : nil) { sheet = .quests }
            shortcut(.dex, t("Dex", "圖鑑")) { sheet = .dex }
            shortcut(.album, t("Album", "相簿")) { sheet = .album }
            Spacer(minLength: 0)
        }
    }

    private func shortcut(_ glyph: PixelIcon.Glyph, _ label: String, badge: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                PixelIcon(glyph: glyph).frame(width: 16, height: 16)
                Text(label).font(.system(.caption, design: .monospaced)).lineLimit(1)
                if let badge {
                    Text(badge).font(.system(.caption2, design: .monospaced)).foregroundStyle(Theme.ink)
                        .padding(.horizontal, 4).padding(.vertical, 1).background(Theme.accent, in: Capsule())
                }
            }
            .fixedSize()
            .foregroundStyle(.primary)
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(surface.opacity(0.8), in: Capsule())
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue(badge ?? "")
    }

    /// The door in the room artwork also starts a walk; hidden from VoiceOver, which uses the Start button.
    private func door(in size: CGSize) -> some View {
        Button(action: startWalk) { Color.clear }
            .disabled(!model.canWrite)
            .frame(width: size.width * 0.32, height: size.height * 0.32)
            .position(x: size.width * 0.78, y: size.height * 0.31)
            .accessibilityHidden(true)
    }

    /// Floating Start button, plus the park saved with "Go" that the walk will be linked to.
    private var startControls: some View {
        let planned = spots.spot(id: plannedID.isEmpty ? nil : plannedID)
        return VStack(spacing: 10) {
            if let planned {
                HStack(spacing: 6) {
                    Button { sheet = .spots } label: {
                        Label(planned.name, systemImage: "flag.fill").lineLimit(1)
                    }
                    Button { plannedID = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .accessibilityLabel(t("Clear saved park", "清除已選地點"))
                }
                .font(.system(.footnote, design: .monospaced))
                .padding(.horizontal, 12).padding(.vertical, 7)
                .foregroundStyle(.white).background(Theme.overlay, in: Capsule())
            }
            Button { sheet = .search } label: {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                    Text(t("Find a park to walk", "搜尋散步地點")).lineLimit(1)
                    Spacer(minLength: 0)
                    PixelIcon(glyph: .map).frame(width: 20, height: 20)
                }
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(surface, in: Capsule())
                .overlay { Capsule().stroke(Theme.ink.opacity(0.15), lineWidth: 1) }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(t("Search parks", "搜尋地點"))
            .accessibilityHint(t("Find a park or spot to walk", "找公園或散步地點"))
            Button(action: startWalk) {
                HStack(spacing: 10) {
                    Image(systemName: "pawprint.fill").font(.system(size: 24, weight: .bold))
                    Text(t("Start walk", "開始散步")).font(.system(.title3, design: .monospaced).weight(.bold))
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, minHeight: 64)
                .background(Theme.accent, in: Capsule())
                .overlay { Capsule().stroke(Theme.ink, lineWidth: 3) }
                // Hard offset shadow, like the pixel-art pills.
                .background { Capsule().fill(Theme.ink.opacity(0.35)).offset(y: 4) }
            }
            .buttonStyle(.plain)
            .disabled(!model.canWrite)
            .accessibilityLabel(t("Start walk", "開始散步"))
            .accessibilityHint(planned.map { t("Walk at \($0.name)", "在 \($0.name) 散步") } ?? t("Starts tracking your walk", "開始記錄散步"))
            .sensoryFeedback(.impact(weight: .medium), trigger: model.activeWalk?.id)
        }
    }

    /// Starts tracking, linked to the saved park if there is one.
    private func startWalk() {
        let planned = plannedID.isEmpty ? nil : plannedID
        model.start(at: spots.spot(id: planned) == nil ? nil : planned)
        if model.activeWalk != nil { plannedID = "" }
    }

    // MARK: Walking

    private func walkStatus(_ walk: Walk) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    pill(WalkFormat.duration(walk.duration(at: context.date)), systemImage: "stopwatch")
                }
                Button { sheet = .route } label: { pill(WalkFormat.distance(walk, locale: language.locale), systemImage: "map") }
                    .accessibilityHint(t("Shows your route", "查看路線"))
                Spacer(minLength: 0)
                Button { sheet = .spots } label: {
                    pill(WalkFormat.spotName(walk, spots: spots, language: language), systemImage: "mappin.and.ellipse")
                }
                .accessibilityHint(t("Choose where you are", "選擇目前地點"))
            }
            Text(model.gpsStatus.message(in: language)).font(.caption)
                .padding(.horizontal, 10).padding(.vertical, 6).background(.regularMaterial, in: Capsule())
            if Heat.isHot(.now, language: language) {
                Label { Text(t("Hot pavement, try grass", "地面燙，走草地")) } icon: { PixelIcon(glyph: .sun).frame(width: 16) }
                    .font(.system(.caption, design: .monospaced)).foregroundStyle(Theme.ink)
                    .padding(.horizontal, 10).padding(.vertical, 6).background(Theme.accent.opacity(0.9), in: Capsule())
            }
        }
    }

    /// A visiting dog appears in the park; tapping it opens the encounter.
    private func visitor(in size: CGSize) -> some View {
        TimelineView(.periodic(from: .now, by: 5)) { context in
            let pending = game.pendingEncounters(at: context.date, language: language)
            Group {
                if let first = pending.first {
                    Button { sheet = .encounter } label: {
                        PixelDog(breed: first.breed, scarf: 0x7A7385).frame(width: 64, height: 64)
                            .overlay(alignment: .topTrailing) {
                                Text("!").font(.system(.headline, design: .monospaced)).foregroundStyle(Theme.ink)
                                    .frame(width: 24, height: 24).background(Theme.accent, in: Circle()).offset(x: 6, y: -8)
                            }
                            .overlay(alignment: .bottomTrailing) {
                                if pending.count > 1 {
                                    Text("\(pending.count)").font(.system(.caption, design: .monospaced)).foregroundStyle(.white)
                                        .frame(minWidth: 20, minHeight: 20).background(Theme.ink, in: Circle())
                                }
                            }
                    }
                    .accessibilityLabel(t("A dog nearby", "附近有狗狗"))
                    .position(x: size.width * 0.74, y: size.height * 0.62)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .onChange(of: pending.count) { old, new in
                guard new > old else { return }
                arrivals += 1
                toaster.show(t("A dog appeared!", "有狗狗出現了！"))
            }
        }
        .sensoryFeedback(.impact, trigger: arrivals)
    }

    private func walkBar(_ walk: Walk) -> some View {
        HStack(spacing: 14) {
            eventControl(.poop, walk: walk)
            eventControl(.pee, walk: walk)
            circleControl(.cam, label: t("Photo", "拍照"), badge: walk.photoIDs.isEmpty ? nil : walk.photoIDs.count) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) { showingCamera = true } else { showingLibraryPicker = true }
            }
            circleControl(.home, label: t("Head home and end walk", "回家，結束散步"), highlighted: true) { confirmingFinish = true }
        }
    }

    private func pill(_ text: String, systemImage: String? = nil) -> some View {
        Label { Text(text).lineLimit(1) } icon: { if let systemImage { Image(systemName: systemImage) } }
            .labelStyle(.titleAndIcon).font(.system(.subheadline, design: .monospaced))
            .padding(.horizontal, 12).padding(.vertical, 8)
            .foregroundStyle(.white).background(Theme.overlay, in: Capsule())
    }

    private func circleControl(_ glyph: PixelIcon.Glyph, label: String, highlighted: Bool = false, badge: Int? = nil,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            PixelIcon(glyph: glyph).frame(width: 30, height: 30).frame(width: 58, height: 58)
                .background(highlighted ? Theme.accent : Theme.overlay, in: Circle())
                .overlay(alignment: .topTrailing) { if let badge { countBadge(badge) } }
        }
        .accessibilityLabel(label)
        .accessibilityValue(badge.map(String.init) ?? "")
    }

    private func eventControl(_ kind: WalkEvent.Kind, walk: Walk) -> some View {
        circleControl(kind == .pee ? .drop : .poop, label: kind == .pee ? t("Log a pee", "記錄尿尿") : t("Log a poop", "記錄便便"),
                      badge: walk.count(of: kind)) { model.log(kind) }
            .sensoryFeedback(.increase, trigger: walk.count(of: kind))
    }

    private func countBadge(_ count: Int) -> some View {
        Text("\(count)").font(.system(.caption, design: .monospaced)).foregroundStyle(Theme.ink)
            .frame(minWidth: 22, minHeight: 22).background(.white, in: Capsule()).offset(x: 4, y: -4)
    }

    // MARK: Actions

    private func finishWalk() {
        let strangers = game.pendingEncounters(language: language).filter { !$0.fromEgg }.count
        guard let walk = model.finish() else { return }
        sheet = .finished(walk)
        if strangers > 0 {
            toaster.show(t("The dogs you didn't befriend went home. See them next time", "沒交到的狗狗回家了，下次再見"))
        }
    }

    private func savePhoto(_ data: Data) {
        let walk = model.activeWalk
        Task {
            do {
                let photo = try await photos.add(imageData: data, walkID: walk?.id, spotID: walk?.spotID)
                if walk != nil { model.attachPhoto(photo.id) }
                toaster.show(t("📷 Saved to album", "📷 收進相簿"))
            } catch {
                toaster.show(t("Photo didn't save", "照片沒存到"))
            }
        }
    }

    private func announceMilestones() {
        for message in game.newMilestones(language: language) { toaster.show(message) }
    }
}

private enum WalkSheet: Identifiable {
    case diary, quests, dex, album, spots, search, profile, settings, route, encounter
    case finished(Walk)

    var id: String {
        switch self {
        case .finished(let walk): "finished-\(walk.id)"
        default: String(describing: self)
        }
    }

    func title(in language: AppLanguage) -> String {
        switch self {
        case .settings: language.text("Settings", "設定")
        case .profile: language.text("My Dog", "我的狗狗")
        case .diary: language.text("Diary", "日記")
        case .quests: language.text("Quests", "任務")
        case .dex: language.text("Dex", "圖鑑")
        case .album: language.text("Album", "相簿")
        case .spots, .search: language.text("Spots", "地點")
        case .route: language.text("Current walk", "這次的散步")
        case .encounter: language.text("You met a dog", "遇到狗狗")
        case .finished: language.text("Walk complete", "散步完成")
        }
    }
}
