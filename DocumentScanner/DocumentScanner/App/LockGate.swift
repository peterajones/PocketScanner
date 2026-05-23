import SwiftUI

/// Wraps content in an auth-gated screen. When the lock is active, shows
/// an opaque lock UI; when not, shows the content. Reacts to scene-phase
/// changes to re-lock after >30s in background.
struct LockGate<Content: View>: View {
    @Bindable var lockSettings: AppLockSettings
    @ViewBuilder let content: () -> Content
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            content()
            if lockSettings.isLocked {
                lockScreen
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                if lockSettings.shouldRelock() {
                    lockSettings.lock()
                }
                lockSettings.clearBackground()
            case .inactive, .background:
                lockSettings.recordBackground()
            @unknown default:
                break
            }
        }
        .task(id: lockSettings.isLocked) {
            // Auto-prompt on cold launch (isLocked started true) and any
            // explicit relock that doesn't already have an auth in flight.
            if lockSettings.isLocked {
                let ok = await lockSettings.authenticate(reason: "Unlock your document library")
                if ok { lockSettings.unlock() }
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
                Text("Mobile Scanner is locked")
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
