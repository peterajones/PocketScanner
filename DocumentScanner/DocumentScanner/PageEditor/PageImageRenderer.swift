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
        return renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: bounds.size))
            ctx.cgContext.saveGState()
            page.draw(with: .mediaBox, to: ctx.cgContext)
            ctx.cgContext.restoreGState()
        }
    }
}
