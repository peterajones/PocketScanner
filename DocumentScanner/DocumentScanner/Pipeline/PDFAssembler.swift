import CoreGraphics
import PDFKit
import UIKit

enum PDFAssemblerError: Error {
    case pageCreationFailed
    case documentLoadFailed
}

/// `PDFDocument` whose `dataRepresentation()` returns the exact bytes it was
/// constructed from, rather than re-serializing through PDFKit. PDFKit's
/// re-serialization stamps a fresh `CreationDate` and `Producer`, which would
/// silently drop the metadata we baked into the byte stream via
/// `CGContext`'s `auxiliaryInfo`.
private final class ByteFaithfulPDFDocument: PDFDocument {
    private let sourceData: Data

    init?(byteFaithfulData: Data) {
        self.sourceData = byteFaithfulData
        super.init(data: byteFaithfulData)
    }

    override func dataRepresentation() -> Data? {
        return sourceData
    }
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

        guard let document = ByteFaithfulPDFDocument(byteFaithfulData: data as Data) else {
            throw PDFAssemblerError.documentLoadFailed
        }

        return document
    }

    private func renderPage(_ page: ScannedPage, into context: CGContext) throws {
        // VisionKit returns UIImages with a non-`.up` orientation flag (the camera
        // sensor is landscape; portrait photos carry a "rotate 90°" hint). Pulling
        // `.cgImage` returns the raw sensor-orientation pixels, losing that flag —
        // which lands the page rotated in the PDF. Normalize first so the bytes
        // we draw match what the user saw in the scanner.
        guard let cgImage = normalizedCGImage(from: page.image) else {
            throw PDFAssemblerError.pageCreationFailed
        }

        // Page size in points matches the image's pixel size at 1pt-per-pixel; this
        // preserves aspect ratio without resampling.
        let size = CGSize(width: CGFloat(cgImage.width), height: CGFloat(cgImage.height))
        var pageRect = CGRect(origin: .zero, size: size)

        context.beginPage(mediaBox: &pageRect)

        // CGContext PDF origin is bottom-left, so flip before drawing the image so it
        // appears right-side up.
        context.saveGState()
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1, y: -1)
        context.draw(cgImage, in: pageRect)
        context.restoreGState()

        // Draw OCR-recognized text invisibly so `pdf.string` returns it and search
        // works. We use the PDF text-rendering mode "invisible" (3), which keeps the
        // glyphs in the content stream — and therefore in the text extraction — while
        // not painting any pixels.
        //
        // The current layout is coarse: all lines stacked at the top of the page in a
        // tiny font. A future plan will refine this to per-observation position-anchored
        // text using the bounding boxes from VNRecognizedTextObservation so highlights
        // line up with the visible scan.
        if !page.recognizedStrings.isEmpty {
            drawInvisibleText(page.recognizedStrings, in: pageRect, into: context)
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

    private func drawInvisibleText(_ lines: [String], in pageRect: CGRect, into context: CGContext) {
        let font = UIFont.systemFont(ofSize: 8)

        context.saveGState()
        context.setTextDrawingMode(.invisible)

        var y = pageRect.height - font.lineHeight
        for line in lines {
            let attributed = NSAttributedString(
                string: line,
                attributes: [
                    .font: font,
                    .foregroundColor: UIColor.clear,
                ]
            )
            let ctLine = CTLineCreateWithAttributedString(attributed)
            context.textPosition = CGPoint(x: 8, y: y)
            CTLineDraw(ctLine, context)
            y -= font.lineHeight
        }

        context.restoreGState()
    }
}
