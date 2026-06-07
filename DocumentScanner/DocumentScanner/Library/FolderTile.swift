import SwiftUI

/// Grid tile for a folder: a folder glyph over the folder name. The hidden
/// second text line keeps folder tiles the same height as document tiles.
struct FolderTile: View {
    let url: URL

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 6).fill(Color(.systemGray6))
                Image(systemName: "folder.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.tint)
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(0.78, contentMode: .fit)

            Text(url.lastPathComponent)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
            Text(" ")
                .font(.caption)
                .hidden()
        }
        .accessibilityIdentifier("Library.FolderTile.\(url.lastPathComponent)")
    }
}
