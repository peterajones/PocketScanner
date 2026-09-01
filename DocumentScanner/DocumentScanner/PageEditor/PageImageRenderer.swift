import UIKit
import PDFKit

/// Rasterizes a PDFPage to a UIImage for the page editor — segmentation, perspective
/// correction, rotation and filtering all work on this bitmap, and the result is what
/// gets written back as the new page.
///
/// It rasterises UP to `PageImageCompressor.pageLongEdgeCap` rather than at the page's
/// point size. That used to be the same thing: pages were sized from their image's pixel
/// count, so a page was ~2800pt on the long edge and 1pt = 1px gave full resolution.
/// Once PaperSize made a page 792pt, rendering at point size silently downsampled a
/// 2800px scan to 792px and drew it back at 72 DPI — cropping a page visibly blurred it.
///
/// The image's point size still equals its pixel size (scale 1), which is the convention
/// `PageImageCompressor` and `PDFAssembler` both rely on. Only the PAGE's size is
/// independent now; images stay 1pt = 1px throughout.
struct PageImageRenderer {

    func image(from page: PDFPage) -> UIImage? {
        let bounds = page.bounds(for: .mediaBox)
        guard bounds.width > 0, bounds.height > 0 else { return nil }

        // Never below 1: a page already larger than the cap is rendered as-is and the
        // compressor brings it back down.
        let scale = max(1, PageImageCompressor.pageLongEdgeCap / max(bounds.width, bounds.height))
        let pixelSize = CGSize(width: (bounds.width * scale).rounded(),
                               height: (bounds.height * scale).rounded())

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: pixelSize, format: format)

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
            ctx.fill(CGRect(origin: .zero, size: pixelSize))
            ctx.cgContext.saveGState()
            // PDF coordinate space is origin bottom-left, y-up; UIKit's image context is
            // origin top-left, y-down. Flip Y before page.draw so the rendered image is
            // right-side up, and scale by the same factor on both axes so the page's
            // point space maps onto the larger pixel canvas without distortion.
            ctx.cgContext.translateBy(x: 0, y: pixelSize.height)
            ctx.cgContext.scaleBy(x: scale, y: -scale)
            page.draw(with: .mediaBox, to: ctx.cgContext)
            ctx.cgContext.restoreGState()
        }
    }
}
