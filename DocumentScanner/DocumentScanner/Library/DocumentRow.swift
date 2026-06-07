import SwiftUI

struct DocumentRow: View {
    let summary: DocumentSummary

    var body: some View {
        HStack(spacing: 12) {
            if summary.isCorrupt {
                ZStack {
                    RoundedRectangle(cornerRadius: 4).fill(Color(.systemGray6))
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
                .frame(width: 44, height: 56)
            } else {
                DocumentThumbnail(url: summary.url, size: CGSize(width: 88, height: 112))
                    .frame(width: 44, height: 56)
                    .background(Color(.systemGray6))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(.systemGray4)))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(summary.displayName)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                Text(summary.formattedSubtitle)
                    .font(.footnote)
                    .foregroundStyle(summary.isCorrupt ? .orange : .secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier("Library.Row.\(summary.displayName)")
    }
}
