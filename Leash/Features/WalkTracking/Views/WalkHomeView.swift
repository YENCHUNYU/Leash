import SwiftUI

/// Full-screen room/park scene with the header, live walk stats and walk controls.
struct WalkHomeView: View {
    @Bindable var model: WalkViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.appLanguage) private var language
    @State private var confirmingFinish = false
    @State private var sheet: WalkSheet?
    private func t(_ english: String, _ chinese: String) -> String { language.text(english, chinese) }
    private var surface: Color { Theme.surface(colorScheme) }

    var body: some View {
        GeometryReader { geometry in
            scene(safeArea: geometry.safeAreaInsets)
                .ignoresSafeArea()
        }
        .sheet(item: $sheet) { selected in
            NavigationStack {
                sheetContent(selected)
                    .navigationTitle(selected.title(in: language))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button(t("Close", "關閉")) { sheet = nil } } }
            }.presentationDetents([.large]).presentationDragIndicator(.visible)
        }
        .confirmationDialog(t("Finish and save this walk?", "回家並儲存這次散步？"), isPresented: $confirmingFinish, titleVisibility: .visible) {
            Button(t("Finish walk", "回家，結束散步")) {
                if model.finish() { sheet = .diary }
            }
        }
        .alert("Leash", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } }), presenting: model.error) { _ in
            Button(t("OK", "好")) { model.error = nil }
        } message: { Text($0.message(in: language)) }
    }

    @ViewBuilder private func sheetContent(_ selected: WalkSheet) -> some View {
        switch selected {
        case .settings: SettingsView()
        case .diary: WalkDiaryView(walks: model.archive.completed)
        case .route:
            if let walk = model.activeWalk { WalkSummaryView(walk: walk) }
            else { ContentUnavailableView(t("No route yet", "還沒有散步路線"), systemImage: "map", description: Text(t("Start a walk to record your route.", "出門散步後，就能在這裡查看路線。"))) }
        }
    }

    private var header: some View {
        HStack(spacing: 7) {
            Text(t("My dog", "我的狗狗")).font(.system(.title3, design: .monospaced)).padding(.horizontal, 16).padding(.vertical, 9)
                .background(surface, in: Capsule())
            Spacer(minLength: 0)
            Label("\(model.archive.completed.count)", systemImage: "pawprint.fill")
                .padding(9).background(surface, in: Capsule()).accessibilityLabel(t("\(model.archive.completed.count) completed walks", "已完成 \(model.archive.completed.count) 次散步"))
            Label("\(model.totalMinutes)", systemImage: "clock.fill")
                .padding(9).background(surface, in: Capsule()).accessibilityLabel(t("Total walking minutes", "累計散步分鐘"))
            Button { sheet = .settings } label: {
                Image(systemName: "gearshape.fill").padding(11).background(surface, in: Circle())
            }.foregroundStyle(.primary).accessibilityLabel(t("Settings", "設定"))
        }.font(.system(.subheadline, design: .monospaced)).shadow(color: .black.opacity(0.05), radius: 0, y: 2)
    }

    private func scene(safeArea: EdgeInsets) -> some View {
        GeometryReader { geometry in
            let size = geometry.size
            ZStack(alignment: .topLeading) {
                PixelScene(outdoors: model.activeWalk != nil)
                WanderingDog(outdoors: model.activeWalk != nil, name: t("My dog", "我的狗狗"))
                VStack(spacing: 12) {
                    header
                    if let walk = model.activeWalk {
                        HStack(spacing: 6) {
                            TimelineView(.periodic(from: .now, by: 1)) { context in
                                pill(WalkFormat.duration(walk.duration(at: context.date)), systemImage: "stopwatch")
                            }
                            pill(WalkFormat.distance(walk, locale: language.locale))
                            Spacer(minLength: 0)
                        }
                        Text(model.gpsStatus.message(in: language)).font(.caption)
                            .padding(8).background(.regularMaterial, in: Capsule())
                    } else {
                        HStack(spacing: 6) {
                            Button { sheet = .diary } label: { pill(t("Diary", "日記"), systemImage: "book.closed.fill") }
                            Spacer()
                        }
                    }
                    Spacer()
                    if let walk = model.activeWalk {
                        HStack(spacing: 18) {
                            eventControl(.poop, walk: walk)
                            eventControl(.pee, walk: walk)
                            circleControl(.map, label: t("View route", "查看路線"), highlighted: false) { sheet = .route }
                            circleControl(.home, label: t("Finish walk", "回家，結束散步"), highlighted: true) { confirmingFinish = true }
                        }
                    }
                    if !model.canWrite {
                        Button(t("Reload walks", "重新載入散步紀錄")) { model.reload() }
                            .padding(10).background(.regularMaterial, in: Capsule())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, safeArea.top + 12)
                .padding(.bottom, safeArea.bottom + 16)
                if model.activeWalk == nil {
                    // Hit area over the door in the room artwork.
                    Button { model.start() } label: {
                        VStack {
                            pill(t("Tap to head out", "點門出發"))
                            Color.clear
                        }
                    }
                    .disabled(!model.canWrite)
                    .frame(width: size.width * 0.32, height: size.height * 0.32)
                    .position(x: size.width * 0.78, y: size.height * 0.31)
                    .accessibilityLabel(t("Start walk", "出門散步"))
                }
            }
        }
    }

    private func pill(_ text: String, systemImage: String? = nil) -> some View {
        Label { Text(text) } icon: { if let systemImage { Image(systemName: systemImage) } }
            .labelStyle(.titleAndIcon).font(.system(.subheadline, design: .monospaced))
            .padding(.horizontal, 12).padding(.vertical, 8)
            .foregroundStyle(.white).background(Theme.overlay, in: Capsule())
    }

    private func circleButtonFace(_ glyph: PixelIcon.Glyph, highlighted: Bool) -> some View {
        PixelIcon(glyph: glyph).frame(width: 30, height: 30).frame(width: 58, height: 58)
            .background(highlighted ? Theme.accent : Theme.overlay, in: Circle())
    }

    private func circleControl(_ glyph: PixelIcon.Glyph, label: String, highlighted: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) { circleButtonFace(glyph, highlighted: highlighted) }
            .accessibilityLabel(label)
    }

    private func eventControl(_ kind: WalkEvent.Kind, walk: Walk) -> some View {
        Button { model.log(kind) } label: {
            circleButtonFace(kind == .pee ? .drop : .poop, highlighted: false)
                .overlay(alignment: .topTrailing) {
                    Text("\(walk.count(of: kind))")
                        .font(.system(.caption, design: .monospaced)).foregroundStyle(Theme.ink)
                        .frame(minWidth: 22, minHeight: 22).background(.white, in: Capsule()).offset(x: 4, y: -4)
                }
        }
        .accessibilityLabel(kind == .pee ? t("Log a pee", "記錄尿尿") : t("Log a poop", "記錄便便"))
        .accessibilityValue("\(walk.count(of: kind))")
    }
}

private enum WalkSheet: String, Identifiable {
    case diary, route, settings
    var id: String { rawValue }

    func title(in language: AppLanguage) -> String {
        switch self {
        case .settings: language.text("Settings", "設定")
        case .diary: language.text("Walk diary", "散步日記")
        case .route: language.text("Current walk", "這次的散步")
        }
    }
}
