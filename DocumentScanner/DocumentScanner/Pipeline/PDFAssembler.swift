import CoreGraphics
import ImageIO
import PDFKit
import UIKit

enum PDFAssemblerError: Error {
    case pageCreationFailed
    case documentLoadFailed
}

struct PDFAssembler {

    func assemble(pages: [ScannedPage], createdAt: Date) throws -> PDFDocument {
        // Render each scanned page into a PDF page via UIGraphicsPDFRenderer so that
        // any OCR text is part of the page content stream — that's what PDFKit's
        // `PDFDocument.string` extracts, and what other PDF readers index for search.
        // Drawing a transparent-coloured glyph on top of the image keeps the visual
        // page looking like the scan while making the text selectable/searchable.
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data) else {
            throw PDFAssemblerError.pageCreationFailed
        }

        // Use US Letter as a sane default; each page's actual bounds come from its image.
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
            try renderPage(page, into: context)
        }

        context.closePDF()

        guard let document = PDFDocument(data: data as Data) else {
            throw PDFAssemblerError.documentLoadFailed
        }

        return document
    }

    private func renderPage(_ page: ScannedPage, into context: CGContext) throws {
        let cgImage = try compressedCGImage(from: page.image)

        // Page size in points matches the (possibly downsampled) image's pixel size at
        // 1pt-per-pixel; preserves aspect ratio without further resampling.
        let size = CGSize(width: CGFloat(cgImage.width), height: CGFloat(cgImage.height))
        var pageRect = CGRect(origin: .zero, size: size)

        context.beginPage(mediaBox: &pageRect)
        context.draw(cgImage, in: pageRect)

        if !page.observations.isEmpty {
            drawInvisibleText(page.observations, in: pageRect, into: context)
        }
        context.endPage()
    }

    /// Returns a CGImage whose pixel data matches what the UIImage displays —
    /// i.e. with the imageOrientation baked in — and whose pixel dimensions
    /// equal the UIImage's point size. Forcing scale=1 here is what keeps the
    /// resulting PDF page sized in document points rather than screen pixels;
    /// `renderPage` derives the page mediaBox from these dimensions.
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
        if let jpeg = PageImageCompressor.compressedJPEGData(from: image, maxLongEdge: 2400, quality: 0.65),
           let source = CGImageSourceCreateWithData(jpeg as CFData, nil),
           let cg = CGImageSourceCreateImageAtIndex(source, 0, nil) {
            return cg
        }
        guard let normalized = normalizedCGImage(from: image) else {
            throw PDFAssemblerError.pageCreationFailed
        }
        return normalized
    }

    private func drawInvisibleText(_ observations: [OCRObservation], in pageRect: CGRect, into context: CGContext) {
        context.saveGState()
        context.setTextDrawingMode(.invisible)

        for observation in observations {
            // Vision returns normalized coords (0…1, origin bottom-left, y-up).
            // CGContext PDF coords are also origin bottom-left, y-up — no flip needed.
            let bbox = observation.boundingBox
            let rect = CGRect(
                x: bbox.origin.x * pageRect.width,
                y: bbox.origin.y * pageRect.height,
                width: bbox.width * pageRect.width,
                height: bbox.height * pageRect.height
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
