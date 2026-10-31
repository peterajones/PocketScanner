import SwiftUI
import TipKit

/// TipKit's side of a `ContextualTip`: it draws the card. Written `TipKit.Tip` because
/// the app's own `Tip` (the Tips screen entry) wins inside this module.
struct ContextualTipKitTip: TipKit.Tip {
    let tip: ContextualTip

    var id: String { "contextual.\(tip.rawValue)" }
    var title: Text { Text(tip.entry?.title ?? "") }
    var message: Text? { tip.entry.map { Text($0.body) } }
}

/// The one contextual tip Main Library shows, if any, as an inline card above the list.
///
/// `ContextualTipTracker` picks the tip and remembers which were closed; TipKit draws it
/// and decides whether it may show today (`.displayFrequency(.daily)`, set at launch).
/// Closed tips are not read back from TipKit: its record loads after launch, and a card
/// that asked too early picked a tip TipKit then refused to draw, leaving nothing.
struct ContextualTipCard: View {
    let documentCount: Int

    @Environment(\.reviewPrompt) private var reviewPrompt
    /// Bumped when a tip is closed, so `current` is read again.
    @State private var closedCount = 0

    private let tracker = ContextualTipTracker()

    private var current: ContextualTip? {
        tracker.current(scanCount: reviewPrompt.scanCount, documentCount: documentCount)
    }

    var body: some View {
        let _ = closedCount
        if let current {
            let kitTip = ContextualTipKitTip(tip: current)
            // The listener hangs off the card itself: modifiers on empty content in a
            // List never run, so a card that waited to be told to appear never did.
            TipView(kitTip)
                // In the list, TipView's own card is enough: no row box around it.
                // Both are no-ops in the grid's ScrollView.
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                .task(id: current) {
                    for await status in kitTip.statusUpdates {
                        if case .invalidated = status {
                            tracker.recordDismissed(current)
                            closedCount += 1
                        }
                    }
                }
        }
    }
}
