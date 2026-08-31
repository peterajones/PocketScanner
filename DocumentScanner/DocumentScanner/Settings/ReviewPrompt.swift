import Foundation
import SwiftUI
import StoreKit

/// When it is appropriate to ask iOS to consider showing the App Store rating prompt.
///
/// Pure logic, deliberately separated from the StoreKit call so it can be unit-tested —
/// the same split `AppLockSettings.shouldRelock(now:)` uses for the re-lock rule.
///
/// A `true` here does NOT mean a prompt appears. StoreKit decides that, applies its own
/// per-user limits (Apple's guidance is at most three prompts per 365 days), and reports
/// nothing back. Users can also disable rating requests entirely in Settings. So this
/// answers only "is now a reasonable moment to ask", never "was the user asked".
enum ReviewPromptPolicy {

    /// Don't ask a stranger. Three completed jobs — a scan saved, a document signed —
    /// means the app has actually worked for this person, not just been installed.
    static let minimumScans = 3

    /// Never ask twice inside this window, even across app versions. StoreKit throttles
    /// too, but it does so silently — throttled requests are simply spent, so pacing on
    /// our side keeps them for moments worth having.
    static let minimumInterval: TimeInterval = 90 * 24 * 60 * 60   // 90 days

    static func shouldRequest(scanCount: Int,
                              lastPromptDate: Date?,
                              lastPromptVersion: String?,
                              currentVersion: String,
                              now: Date = Date()) -> Bool {
        guard scanCount >= minimumScans else { return false }
        // One ask per version at most: a user who ignored it on 3.3 shouldn't meet it
        // again the moment they update.
        guard lastPromptVersion != currentVersion else { return false }
        if let lastPromptDate, now.timeIntervalSince(lastPromptDate) < minimumInterval {
            return false
        }
        return true
    }
}

/// Persists the counters `ReviewPromptPolicy` reads.
///
/// A value type with no stored mutable state — every property reads through to
/// `UserDefaults` on access. That is deliberate: unlike `AlertCenter` and
/// `AppLockSettings`, nothing here drives a view, so there is nothing to observe and no
/// reason to be `@Observable` or main-actor isolated.
struct ReviewPromptTracker {

    private let defaults: UserDefaults

    /// False in UI-test runs. In a Debug build `requestReview()` bypasses StoreKit's
    /// throttling and shows the sheet EVERY time it is called, which would drop a system
    /// dialog on top of `DocScannerUITests` mid-scan and fail it. Release builds are
    /// unaffected either way.
    private let isEnabled: Bool

    private static let scanCountKey = "ReviewPrompt.scanCount"
    private static let lastDateKey = "ReviewPrompt.lastPromptDate"
    private static let lastVersionKey = "ReviewPrompt.lastPromptVersion"

    init(defaults: UserDefaults = .standard,
         isEnabled: Bool = !ProcessInfo.processInfo.arguments.contains("-UITestMode")) {
        self.defaults = defaults
        self.isEnabled = isEnabled
    }

    var scanCount: Int { defaults.integer(forKey: Self.scanCountKey) }
    var lastPromptDate: Date? { defaults.object(forKey: Self.lastDateKey) as? Date }
    var lastPromptVersion: String? { defaults.string(forKey: Self.lastVersionKey) }

    /// Current `CFBundleShortVersionString`, e.g. "3.4".
    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
    }

    /// Call after a piece of work is successfully written to disk — a scan saved, a
    /// signature placed. Not when capture ends, and never after a failure.
    func recordSuccess() {
        defaults.set(scanCount + 1, forKey: Self.scanCountKey)
    }

    func shouldRequest(currentVersion: String = ReviewPromptTracker.currentVersion,
                       now: Date = Date()) -> Bool {
        guard isEnabled else { return false }
        return ReviewPromptPolicy.shouldRequest(scanCount: scanCount,
                                                lastPromptDate: lastPromptDate,
                                                lastPromptVersion: lastPromptVersion,
                                                currentVersion: currentVersion,
                                                now: now)
    }

    /// Record that we asked. "Asked" means we called StoreKit — whether anything was
    /// shown is unknowable, so this deliberately counts requests, not appearances.
    func recordRequested(currentVersion: String = ReviewPromptTracker.currentVersion,
                         now: Date = Date()) {
        defaults.set(now, forKey: Self.lastDateKey)
        defaults.set(currentVersion, forKey: Self.lastVersionKey)
    }
}

extension ReviewPromptTracker {

    /// Record a completed job and, if the policy allows it, ask StoreKit to consider the
    /// rating prompt. This is the whole sequence every call site needs, kept in one place
    /// so the three of them cannot drift apart.
    ///
    /// Call this from the view that *presented* the work, not from a sheet that is being
    /// dismissed — a system dialog raised by a disappearing view silently never appears.
    ///
    /// `@MainActor` because `RequestReviewAction` is; every call site is a SwiftUI view.
    @MainActor
    func recordSuccessAndMaybeRequest(using requestReview: RequestReviewAction) {
        recordSuccess()
        guard shouldRequest() else { return }
        recordRequested()
        requestReview()
    }
}

private struct ReviewPromptTrackerKey: EnvironmentKey {
    static let defaultValue = ReviewPromptTracker()
}

extension EnvironmentValues {
    var reviewPrompt: ReviewPromptTracker {
        get { self[ReviewPromptTrackerKey.self] }
        set { self[ReviewPromptTrackerKey.self] = newValue }
    }
}
