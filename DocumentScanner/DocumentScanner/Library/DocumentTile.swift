import SwiftUI

/// Grid tile for a document: thumbnail over name + "date · pages" subtitle.
/// Pure presentation — the parent wraps it in a NavigationLink / contextMenu.
struct DocumentTile: View {
    let summary: DocumentSummary
    var folderName: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 6).fill(Color(.systemGray6))
                if summary.isCorrupt {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.title2)
                } else {
                    DocumentThumbnail(url: summary.url, size: CGSize(width: 220, height: 280))
                        .padding(4)
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(0.78, contentMode: .fit)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(.systemGray4)))

            Text(summary.displayName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
            Text(summary.formattedSubtitle)
                .font(.caption)
                .foregroundStyle(summary.isCorrupt ? .orange : .secondary)
                .lineLimit(1)
            if let folderName {
                Text("in \(folderName)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .accessibilityIdentifier("Library.Tile.\(summary.displayName)")
    }
}
