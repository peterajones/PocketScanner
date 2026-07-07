import XCTest
import UIKit
@testable import DocumentScanner

final class PageImageCompressorTests: XCTestCase {

    private func solidImage(_ w: CGFloat, _ h: CGFloat) -> UIImage {
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1; fmt.opaque = true
        return UIGraphicsImageRenderer(size: CGSize(width: w, height: h), format: fmt).image { ctx in
            UIColor.white.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
            UIColor.black.setFill(); ctx.fill(CGRect(x: 10, y: 10, width: w - 20, height: 40))
        }
    }

    func test_downsampledSize_scalesDownWhenAboveCap() {
        let s = PageImageCompressor.downsampledSize(for: CGSize(width: 3000, height: 4000), maxLongEdge: 2000)
        XCTAssertEqual(s.width, 1500, accuracy: 1)
        XCTAssertEqual(s.height, 2000, accuracy: 1)
    }

    func test_downsampledSize_leavesSmallImageUntouched() {
        let s = PageImageCompressor.downsampledSize(for: CGSize(width: 1000, height: 800), maxLongEdge: 2000)
        XCTAssertEqual(s, CGSize(width: 1000, height: 800))
    }

    func test_downsampledSize_preservesAspectRatio() {
        let src = CGSize(width: 4000, height: 3000)
        let s = PageImageCompressor.downsampledSize(for: src, maxLongEdge: 2000)
        XCTAssertEqual(s.width / s.height, src.width / src.height, accuracy: 0.01)
        XCTAssertLessThanOrEqual(max(s.width, s.height), 2001, "long edge capped")
    }

    func test_compressedJPEGData_isDecodableAndCappedLongEdge() throws {
        let data = try XCTUnwrap(
            PageImageCompressor.compressedJPEGData(from: solidImage(3000, 4000), maxLongEdge: 2000, quality: 0.6)
        )
        let decoded = try XCTUnwrap(UIImage(data: data))
        XCTAssertLessThanOrEqual(max(decoded.size.width, decoded.size.height) * decoded.scale, 2000 + 1)
    }

    func test_compressedJPEGData_doesNotUpsampleSmallImage() throws {
        let data = try XCTUnwrap(
            PageImageCompressor.compressedJPEGData(from: solidImage(800, 600), maxLongEdge: 2000, quality: 0.6)
        )
        let decoded = try XCTUnwrap(UIImage(data: data))
        XCTAssertEqual(decoded.size.width * decoded.scale, 800, accuracy: 1)
        XCTAssertEqual(decoded.size.height * decoded.scale, 600, accuracy: 1)
    }
}
