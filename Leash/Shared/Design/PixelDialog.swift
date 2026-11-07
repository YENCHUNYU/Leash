import SwiftUI

/// A rectangle with stair-stepped corners, like a pixel-art window.
nonisolated struct PixelShape: InsettableShape {
    var step: CGFloat = 4
    var inset: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: inset, dy: inset)
        let s = min(step, r.width / 4, r.height / 4)
        let (x0, y0, x1, y1) = (r.minX, r.minY, r.maxX, r.maxY)
        var path = Path()
        path.addLines([
            CGPoint(x: x0 + 2 * s, y: y0), CGPoint(x: x1 - 2 * s, y: y0),
            CGPoint(x: x1 - 2 * s, y: y0 + s), CGPoint(x: x1 - s, y: y0 + s),
            CGPoint(x: x1 - s, y: y0 + 2 * s), CGPoint(x: x1, y: y0 + 2 * s),
            CGPoint(x: x1, y: y1 - 2 * s), CGPoint(x: x1 - s, y: y1 - 2 * s),
            CGPoint(x: x1 - s, y: y1 - s), CGPoint(x: x1 - 2 * s, y: y1 - s),
            CGPoint(x: x1 - 2 * s, y: y1), CGPoint(x: x0 + 2 * s, y: y1),
            CGPoint(x: x0 + 2 * s, y: y1 - s), CGPoint(x: x0 + s, y: y1 - s),
            CGPoint(x: x0 + s, y: y1 - 2 * s), CGPoint(x: x0, y: y1 - 2 * s),
            CGPoint(x: x0, y: y0 + 2 * s), CGPoint(x: x0 + s, y: y0 + 2 * s),
            CGPoint(x: x0 + s, y: y0 + s), CGPoint(x: x0 + 2 * s, y: y0 + s),
        ])
        path.closeSubpath()
        return path
    }

    func inset(by amount: CGFloat) -> PixelShape { PixelShape(step: step, inset: inset + amount) }
}

/// The pixel window: lawn-green frame, cream panel, yellow pill buttons.
private struct PixelDialogView: View {
    let title: String
    let message: String?
    let confirmLabel: String
    let isDestructive: Bool
    let cancelLabel: String?
    let onFinish: (_ confirmed: Bool) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false
    @State private var closing = false

    private static let frame = Color(leashHex: 0x5BAF6A)
    private static let danger = Color(leashHex: 0xE2574C)
    private var panel: Color { colorScheme == .dark ? Theme.surface(.dark) : Color(leashHex: 0xFFF8EC) }

    var body: some View {
        ZStack {
            Theme.ink.opacity(shown ? 0.45 : 0)
                .ignoresSafeArea()
                .onTapGesture { if cancelLabel != nil { close(confirmed: false) } }
                .accessibilityHidden(true)
            window
                .scaleEffect(shown || reduceMotion ? 1 : 0.85)
                .opacity(shown ? 1 : 0)
        }
        .onAppear {
            withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .spring(duration: 0.28, bounce: 0.35)) { shown = true }
        }
    }

    private var window: some View {
        VStack(spacing: 0) {
            titleBar
            content
                .padding(.horizontal, 18).padding(.vertical, 20)
                .frame(maxWidth: .infinity)
                .background(PixelShape(step: 4).fill(panel))
                .overlay(PixelShape(step: 4).strokeBorder(Theme.ink, lineWidth: 3))
                .background { PixelShape(step: 4).fill(Theme.ink.opacity(0.18)).offset(y: 4) }
        }
        .padding([.horizontal, .bottom], 12)
        .background(PixelShape(step: 6).fill(Self.frame))
        .overlay(PixelShape(step: 6).strokeBorder(Theme.ink, lineWidth: 3))
        .background { PixelShape(step: 6).fill(Theme.ink.opacity(0.4)).offset(y: 6) }
        .frame(maxWidth: 340)
        .padding(.horizontal, 28)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) { if cancelLabel != nil { close(confirmed: false) } }
    }

    /// The "— □ ×" window controls; × works as cancel.
    private var titleBar: some View {
        HStack(spacing: 8) {
            Spacer()
            Rectangle().fill(Theme.ink).frame(width: 12, height: 3)
            Rectangle().strokeBorder(Theme.ink, lineWidth: 3).frame(width: 11, height: 11)
            Button { close(confirmed: false) } label: {
                Image(systemName: "xmark").font(.system(size: 13, weight: .black)).foregroundStyle(Theme.ink)
                    .frame(width: 30, height: 34).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .opacity(cancelLabel == nil ? 0 : 1)
            .disabled(cancelLabel == nil)
            .accessibilityLabel(cancelLabel ?? "")
        }
        .padding(.top, 2)
        .frame(height: 36)
        .accessibilityElement(children: .contain)
    }

    private var content: some View {
        VStack(spacing: 14) {
            Text(title)
                .font(.system(.title3, design: .monospaced).weight(.heavy))
                .foregroundStyle(colorScheme == .dark ? .white : Theme.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if let message {
                Text(message)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.7) : Theme.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { buttons }
                VStack(spacing: 12) { buttons }
            }
            .padding(.top, 4)
        }
    }

    @ViewBuilder private var buttons: some View {
        Button(confirmLabel) { close(confirmed: true) }
            .buttonStyle(PixelPillStyle(fill: isDestructive ? Self.danger : Theme.accent))
        if let cancelLabel {
            Button(cancelLabel) { close(confirmed: false) }
                .buttonStyle(PixelPillStyle(fill: Theme.accent))
        }
    }

    private func close(confirmed: Bool) {
        guard !closing else { return }
        closing = true
        withAnimation(.easeIn(duration: 0.14)) { shown = false } completion: { onFinish(confirmed) }
    }
}

/// Chunky pill button with a hard drop shadow that presses down when tapped.
struct PixelPillStyle: ButtonStyle {
    var fill: Color = Theme.accent

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .font(.system(.headline, design: .monospaced).weight(.heavy))
            .foregroundStyle(Theme.ink)
            .lineLimit(1).minimumScaleFactor(0.7)
            .padding(.horizontal, 18)
            .frame(minWidth: 96, minHeight: 46)
            .background(PixelShape(step: 3).fill(fill))
            .overlay(alignment: .bottomTrailing) {
                Rectangle().fill(.white.opacity(0.7)).frame(width: 4, height: 4).padding(.trailing, 9).padding(.bottom, 8)
            }
            .overlay(PixelShape(step: 3).strokeBorder(Theme.ink, lineWidth: 3))
            .offset(y: pressed ? 3 : 0)
            .background { PixelShape(step: 3).fill(Theme.ink.opacity(0.35)).offset(y: 3) }
            .contentShape(Rectangle())
    }
}

private struct PixelDialogModifier: ViewModifier {
    let title: String
    let message: String?
    @Binding var isPresented: Bool
    let confirmLabel: String
    let isDestructive: Bool
    let cancelLabel: String?
    let action: () -> Void

    @State private var presented = false
    @State private var confirmed = false

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $presented, onDismiss: {
                // Run after the cover is gone, so the action can present a sheet of its own.
                if confirmed { action() }
                confirmed = false
                isPresented = false
            }) {
                PixelDialogView(title: title, message: message, confirmLabel: confirmLabel,
                                isDestructive: isDestructive, cancelLabel: cancelLabel) { didConfirm in
                    confirmed = didConfirm
                    setPresented(false)
                }
                .presentationBackground(.clear)
            }
            .onChange(of: isPresented, initial: true) { _, newValue in
                if newValue != presented { setPresented(newValue) }
            }
    }

    /// The window animates itself, so skip the cover's slide-up.
    private func setPresented(_ value: Bool) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { presented = value }
    }
}

extension View {
    /// A pixel-art confirm window. `action` runs only when the confirm button is tapped.
    /// Pass `cancel: nil` for a single-button notice.
    func pixelDialog(_ title: String, message: String? = nil, isPresented: Binding<Bool>,
                     confirm: String, destructive: Bool = false, cancel: String?,
                     action: @escaping () -> Void = {}) -> some View {
        modifier(PixelDialogModifier(title: title, message: message, isPresented: isPresented,
                                     confirmLabel: confirm, isDestructive: destructive,
                                     cancelLabel: cancel, action: action))
    }
}
