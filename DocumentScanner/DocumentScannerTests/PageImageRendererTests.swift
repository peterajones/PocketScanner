import XCTest
import PDFKit
@testable import DocumentScanner

final class PageImageRendererTests: XCTestCase {

    func test_render_producesImageAtPageSize() throws {
        // 100×100 source image → assembled into a one-page PDF.
        let source = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100)).image { _ in
            UIColor.white.setFill()
            UIRectFill(CGRect(x: 0, y: 0, width: 100, height: 100))
        }
        let pdf = try PDFAssembler().assemble(
            pages: [ScannedPage(image: source, observations: [])],
            createdAt: Date()
        )
        let page = try XCTUnwrap(pdf.page(at: 0))
        let rendered = try XCTUnwrap(PageImageRenderer().image(from: page))
        // Assert against the page's OWN bounds rather than the source image's pixels.
        // Those were the same number until PaperSize decoupled page size from image
        // resolution; the renderer's actual contract is "an image at the page's size".
        let pageSize = page.bounds(for: .mediaBox).size
        XCTAssertEqual(rendered.size.width, pageSize.width, accuracy: 1)
        XCTAssertEqual(rendered.size.height, pageSize.height, accuracy: 1)
    }
}
