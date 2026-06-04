import UIKit
import PDFKit

/// Rasterizes a PDFPage to a UIImage at the page's native point dimensions
/// (1pt = 1px, scale 1) — same convention PDFAssembler used to construct
/// the page. Used by PageEditorView to feed the page into segmentation and
/// perspective correction.
struct PageImageRenderer {

    func image(from page: PDFPage) -> UIImage? {
        let bounds = page.bounds(for: .mediaBox)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: bounds.size, format: format)

        // Temporarily hide all annotations during rasterization. The editor
        // wants the original page content, not the overlays drawn on top of it
        // (search highlights, and now persistent user marks — highlights /
        // strikethroughs). Without this they'd be baked into the new page image.
        // NOTE: the page editor replaces the page wholesale (see
        // DocumentMutations.replacePage), so user marks on an edited page are
        // NOT carried onto the re-assembled page — a known limitation, since a
        // cropped / perspective-corrected page has different geometry anyway.
        let savedDisplay = page.annotations.map { ($0, $0.shouldDisplay) }
        for annotation in page.annotations { annotation.shouldDisplay = false }
        defer {
            for (annotation, original) in savedDisplay {
                annotation.shouldDisplay = original
            }
        }

        return renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: bounds.size))
            ctx.cgContext.saveGState()
            // PDF coordinate space is origin bottom-left, y-up; UIKit's image
            // context is origin top-left, y-down. Flip Y before page.draw so
            // the rendered image is right-side up.
            ctx.cgContext.translateBy(x: 0, y: bounds.height)
            ctx.cgContext.scaleBy(x: 1, y: -1)
            page.draw(with: .mediaBox, to: ctx.cgContext)
            ctx.cgContext.restoreGState()
        }
    }
}
