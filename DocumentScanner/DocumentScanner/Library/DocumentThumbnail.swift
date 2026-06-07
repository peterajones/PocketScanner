import SwiftUI
import PDFKit

/// Renders the first page of a PDF as a thumbnail, async on a background queue.
/// Shared by the library list rows and the grid tiles; `size` is the render
/// resolution (callers frame it as needed).
struct DocumentThumbnail: View {
    let url: URL
    let size: CGSize

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFit()
            } else {
                Color.clear
            }
        }
        .task(id: url) {
            image = await Self.render(url: url, size: size)
        }
    }

    private static func render(url: URL, size: CGSize) async -> UIImage? {
        await Task.detached(priority: .userInitiated) {
            guard let pdf = PDFDocument(url: url), let page = pdf.page(at: 0) else { return nil }
            return page.thumbnail(of: size, for: .mediaBox)
        }.value
    }
}
