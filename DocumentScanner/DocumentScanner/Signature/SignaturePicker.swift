import SwiftUI

/// A sheet that lists saved signatures as thumbnails; tapping one calls `onPick`.
/// Used when signing with 2+ signatures, and as Move's fallback.
struct SignaturePicker: View {
    let signatures: [Signature]
    let onPick: (Signature) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            List(signatures) { sig in
                Button { onPick(sig) } label: {
                    Image(uiImage: sig.image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: 90)
                        .padding(.vertical, 8)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.systemGray4)))
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Choose a Signature")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { onCancel() } }
            }
        }
    }
}
