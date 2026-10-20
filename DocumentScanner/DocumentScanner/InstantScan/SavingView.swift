import SwiftUI

/// Opaque screen shown while an instant scan is recognised and saved. It deliberately
/// shows no page content: with the app lock on, nothing may be visible before Face ID.
struct SavingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text(String(localized: "Saving…",
                        comment: "Instant scan: shown while the scan is recognised and saved"))
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

#Preview {
    SavingView()
}
