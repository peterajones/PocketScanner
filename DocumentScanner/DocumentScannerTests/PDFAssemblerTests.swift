import XCTest
import PDFKit
import UIKit
@testable import DocumentScanner

final class PDFAssemblerTests: XCTestCase {

    func test_assemble_singlePage_producesPDFWithOnePage() throws {
        let image = whitePageImage()
        let page = ScannedPage(image: image, observations: [])
        let pdf = try PDFAssembler().assemble(pages: [page], createdAt: Date())
        XCTAssertEqual(pdf.pageCount, 1)
    }

    func test_assemble_multiplePages_producesCorrectPageCount() throws {
        let image = whitePageImage()
        let pages = (0..<3).map { _ in ScannedPage(image: image, observations: []) }
        let pdf = try PDFAssembler().assemble(pages: pages, createdAt: Date())
        XCTAssertEqual(pdf.pageCount, 3)
    }

    func test_assemble_embedsRecognizedTextSoStringIsSearchable() throws {
        let image = whitePageImage()
        let page = ScannedPage(
            image: image,
            observations: [
                obs("The quick brown fox", y: 0.7),
                obs("jumps over the lazy dog", y: 0.5),
            ]
        )
        let pdf = try PDFAssembler().assemble(pages: [page], createdAt: Date())
        let text = pdf.string ?? ""
        XCTAssertTrue(text.contains("quick brown fox"), "got: \(text)")
        XCTAssertTrue(text.contains("lazy dog"), "got: \(text)")
    }

    func test_assemble_setsCreatedAtMetadata() throws {
        let image = whitePageImage()
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let pdf = try PDFAssembler().assemble(
            pages: [ScannedPage(image: image, observations: [])],
            createdAt: date
        )
        let attrs = pdf.documentAttributes ?? [:]
        XCTAssertEqual(attrs[PDFDocumentAttribute.creationDateAttribute] as? Date, date)
    }

    func test_assemble_outputIsRoundTrippable() throws {
        // PDFKit's dataRepresentation() re-serializes the PDF and stamps fresh
        // metadata (CreationDate, Producer) — we don't claim any specific
        // metadata key survives. The library's createdAt falls back to the
        // filesystem creationDate, so the in-PDF date isn't load-bearing.
        // This test just verifies the assembled PDF round-trips through
        // dataRepresentation() with content intact.
        let image = whitePageImage()
        let pdf = try PDFAssembler().assemble(
            pages: [
                ScannedPage(image: image, observations: [obs("alpha", y: 0.5)]),
                ScannedPage(image: image, observations: [obs("beta", y: 0.5)]),
            ],
            createdAt: Date()
        )
        let data = try XCTUnwrap(pdf.dataRepresentation())
        let reloaded = try XCTUnwrap(PDFDocument(data: data))
        XCTAssertEqual(reloaded.pageCount, 2)
        let text = reloaded.string ?? ""
        XCTAssertTrue(text.contains("alpha"))
        XCTAssertTrue(text.contains("beta"))
    }

    func test_assemble_respectsUIImageOrientation() throws {
        // Build a 100×200 raw image, then wrap it with .right orientation —
        // displays as 200×100. PDFAssembler must normalize so the page reflects
        // the displayed size, not the raw sensor-orientation pixels.
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 200))
        let raw = renderer.image { _ in
            UIColor.white.setFill()
            UIRectFill(CGRect(x: 0, y: 0, width: 100, height: 200))
        }
        let rotated = UIImage(cgImage: raw.cgImage!, scale: raw.scale, orientation: .right)

        let pdf = try PDFAssembler().assemble(
            pages: [ScannedPage(image: rotated, observations: [])],
            createdAt: Date()
        )
        let bounds = try XCTUnwrap(pdf.page(at: 0)).bounds(for: .mediaBox)
        // The page must come out LANDSCAPE (2:1), reflecting the displayed orientation
        // rather than the raw sensor pixels. Exact point values now depend on PaperSize,
        // so assert the proportions — which is what this test was ever about.
        XCTAssertGreaterThan(bounds.width, bounds.height)
        XCTAssertEqual(bounds.width / bounds.height, 2, accuracy: 0.02)
    }

    // MARK: - Compression tests

    func test_assemble_compressesLargePageWellBelowLosslessSize() throws {
        let page = ScannedPage(image: largeGradientImage(), observations: [])
        let pdf = try PDFAssembler().assemble(pages: [page], createdAt: Date())
        let data = try XCTUnwrap(pdf.dataRepresentation())
        XCTAssertLessThan(data.count, 800_000, "expected downsampled+JPEG page, got \(data.count) bytes")
    }

    func test_assemble_downsamplesLargePageToCap() throws {
        let page = ScannedPage(image: largeGradientImage(3000, 4000), observations: [])
        // Identity resolver: page points == image pixels, so page bounds measure the
        // IMAGE downsampling cap. Page sizing is a separate concern (see PaperSizeTests).
        let pdf = try PDFAssembler().assemble(pages: [page], createdAt: Date(), pageSize: { $0 })
        let bounds = try XCTUnwrap(pdf.page(at: 0)).bounds(for: .mediaBox)
        XCTAssertLessThanOrEqual(max(bounds.width, bounds.height), 2800 + 1)
    }

    func test_assemble_doesNotUpsampleSmallPage() throws {
        let small = UIGraphicsImageRenderer(size: CGSize(width: 600, height: 800)).image { ctx in
            UIColor.white.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 600, height: 800))
        }
        // Identity resolver, as above: this is about not upsampling the IMAGE.
        let pdf = try PDFAssembler().assemble(pages: [ScannedPage(image: small, observations: [])],
                                              createdAt: Date(), pageSize: { $0 })
        let bounds = try XCTUnwrap(pdf.page(at: 0)).bounds(for: .mediaBox)
        XCTAssertEqual(max(bounds.width, bounds.height), 800, accuracy: 2)
    }

    func test_assemble_preservesSearchableText_afterCompression() throws {
        let page = ScannedPage(image: largeGradientImage(), observations: [obs("INVOICE", y: 0.8)])
        let pdf = try PDFAssembler().assemble(pages: [page], createdAt: Date())
        XCTAssertTrue((pdf.string ?? "").contains("INVOICE"))
    }

    // MARK: - Helpers

    private func largeGradientImage(_ w: CGFloat = 3000, _ h: CGFloat = 4000) -> UIImage {
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1; fmt.opaque = true
        return UIGraphicsImageRenderer(size: CGSize(width: w, height: h), format: fmt).image { ctx in
            let colors = [UIColor.systemRed.cgColor, UIColor.systemBlue.cgColor] as CFArray
            let space = CGColorSpaceCreateDeviceRGB()
            let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1])!
            ctx.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: w, y: h), options: [])
        }
    }

    private func whitePageImage() -> UIImage {
        UIGraphicsBeginImageContextWithOptions(CGSize(width: 612, height: 792), true, 1)
        UIColor.white.setFill()
        UIRectFill(CGRect(x: 0, y: 0, width: 612, height: 792))
        let img = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return img
    }

    /// Build an OCRObservation at a given normalized y (origin bottom-left),
    /// occupying most of the page width with a default line height.
    private func obs(_ string: String, y: CGFloat) -> OCRObservation {
        OCRObservation(string: string,
                       boundingBox: CGRect(x: 0.05, y: y, width: 0.9, height: 0.04))
    }
    // MARK: - Page size (v3.5)

    private func letterishPage() -> ScannedPage {
        let img = UIGraphicsImageRenderer(size: CGSize(width: 850, height: 1100)).image { ctx in
            UIColor.white.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 850, height: 1100))
        }
        return ScannedPage(image: img, observations: [])
    }

    func test_defaultPageSizeIsSaneNotThirtyInches() throws {
        let pdf = try PDFAssembler().assemble(pages: [letterishPage()], createdAt: Date())
        let bounds = try XCTUnwrap(pdf.page(at: 0)).bounds(for: .mediaBox)
        // The bug this replaced produced pages ~2800pt (≈39in) tall.
        XCTAssertLessThanOrEqual(bounds.height, 800, "page should be about 11in, not 39in")
        XCTAssertEqual(bounds.height, 792, accuracy: 1)
    }

    func test_usLetterResolverProducesExactlyLetter() throws {
        let pdf = try PDFAssembler().assemble(pages: [letterishPage()], createdAt: Date(),
                                              pageSize: PaperSize.usLetter.resolver)
        let bounds = try XCTUnwrap(pdf.page(at: 0)).bounds(for: .mediaBox)
        XCTAssertEqual(bounds.width, 612, accuracy: 1)
        XCTAssertEqual(bounds.height, 792, accuracy: 1)
    }

    func test_a4ResolverProducesExactlyA4() throws {
        let pdf = try PDFAssembler().assemble(pages: [letterishPage()], createdAt: Date(),
                                              pageSize: PaperSize.a4.resolver)
        let bounds = try XCTUnwrap(pdf.page(at: 0)).bounds(for: .mediaBox)
        XCTAssertEqual(bounds.width, 595, accuracy: 1)
        XCTAssertEqual(bounds.height, 842, accuracy: 1)
    }

    /// A receipt forced onto Letter must be letterboxed, never stretched.
    func test_fixedSizeLetterboxesRatherThanDistorts() {
        let receipt = CGSize(width: 800, height: 2400)          // 1:3
        let page = CGRect(x: 0, y: 0, width: 612, height: 792)  // Letter
        let drawn = PDFAssembler.aspectFitRect(receipt, in: page)

        XCTAssertEqual(drawn.width / drawn.height,
                       receipt.width / receipt.height,
                       accuracy: 0.001,
                       "aspect distorted — a scanner must not stretch the document")
        XCTAssertLessThanOrEqual(drawn.width, page.width + 0.5)
        XCTAssertLessThanOrEqual(drawn.height, page.height + 0.5)
        XCTAssertEqual(drawn.midX, page.midX, accuracy: 0.5, "not centred")
        XCTAssertEqual(drawn.midY, page.midY, accuracy: 0.5, "not centred")
    }

    /// Text is searchable even when a fixed paper size introduces margins — i.e. the
    /// invisible OCR layer follows the image rect, not the page rect.
    func test_searchableTextSurvivesLetterboxing() throws {
        let receipt = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 1200)).image { ctx in
            UIColor.white.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 400, height: 1200))
        }
        let pdf = try PDFAssembler().assemble(
            pages: [ScannedPage(image: receipt, observations: [obs("NORTHGATE", y: 0.8)])],
            createdAt: Date(),
            pageSize: PaperSize.usLetter.resolver)
        XCTAssertTrue((pdf.string ?? "").contains("NORTHGATE"))
    }

    /// The page editor replaces a single page inside an existing document; it must be
    /// able to reproduce that page's exact size or a document ends up with mixed sizes.
    func test_explicitSizeResolverReproducesAnExistingPageSize() throws {
        let existing = CGSize(width: 612, height: 792)
        let pdf = try PDFAssembler().assemble(pages: [letterishPage()], createdAt: Date(),
                                              pageSize: { _ in existing })
        let bounds = try XCTUnwrap(pdf.page(at: 0)).bounds(for: .mediaBox)
        XCTAssertEqual(bounds.size.width, existing.width, accuracy: 1)
        XCTAssertEqual(bounds.size.height, existing.height, accuracy: 1)
    }

}
