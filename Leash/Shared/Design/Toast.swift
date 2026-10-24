import SwiftUI
import Observation

/// Short confirmations shown over the scene, like the reference app's toasts.
@MainActor @Observable
final class Toaster {
    private(set) var message: String?
    private var queue: [String] = []
    private var isRunning = false

    /// Queues the message; each one shows for about two seconds.
    func show(_ text: String) {
        queue.append(text)
        guard !isRunning else { return }
        isRunning = true
        Task {
            while !queue.isEmpty {
                message = queue.removeFirst()
                try? await Task.sleep(for: .seconds(2.3))
                message = nil
                try? await Task.sleep(for: .seconds(0.3))
            }
            isRunning = false
        }
    }
}

struct ToastOverlay: ViewModifier {
    let toaster: Toaster
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let message = toaster.message {
                Text(message)
                    .font(.subheadline.weight(.medium))  // Monospaced design drops emoji glyphs.
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .foregroundStyle(.white)
                    .background(Theme.ink.opacity(0.9), in: Capsule())
                    .padding(.horizontal, 24).padding(.bottom, 110)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .accessibilityAddTraits(.updatesFrequently)
                    .onAppear { AccessibilityNotification.Announcement(message).post() }
            }
        }
        .animation(reduceMotion ? nil : .spring(duration: 0.3), value: toaster.message)
    }
}

extension View {
    func toasts(_ toaster: Toaster) -> some View { modifier(ToastOverlay(toaster: toaster)) }
}
