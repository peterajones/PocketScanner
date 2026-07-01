import SwiftUI

/// A sheet that lists saved signatures as thumbnails; tapping one calls `onPick`.
/// Used when signing with 2+ signatures, and as Move's fallback.
struct SignaturePicker: View {
    let signatures: [Signature]
    let onPick: (Signature) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            Group {
                if signatures.isEmpty {
                    ContentUnavailableView("No signatures",
                        systemImage: "signature",
                        description: Text("Add a signature in Settings first."))
                } else {
                    pickerList
                }
            }
            .navigationTitle("Choose a Signature")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { onCancel() } }
            }
        }
    }

    private var pickerList: some View {
        List(signatures) { sig in
            Button { onPick(sig) } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Image(uiImage: sig.image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: 90)
                        .padding(.vertical, 8)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.systemGray4)))
                    if let name = sig.name, !name.isEmpty {
                        Text(name)
                            .font(.subheadline)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }
}
