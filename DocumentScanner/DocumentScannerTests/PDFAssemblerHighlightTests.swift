import XCTest
import PDFKit
import UIKit
@testable import DocumentScanner

final class PDFAssemblerHighlightTests: XCTestCase {

    /// Assembles a 1-page PDF with a single OCR observation, runs findString
    /// for that observation's string, and asserts the resulting PDFSelection's
    /// bounds match the OCR rect within ~5pt horizontal tolerance.
    ///
    /// The previous implementation (no text-matrix scaling) drifts much further
    /// than 5pt because system-font glyph widths don't match the original.
    func test_findStringHighlight_matchesOCRRectWidth() throws {
        // 612x792pt page (US Letter).
        let pageSize = CGSize(width: 612, height: 792)

        // OCR observation: a 30pt-tall band, 400pt wide, positioned 100pt in.
        let ocrRect = CGRect(x: 100, y: 200, width: 400, height: 30)
        let normalized = CGRect(
            x: ocrRect.origin.x / pageSize.width,
            y: ocrRect.origin.y / pageSize.height,
            width: ocrRect.width / pageSize.width,
            height: ocrRect.height / pageSize.height
        )
        let observation = OCRObservation(
            string: "Quick brown fox jumps over the lazy dog",
            boundingBox: normalized
        )

        let image = blankImage(size: pageSize)
        let scanned = ScannedPage(image: image, observations: [observation])
        let pdf = try PDFAssembler().assemble(pages: [scanned], createdAt: Date())

        let selections = pdf.findString(observation.string, withOptions: .caseInsensitive)
        let selection = try XCTUnwrap(selections.first,
                                      "Expected findString to return a match for the observation")

        let page = try XCTUnwrap(pdf.page(at: 0))
        let bounds = selection.bounds(for: page)

        // The OCR rect is in PDF page coordinates (origin bottom-left, y-up).
        // After text-matrix scaling, the selection's x-extent should align
        // with the OCR rect within ~5pt slack.
        XCTAssertEqual(bounds.minX, ocrRect.minX, accuracy: 5,
                       "Selection minX should align with OCR rect minX")
        XCTAssertEqual(bounds.width, ocrRect.width, accuracy: 5,
                       "Selection width should align with OCR rect width")
    }

    // MARK: - Helpers

    private func blankImage(size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }
}
