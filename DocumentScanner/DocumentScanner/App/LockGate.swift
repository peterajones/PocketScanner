import SwiftUI

/// Wraps content in an auth-gated screen. When the lock is active, shows
/// an opaque lock UI; when not, shows the content. Reacts to scene-phase
/// changes to re-lock after >30s in background.
struct LockGate<Content: View>: View {
    @Bindable var lockSettings: AppLockSettings
    let instantScan: InstantScanCoordinator
    @ViewBuilder let content: () -> Content
    @Environment(\.scenePhase) private var scenePhase

    /// The lock still covers the library during an instant scan; only the
    /// automatic Face ID prompt waits, so it doesn't appear over the camera or
    /// the "Saving…" state. The Unlock button is unaffected.
    static func shouldAutoPrompt(isLocked: Bool, instantScanBusy: Bool) -> Bool {
        isLocked && !instantScanBusy
    }

    /// A cancelled auto-prompt (its key changed, e.g. an instant scan started) never
    /// unlocks, even if Face ID happened to succeed as the task was withdrawn.
    static func shouldUnlockAfterAutoPrompt(authenticated: Bool, cancelled: Bool) -> Bool {
        authenticated && !cancelled
    }

    private struct PromptKey: Hashable {
        let isLocked: Bool
        let instantScanBusy: Bool
    }

    var body: some View {
        ZStack {
            content()
            if lockSettings.isLocked {
                lockScreen
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            lockSettings.scenePhaseChanged(to: newPhase)
        }
        .task(id: PromptKey(isLocked: lockSettings.isLocked, instantScanBusy: instantScan.isBusy)) {
            // Auto-prompt on cold launch (isLocked started true) and on every
            // relock. Deferred while an instant scan runs; re-keys and fires once
            // it finishes if the app is still locked. When the key changes
            // mid-prompt, SwiftUI cancels this task: `authenticate` invalidates
            // its LAContext, which withdraws the system prompt, and the
            // cancelled task never unlocks.
            if Self.shouldAutoPrompt(isLocked: lockSettings.isLocked, instantScanBusy: instantScan.isBusy) {
                let ok = await lockSettings.authenticate(reason: "Unlock your document library")
                if Self.shouldUnlockAfterAutoPrompt(authenticated: ok, cancelled: Task.isCancelled) {
                    lockSettings.unlock()
                }
            }
        }
    }

    private var lockScreen: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 24) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.tint)
                Text("Pocket Scanner is locked")
                    .font(.title2.weight(.semibold))
                Button("Unlock with Face ID") {
                    Task {
                        let ok = await lockSettings.authenticate(reason: "Unlock your document library")
                        if ok { lockSettings.unlock() }
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
    }
}
