import XCTest
import PDFKit
@testable import DocumentScanner

final class PageImageRendererTests: XCTestCase {

    private func page(sized size: CGSize, imagePixels: CGSize) throws -> PDFPage {
        let img = UIGraphicsImageRenderer(size: imagePixels).image { ctx in
            UIColor.white.setFill()
            UIRectFill(CGRect(origin: .zero, size: imagePixels))
        }
        let pdf = try PDFAssembler().assemble(
            pages: [ScannedPage(image: img, observations: [])],
            createdAt: Date(),
            pageSize: { _ in size }
        )
        return try XCTUnwrap(pdf.page(at: 0))
    }

    /// The regression that motivated this. The renderer used to rasterise at the page's
    /// POINT size, which was fine while pages were sized from their image's pixel count
    /// (~2800pt). Once PaperSize made a Letter page 792pt, editing a page downsampled a
    /// 2800px scan to 792px and drew it back at 72 DPI — cropping visibly blurred it.
    func test_render_keepsEditingResolution_onASmallPointSizePage() throws {
        let letter = try page(sized: CGSize(width: 612, height: 792),
                              imagePixels: CGSize(width: 2100, height: 2800))
        let rendered = try XCTUnwrap(PageImageRenderer().image(from: letter))

        XCTAssertGreaterThan(max(rendered.size.width, rendered.size.height), 2000,
                             "rasterised at page point size — a crop would blur the page")
        XCTAssertEqual(max(rendered.size.width, rendered.size.height),
                       PageImageCompressor.pageLongEdgeCap, accuracy: 2)
    }

    func test_render_preservesPageAspectRatio() throws {
        let letter = try page(sized: CGSize(width: 612, height: 792),
                              imagePixels: CGSize(width: 2100, height: 2800))
        let rendered = try XCTUnwrap(PageImageRenderer().image(from: letter))
        XCTAssertEqual(rendered.size.width / rendered.size.height,
                       612.0 / 792.0, accuracy: 0.005)
    }

    /// A page already at or above the cap must not be blown up further — that would
    /// cost bytes for no detail.
    func test_render_doesNotUpsampleAnAlreadyLargePage() throws {
        let big = try page(sized: CGSize(width: 3000, height: 4000),
                           imagePixels: CGSize(width: 3000, height: 4000))
        let rendered = try XCTUnwrap(PageImageRenderer().image(from: big))
        XCTAssertEqual(rendered.size.height, 4000, accuracy: 2)
    }

    /// The renderer's output feeds straight back into PDFAssembler, whose compressor
    /// reads `image.size`. So point size must equal pixel size, or the resolution is
    /// discarded on the way back in.
    func test_render_producesScaleOnePointsEqualPixels() throws {
        let letter = try page(sized: CGSize(width: 612, height: 792),
                              imagePixels: CGSize(width: 2100, height: 2800))
        let rendered = try XCTUnwrap(PageImageRenderer().image(from: letter))
        XCTAssertEqual(rendered.scale, 1, accuracy: 0.001)
        let cg = try XCTUnwrap(rendered.cgImage)
        XCTAssertEqual(CGFloat(cg.width), rendered.size.width, accuracy: 2)
        XCTAssertEqual(CGFloat(cg.height), rendered.size.height, accuracy: 2)
    }

    /// End-to-end: render a page, hand it straight back to the assembler as the editor
    /// does, and the round-trip must keep both the page's size AND its resolution.
    func test_editorRoundTrip_keepsPageSizeAndResolution() throws {
        let original = try page(sized: CGSize(width: 612, height: 792),
                                imagePixels: CGSize(width: 2100, height: 2800))
        let rendered = try XCTUnwrap(PageImageRenderer().image(from: original))
        let existingSize = original.bounds(for: .mediaBox).size

        let rebuilt = try PDFAssembler().assemble(
            pages: [ScannedPage(image: rendered, observations: [])],
            createdAt: Date(),
            pageSize: { _ in existingSize }
        )
        let newPage = try XCTUnwrap(rebuilt.page(at: 0))
        XCTAssertEqual(newPage.bounds(for: .mediaBox).size.width, 612, accuracy: 1)
        XCTAssertEqual(newPage.bounds(for: .mediaBox).size.height, 792, accuracy: 1)

        let reRendered = try XCTUnwrap(PageImageRenderer().image(from: newPage))
        XCTAssertGreaterThan(max(reRendered.size.width, reRendered.size.height), 2000,
                             "resolution lost on a single editor round-trip")
    }
}
