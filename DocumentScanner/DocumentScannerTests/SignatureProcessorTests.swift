import XCTest
import UIKit
@testable import DocumentScanner

final class SignatureProcessorTests: XCTestCase {

    /// White page with a black bar across the middle — mimics ink on paper.
    private func inkOnPaper(size: CGSize = CGSize(width: 200, height: 200)) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            UIColor.black.setFill()
            ctx.fill(CGRect(x: 40, y: 90, width: 120, height: 20))
        }
    }

    private func alpha(of image: UIImage, atX x: Int, y: Int) -> CGFloat {
        let cg = image.cgImage!
        let w = cg.width, h = cg.height
        var px: [UInt8] = [0, 0, 0, 0]
        let cs = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(data: &px, width: 1, height: 1, bitsPerComponent: 8,
                            bytesPerRow: 4, space: cs,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(cg, in: CGRect(x: -x, y: -(h - 1 - y), width: w, height: h))
        return CGFloat(px[3]) / 255.0
    }

    func test_process_makesPaperTransparent_keepsInkOpaque() throws {
        let out = try XCTUnwrap(SignatureProcessor().process(inkOnPaper()))
        let cx = out.cgImage!.width / 2, cy = out.cgImage!.height / 2
        XCTAssertGreaterThan(alpha(of: out, atX: cx, y: cy), 0.8, "ink should be opaque")
        XCTAssertLessThan(alpha(of: out, atX: 0, y: 0), 0.2, "paper should be transparent")
    }

    func test_process_cropsToInkBounds() throws {
        let src = inkOnPaper(size: CGSize(width: 200, height: 200))
        let out = try XCTUnwrap(SignatureProcessor().process(src))
        // Ink bar is 120×20 inside 200×200; cropped output hugs it (+ padding),
        // so the height in particular must be tight — a loose bound would miss a
        // wrong-axis crop.
        XCTAssertLessThan(out.size.width, 160)
        XCTAssertLessThan(out.size.height, 40)
    }

    func test_process_blankPage_returnsNil() {
        let blank = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100)).image { ctx in
            UIColor.white.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
        }
        XCTAssertNil(SignatureProcessor().process(blank), "all-paper input has no ink → nil")
    }
}
