import XCTest
import UIKit
@testable import DocumentScanner

final class DocumentSegmenterTests: XCTestCase {

    func test_segment_returnsQuadForDocumentLikeImage() async throws {
        // Page with a black rectangle on white — Vision should find its edges.
        let image = UIGraphicsImageRenderer(size: CGSize(width: 800, height: 1000)).image { _ in
            UIColor.white.setFill()
            UIRectFill(CGRect(x: 0, y: 0, width: 800, height: 1000))
            UIColor.black.setFill()
            UIRectFill(CGRect(x: 100, y: 150, width: 600, height: 700))
        }
        let segmenter = DocumentSegmenter()
        let quad = try await segmenter.detect(in: image)
        let quadUnwrapped = try XCTUnwrap(quad)
        // Should find something near our 600×700 inset; corners between (50, 100) and (750, 900).
        XCTAssertGreaterThan(quadUnwrapped.topRight.x, 400)
        XCTAssertGreaterThan(quadUnwrapped.bottomLeft.y, 500)
    }

    func test_segment_returnsNilForBlankImage() async throws {
        // Random noise — no rectangular document structure for Vision to find.
        let size = CGSize(width: 400, height: 400)
        let image = UIGraphicsImageRenderer(size: size).image { ctx in
            for x in stride(from: 0, to: Int(size.width), by: 4) {
                for y in stride(from: 0, to: Int(size.height), by: 4) {
                    let gray = CGFloat.random(in: 0...1)
                    UIColor(white: gray, alpha: 1).setFill()
                    ctx.fill(CGRect(x: x, y: y, width: 4, height: 4))
                }
            }
        }
        let quad = try await DocumentSegmenter().detect(in: image)
        XCTAssertNil(quad)
    }
}
