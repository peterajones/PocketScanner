import Foundation

/// A tip from the Tips screen that is also shown once, in context, in Main Library.
///
/// The Tips screen exists because features are hard to find, and then the screen itself
/// is hard to find. These three show where they apply instead. Their text is the Tips
/// screen's own, looked up by id, so no new copy needs translating.
enum ContextualTip: String, CaseIterable {
    case instantScan = "instant-scan"
    case search
    case contextMenu = "context-menu"

    /// The Tips screen entry this card shows.
    var entry: Tip? { Tip.all.first { $0.id == rawValue } }
}

/// Which contextual tip, if any, Main Library should show now.
///
/// Pure logic, kept apart from TipKit so it can be unit-tested — the same split as
/// `ReviewPromptPolicy`. TipKit only draws the card and remembers it was closed.
enum ContextualTipPolicy {

    /// Completed scans before suggesting Instant Scan: the person scans often enough
    /// to want a faster way, and it is never the first thing a new user sees.
    static let minimumScans = 3

    /// Documents before suggesting search or the context menu: with fewer, the whole
    /// library fits on screen and neither earns its interruption.
    static let minimumDocuments = 5

    /// At most one tip, in this order. TipGroup would do the ordering, but it needs
    /// iOS 18 and the app supports 17.6.
    static func current(scanCount: Int,
                        documentCount: Int,
                        hasUsedInstantScan: Bool,
                        dismissed: Set<ContextualTip>) -> ContextualTip? {
        ContextualTip.allCases.first { tip in
            guard !dismissed.contains(tip) else { return false }
            switch tip {
            case .instantScan: return scanCount >= minimumScans && !hasUsedInstantScan
            case .search, .contextMenu: return documentCount >= minimumDocuments
            }
        }
    }
}

/// Persists what `ContextualTipPolicy` reads beyond the library itself. Like
/// `ReviewPromptTracker`, every property reads through to `UserDefaults`.
struct ContextualTipTracker {

    private let defaults: UserDefaults

    /// False in UI-test runs, where a card would shift the rows the tests tap, and for
    /// `-SeedDemoData` screenshot shoots, where it would end up in the App Store images.
    private let isEnabled: Bool

    private static let usedInstantScanKey = "ContextualTip.usedInstantScan"
    private static let dismissedKey = "ContextualTip.dismissed"

    static var isEnabledForLaunch: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        return !arguments.contains("-UITestMode") && !arguments.contains("-SeedDemoData")
    }

    init(defaults: UserDefaults = .standard, isEnabled: Bool = ContextualTipTracker.isEnabledForLaunch) {
        self.defaults = defaults
        self.isEnabled = isEnabled
    }

    var hasUsedInstantScan: Bool { defaults.bool(forKey: Self.usedInstantScanKey) }

    /// Call when an instant scan is saved: someone already using it needs no tip about it.
    func recordInstantScanUsed() {
        defaults.set(true, forKey: Self.usedInstantScanKey)
    }

    #if DEBUG
    /// For the `-TipsReset` launch argument, so a device check can see every tip again.
    func resetForDeviceChecks() {
        defaults.removeObject(forKey: Self.usedInstantScanKey)
        defaults.removeObject(forKey: Self.dismissedKey)
    }
    #endif

    /// Tips the person has closed. Kept here rather than read back from TipKit, whose
    /// record loads only after launch: asked too early, it reports nothing closed.
    var dismissed: Set<ContextualTip> {
        Set((defaults.stringArray(forKey: Self.dismissedKey) ?? []).compactMap(ContextualTip.init))
    }

    /// Call when TipKit reports the card closed.
    func recordDismissed(_ tip: ContextualTip) {
        let updated = dismissed.union([tip]).map(\.rawValue).sorted()
        defaults.set(updated, forKey: Self.dismissedKey)
    }

    func current(scanCount: Int, documentCount: Int) -> ContextualTip? {
        guard isEnabled else { return nil }
        return ContextualTipPolicy.current(scanCount: scanCount,
                                           documentCount: documentCount,
                                           hasUsedInstantScan: hasUsedInstantScan,
                                           dismissed: dismissed)
    }
}
