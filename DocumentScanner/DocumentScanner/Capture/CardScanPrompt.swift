import SwiftUI

/// A capture `CardScan.route` wants to ask about before it is named and saved.
struct CardScanPending: Identifiable {
    let id = UUID()
    let offer: CardScan.Offer
    let images: [UIImage]
}

/// The question asked after a card-shaped capture, shared by the library and folder
/// screens. Dismissing the dialog without choosing runs the cancel-role button, which
/// always keeps the capture as it is, so nothing scanned is ever lost.
struct CardScanPrompt: ViewModifier {
    @Binding var pending: CardScanPending?
    /// Reopen the camera for the back of this front.
    let onScanBack: (UIImage) -> Void
    /// Name and save these pages.
    let onSave: ([UIImage]) -> Void

    /// From iOS 26 an iPhone confirmation dialog hides its cancel-role button.
    private var cancelIsHidden: Bool {
        if #available(iOS 26, *) { true } else { false }
    }

    func body(content: Content) -> some View {
        content.confirmationDialog(
            title,
            isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
            titleVisibility: .visible,
            presenting: pending
        ) { pending in
            let buttons = CardScan.buttons(for: pending.offer, cancelIsHidden: cancelIsHidden)
            ForEach(Array(buttons.enumerated()), id: \.offset) { _, button in
                Button(label(button.choice), role: button.isCancel ? .cancel : nil) {
                    perform(button.choice, with: pending.images)
                }
            }
        }
    }

    private func perform(_ choice: CardScan.Choice, with images: [UIImage]) {
        switch choice {
        case .scanBack:
            if let front = images.first { onScanBack(front) }
        case .combine:
            onSave([CardScan.stitch(front: images[0], back: images[1])])
        case .continueWithFront, .keepAsTwoPages:
            onSave(images)
        }
    }

    private func label(_ choice: CardScan.Choice) -> LocalizedStringKey {
        switch choice {
        case .scanBack: "Scan Back"
        case .continueWithFront: "Continue"
        case .combine: "Combine"
        case .keepAsTwoPages: "Keep as Two Pages"
        }
    }

    private var title: Text {
        switch pending?.offer {
        case .combine: Text("Combine as front and back?")
        default: Text("Scan the other side?")
        }
    }
}
