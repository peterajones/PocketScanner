import SwiftUI

/// The trailing swipe-to-delete button, used everywhere a row can be deleted.
///
/// **Why this exists rather than a bare `Button(role: .destructive)`.**
///
/// `role: .destructive` supplies a *default* red, and an explicit `.tint()` higher in the
/// view tree outranks it. Since v3.6 the app applies `.tint(...)` at the `WindowGroup` root
/// so the accent colour follows the user's choice — which silently repainted every
/// swipe-to-delete button in the app from red to the accent colour. A delete action that
/// does not look destructive is a genuine hazard, and it is easy to miss because the code
/// still says `.destructive`.
///
/// Alerts are unaffected: they render through UIKit, which ignores the SwiftUI environment
/// tint, so a destructive alert button stays red without help. Verified on device.
///
/// Using this type rather than pasting `.tint(.red)` at each call site keeps the reason in
/// one place and means the next swipe action added cannot quietly get it wrong.
struct DeleteSwipeButton: View {
    let action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
    }

    var body: some View {
        Button(role: .destructive, action: action) {
            Label("Delete", systemImage: "trash")
        }
        // Explicit, because .destructive alone loses to the root .tint.
        .tint(.red)
    }
}
