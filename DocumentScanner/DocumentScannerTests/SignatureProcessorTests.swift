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

    func test_process_dropsSeparatedArtifactLine() throws {
        // A signature mass near the top + a thin full-width line near the bottom,
        // separated by whitespace — mimics the camera band artifact from scanning
        // a screen. The crop should keep the signature band and drop the line.
        let src = UIGraphicsImageRenderer(size: CGSize(width: 200, height: 300)).image { ctx in
            UIColor.white.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 200, height: 300))
            UIColor.black.setFill()
            ctx.fill(CGRect(x: 40, y: 40, width: 120, height: 60))   // signature mass
            ctx.fill(CGRect(x: 10, y: 270, width: 180, height: 3))   // artifact line
        }
        let out = try XCTUnwrap(SignatureProcessor().process(src))
        // Without the line the crop hugs the ~60px band, not the ~230px span.
        XCTAssertLessThan(out.size.height, 120, "separated artifact line should be cropped out")
    }

    func test_process_honorsImageOrientation() throws {
        // A raw portrait buffer with a VERTICAL ink bar, tagged `.right` like a
        // portrait camera capture (UIImagePickerController). Displayed upright,
        // the bar is HORIZONTAL — so the crop must come out wide. If orientation
        // were ignored (processing the raw buffer), the crop would be tall.
        let raw = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 200)).image { ctx in
            UIColor.white.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 200))
            UIColor.black.setFill(); ctx.fill(CGRect(x: 40, y: 40, width: 20, height: 120))
        }
        let oriented = UIImage(cgImage: raw.cgImage!, scale: raw.scale, orientation: .right)
        let out = try XCTUnwrap(SignatureProcessor().process(oriented))
        XCTAssertGreaterThan(out.size.width, out.size.height,
            "output must reflect the displayed (oriented) image, not the raw buffer")
    }

    func test_process_blankPage_returnsNil() {
        let blank = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100)).image { ctx in
            UIColor.white.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
        }
        XCTAssertNil(SignatureProcessor().process(blank), "all-paper input has no ink → nil")
    }
}
