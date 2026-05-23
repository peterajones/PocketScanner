import Foundation
import Observation
import LocalAuthentication

@MainActor
@Observable
final class AppLockSettings {

    /// Threshold beyond which a foreground return re-engages the lock.
    static let backgroundThreshold: TimeInterval = 30

    /// User-facing persistent toggle.
    var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: Self.enabledKey) }
    }

    /// In-memory: true when the lock UI is showing.
    private(set) var isLocked: Bool

    /// In-memory: timestamp of the last scene-deactivation. nil when foregrounded.
    private(set) var recordedBackgroundedAt: Date?

    private static let enabledKey = "AppLockSettings.isEnabled"

    /// Production initializer reads persisted state.
    convenience init() {
        let stored = UserDefaults.standard.bool(forKey: Self.enabledKey)
        self.init(isEnabled: stored, backgroundedAt: nil)
    }

    init(isEnabled: Bool, backgroundedAt: Date?) {
        self.isEnabled = isEnabled
        self.recordedBackgroundedAt = backgroundedAt
        // Cold launch starts in the locked state if enabled; LockGate triggers
        // auth on appear and unlocks on success.
        self.isLocked = isEnabled
    }

    // MARK: - State transitions

    func lock() { isLocked = true }
    func unlock() { isLocked = false }
    func recordBackground() { recordedBackgroundedAt = Date() }
    func clearBackground() { recordedBackgroundedAt = nil }

    /// Returns true if we should re-engage the lock on foregrounding.
    /// Pure function of current state; safe to call repeatedly.
    func shouldRelock(now: Date = Date()) -> Bool {
        guard isEnabled, let backgroundedAt = recordedBackgroundedAt else { return false }
        return now.timeIntervalSince(backgroundedAt) > Self.backgroundThreshold
    }

    // MARK: - LocalAuthentication (not unit-tested — hardware call)

    /// Show the system Face ID / passcode prompt and return whether it succeeded.
    func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            return false
        }
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
        } catch {
            return false
        }
    }
}
