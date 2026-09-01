import CoreGraphics
import ImageIO
import PDFKit
import UIKit

enum PDFAssemblerError: Error {
    case pageCreationFailed
    case documentLoadFailed
}

struct PDFAssembler {

    /// - Parameter pageSize: maps a page image's pixel size to the physical page size in
    ///   points. Scans pass `PaperSize.…​.resolver`; the page editor passes the size of
    ///   the page it is replacing, so an edit can never give one page in a document a
    ///   different size from its siblings.
    func assemble(pages: [ScannedPage],
                  createdAt: Date,
                  pageSize: (CGSize) -> CGSize = PaperSize.auto.resolver) throws -> PDFDocument {
        // Render each scanned page into a PDF page via UIGraphicsPDFRenderer so that
        // any OCR text is part of the page content stream — that's what PDFKit's
        // `PDFDocument.string` extracts, and what other PDF readers index for search.
        // Drawing a transparent-coloured glyph on top of the image keeps the visual
        // page looking like the scan while making the text selectable/searchable.
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data) else {
            throw PDFAssemblerError.pageCreationFailed
        }

        // Placeholder box for the context; each page sets its own via beginPage(mediaBox:).
        var defaultBox = CGRect(x: 0, y: 0, width: 612, height: 792)

        // Embed metadata directly in the PDF byte stream via auxiliaryInfo so it
        // survives a write of the underlying bytes — mutating `documentAttributes`
        // on the parsed `PDFDocument` would only affect the in-memory object.
        //
        // CoreGraphics on iOS does not expose `kCGPDFContextCreationDate` or
        // `kCGPDFContextProducer` as Swift constants, but the dictionary string
        // keys CG actually looks for (verified at runtime) are "CGPDFContextDate"
        // for the creation date and "CGPDFContextProducer" for the producer.
        let auxiliaryInfo: CFDictionary = [
            "CGPDFContextDate": createdAt,
            "CGPDFContextProducer": "DocumentScanner",
        ] as CFDictionary

        guard let context = CGContext(consumer: consumer, mediaBox: &defaultBox, auxiliaryInfo) else {
            throw PDFAssemblerError.pageCreationFailed
        }

        for page in pages {
            try renderPage(page, into: context, pageSize: pageSize)
        }

        context.closePDF()

        guard let document = PDFDocument(data: data as Data) else {
            throw PDFAssemblerError.documentLoadFailed
        }

        return document
    }

    /// Fit `size` inside `rect` without distortion, centred. Margins appear on one axis
    /// when the proportions differ — which is what asking for a fixed paper size means.
    static func aspectFitRect(_ size: CGSize, in rect: CGRect) -> CGRect {
        guard size.width > 0, size.height > 0 else { return rect }
        let scale = min(rect.width / size.width, rect.height / size.height)
        let fitted = CGSize(width: size.width * scale, height: size.height * scale)
        return CGRect(x: rect.midX - fitted.width / 2,
                      y: rect.midY - fitted.height / 2,
                      width: fitted.width,
                      height: fitted.height)
    }

    private func renderPage(_ page: ScannedPage,
                            into context: CGContext,
                            pageSize: (CGSize) -> CGSize) throws {
        let cgImage = try compressedCGImage(from: page.image)

        // Page size and image resolution are INDEPENDENT. The image's pixel count only
        // determines effective DPI; the page's physical size comes from the caller's
        // resolver. Before this, pixels were used as points directly, which produced
        // pages around 29 × 39 inches instead of 8.5 × 11.
        let imageSize = CGSize(width: CGFloat(cgImage.width), height: CGFloat(cgImage.height))
        var pageRect = CGRect(origin: .zero, size: pageSize(imageSize))

        context.beginPage(mediaBox: &pageRect)

        // Paint the page white first: with a fixed paper size the fitted image may not
        // cover it, and unpainted PDF space is transparent, not white.
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(pageRect)

        let drawRect = Self.aspectFitRect(imageSize, in: pageRect)
        context.draw(cgImage, in: drawRect)

        if !page.observations.isEmpty {
            // Text must follow the IMAGE, not the page — otherwise the invisible OCR
            // layer drifts off the glyphs it belongs to whenever there are margins.
            drawInvisibleText(page.observations, in: drawRect, into: context)
        }
        context.endPage()
    }

    /// Returns a CGImage whose pixel data matches what the UIImage displays —
    /// i.e. with the imageOrientation baked in — and whose pixel dimensions
    /// equal the UIImage's point size. Forcing scale=1 keeps the pixel dimensions
    /// predictable; the PAGE size no longer comes from them — see `renderPage`.
    private func normalizedCGImage(from image: UIImage) -> CGImage? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { _ in
            image.draw(at: .zero)
        }.cgImage
    }

    /// Downsampled + JPEG-encoded page image, built from the JPEG bytes via ImageIO so
    /// the CoreGraphics PDF context embeds the compressed (DCTDecode) stream. Falls back
    /// to the uncompressed normalized image if compression fails (a large page beats a
    /// failed save). Long-edge cap and quality are tuned for document legibility.
    private func compressedCGImage(from image: UIImage) throws -> CGImage {
        if let jpeg = PageImageCompressor.compressedJPEGData(from: image, maxLongEdge: PageImageCompressor.pageLongEdgeCap, quality: 0.65),
           let source = CGImageSourceCreateWithData(jpeg as CFData, nil),
           let cg = CGImageSourceCreateImageAtIndex(source, 0, nil) {
            return cg
        }
        guard let normalized = normalizedCGImage(from: image) else {
            throw PDFAssemblerError.pageCreationFailed
        }
        return normalized
    }

    /// - Parameter imageRect: where the page image was actually drawn, which is NOT the
    ///   page rect once a fixed paper size introduces margins. Vision's coordinates are
    ///   normalized to the image, so they must be mapped onto the image's rect — including
    ///   its origin, or the whole text layer shifts by the margin.
    private func drawInvisibleText(_ observations: [OCRObservation], in imageRect: CGRect, into context: CGContext) {
        context.saveGState()
        context.setTextDrawingMode(.invisible)

        for observation in observations {
            // Vision returns normalized coords (0…1, origin bottom-left, y-up).
            // CGContext PDF coords are also origin bottom-left, y-up — no flip needed.
            let bbox = observation.boundingBox
            let rect = CGRect(
                x: imageRect.origin.x + bbox.origin.x * imageRect.width,
                y: imageRect.origin.y + bbox.origin.y * imageRect.height,
                width: bbox.width * imageRect.width,
                height: bbox.height * imageRect.height
            )
            guard rect.height > 0, rect.width > 0 else { continue }

            // Size the font so glyphs roughly match the observed line height;
            // scaleX maps the line's natural width to the OCR rect's width.
            let font = UIFont.systemFont(ofSize: rect.height)
            let attributed = NSAttributedString(
                string: observation.string,
                attributes: [
                    .font: font,
                    .foregroundColor: UIColor.clear,
                ]
            )
            let ctLine = CTLineCreateWithAttributedString(attributed)

            let naturalWidth = CGFloat(CTLineGetTypographicBounds(ctLine, nil, nil, nil))
            let scaleX: CGFloat = naturalWidth > 0 ? rect.width / naturalWidth : 1

            // IMPORTANT: use CTM (translate + scale), NOT context.textMatrix.
            // A non-identity textMatrix causes PDFKit findString to return zero
            // matches — glyphs drawn under a non-identity text matrix are not
            // indexed. The CTM achieves the same horizontal stretch and keeps
            // glyphs indexable. Save/restore so transforms don't accumulate.
            context.saveGState()
            context.translateBy(x: rect.origin.x, y: rect.origin.y)
            context.scaleBy(x: scaleX, y: 1)
            context.textPosition = .zero
            CTLineDraw(ctLine, context)
            context.restoreGState()
        }

        context.restoreGState()
    }
}
