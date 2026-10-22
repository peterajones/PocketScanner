import Foundation
import PDFKit
import UIKit

enum PDFImporterError: Error, Equatable {
    case unreadablePDF
}

/// Imports an existing PDF into the library by reusing `DocumentStorage`. Used by
/// both entry points (the document handler and the in-app picker). The source file
/// is never moved or deleted — we copy it in.
///
/// Pages with no text layer (a camera scan saved as PDF, a lab report a clinic sends
/// as an image) are OCR'd on import so they are searchable like a scan made in the
/// app. Pages that already carry text are copied untouched.
enum PDFImporter {
    /// - Parameters:
    ///   - sourceURL: a possibly security-scoped URL from Files / another app.
    ///   - storage: destination storage (root or the current folder).
    ///   - ocr: recognizes text on pages that have none.
    ///   - onProgress: called before each text-less page is recognized, with its
    ///     1-based position among those pages and their count. Not called when no
    ///     page needs OCR.
    /// - Returns: the new document's URL.
    /// - Throws: `PDFImporterError.unreadablePDF` if the file isn't a readable PDF,
    ///   or a `DocumentStorage` error on write failure. OCR failures never throw: the
    ///   page is imported without a text layer.
    @concurrent
    static func importPDF(from sourceURL: URL,
                          using storage: DocumentStorage,
                          ocr: OCRProviding = OCREngine(),
                          onProgress: @Sendable (_ current: Int, _ total: Int) async -> Void = { _, _ in }) async throws -> URL {
        let scoped = sourceURL.startAccessingSecurityScopedResource()
        defer { if scoped { sourceURL.stopAccessingSecurityScopedResource() } }

        guard let pdf = PDFDocument(url: sourceURL) else {
            throw PDFImporterError.unreadablePDF
        }
        await addTextLayers(to: pdf, ocr: ocr, onProgress: onProgress)
        let name = sourceURL.deletingPathExtension().lastPathComponent
        return try storage.write(pdf, preferredName: name)
    }

    private static func addTextLayers(to pdf: PDFDocument,
                                      ocr: OCRProviding,
                                      onProgress: @Sendable (Int, Int) async -> Void) async {
        let indices = (0..<pdf.pageCount).filter { index in
            guard let page = pdf.page(at: index) else { return false }
            return (page.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        for (position, index) in indices.enumerated() {
            await onProgress(position + 1, indices.count)
            guard let page = pdf.page(at: index),
                  let image = renderDisplayed(page) else { continue }
            let observations = (try? await ocr.recognizeText(in: image)) ?? []
            guard !observations.isEmpty,
                  let searchable = searchablePage(from: page, observations: observations) else { continue }
            pdf.removePage(at: index)
            pdf.insert(searchable, at: index)
        }
    }

    /// The page's size as the viewer shows it: its crop box, turned by its rotation.
    private static func displayedSize(of page: PDFPage) -> CGSize {
        let box = page.bounds(for: .cropBox).size
        return page.rotation % 180 == 0 ? box : CGSize(width: box.height, height: box.width)
    }

    /// Draws the page upright, as displayed, into a PDF-style (y-up) space whose
    /// origin is the bottom-left corner of `displayedSize(of:)`.
    ///
    /// `draw(with:to:)` already applies the page's rotation (its output matches
    /// `thumbnail(of:for:)`). Calling `transform(_:for:)` first rotates twice and
    /// pushes a rotated page mostly off the canvas.
    private static func drawDisplayed(_ page: PDFPage, into context: CGContext) {
        page.draw(with: .cropBox, to: context)
    }

    /// Rasterizes the page as displayed, so text on a rotated page reaches Vision
    /// upright. Same resolution cap as the page editor.
    private static func renderDisplayed(_ page: PDFPage) -> UIImage? {
        let size = displayedSize(of: page)
        guard size.width > 0, size.height > 0 else { return nil }
        let scale = max(1, PageImageCompressor.pageLongEdgeCap / max(size.width, size.height))
        let pixelSize = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: pixelSize, format: format).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: pixelSize))
            // UIKit is y-down; flip so the PDF-space drawing lands right side up.
            ctx.cgContext.translateBy(x: 0, y: pixelSize.height)
            ctx.cgContext.scaleBy(x: scale, y: -scale)
            drawDisplayed(page, into: ctx.cgContext)
        }
    }

    /// A one-page PDF that draws the original page unchanged (its own content, not a
    /// re-compressed bitmap) with the invisible OCR text over it. The new page is
    /// upright with no rotation, so the text layer and the content share one space.
    private static func searchablePage(from page: PDFPage, observations: [OCRObservation]) -> PDFPage? {
        let data = NSMutableData()
        var mediaBox = CGRect(origin: .zero, size: displayedSize(of: page))
        guard let consumer = CGDataConsumer(data: data),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return nil }
        context.beginPage(mediaBox: &mediaBox)
        context.saveGState()
        drawDisplayed(page, into: context)
        context.restoreGState()
        PDFAssembler.drawInvisibleText(observations, in: mediaBox, into: context)
        context.endPage()
        context.closePDF()
        return PDFDocument(data: data as Data)?.page(at: 0)
    }
}
