import XCTest
import PDFKit
import UIKit
@testable import DocumentScanner

final class SignatureAnnotationPersistenceTests: XCTestCase {

    private func solidImage(_ color: UIColor, _ size: CGSize) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { ctx in
            color.setFill(); ctx.fill(CGRect(origin: .zero, size: size))
        }
    }

    /// A one-page PDF with an image stamp annotation, written to data and
    /// reloaded, must still expose an annotation tagged as our signature on the
    /// page. This is the GO/NO-GO for the editable-stamp model.
    func test_imageStampAnnotation_survivesDataRoundTrip() throws {
        let pdf = PDFDocument()
        let page = PDFPage()
        pdf.insert(page, at: 0)
        _ = page.bounds(for: .mediaBox)

        let stamp = ImageStampAnnotation(
            image: solidImage(.black, CGSize(width: 100, height: 40)),
            bounds: CGRect(x: 50, y: 50, width: 100, height: 40),
            userName: "DocumentScanner.signature")
        page.addAnnotation(stamp)

        let data = try XCTUnwrap(pdf.dataRepresentation())
        let reloaded = try XCTUnwrap(PDFDocument(data: data))
        let reloadedPage = try XCTUnwrap(reloaded.page(at: 0))

        let signatureAnnos = reloadedPage.annotations.filter {
            $0.userName == "DocumentScanner.signature"
        }
        XCTAssertFalse(signatureAnnos.isEmpty,
            "Image stamp annotation did not survive the PDF data round-trip — editable-stamp model is not viable as-is; escalate for the flatten fallback.")
    }

    // MARK: - Visual render spike

    /// Empirically determines whether the image drawn by ImageStampAnnotation's
    /// draw(with:in:) override actually appears in a bitmap render of a reloaded
    /// PDF page, or whether PDFKit drops the visual on reload.
    ///
    /// RENDERS (luminance < 0.5)  → editable-stamp model works as-is.
    /// LOST    (luminance ≥ 0.9)  → draw() override is runtime-only; need an
    ///                               appearance stream or a flatten step.
    func test_imageStampAnnotation_imageRendersAfterReload() throws {
        // 1. Build a 1-page PDF.
        let pdf = PDFDocument()
        let page = PDFPage()
        pdf.insert(page, at: 0)
        let pageBounds = page.bounds(for: .mediaBox)   // e.g. 612 × 792

        // 2. Place a solid-black stamp centered on the page.
        let stampSize = CGSize(width: 100, height: 100)
        let stampOrigin = CGPoint(
            x: pageBounds.midX - stampSize.width  / 2,
            y: pageBounds.midY - stampSize.height / 2)
        let stampRect = CGRect(origin: stampOrigin, size: stampSize)

        let blackImage = solidImage(.black, stampSize)
        let stamp = ImageStampAnnotation(
            image: blackImage,
            bounds: stampRect,
            userName: "DocumentScanner.signature")
        page.addAnnotation(stamp)

        // 3. Round-trip through PDF data.
        let data = try XCTUnwrap(pdf.dataRepresentation(),
                                  "PDF dataRepresentation returned nil")
        let reloaded  = try XCTUnwrap(PDFDocument(data: data),
                                       "Could not reload PDF from data")
        let reloadedPage = try XCTUnwrap(reloaded.page(at: 0),
                                          "Reloaded PDF has no page 0")

        // 4. Render the reloaded page to a bitmap.
        let renderSize = pageBounds.size
        let img = reloadedPage.thumbnail(of: renderSize, for: .mediaBox)

        // 5. Sample the center pixel and compute luminance.
        let lum = centerLuminance(of: img)
        print("CENTER LUMINANCE = \(lum)")
        // Also write to a temp file so the value survives xcodebuild's output buffering.
        try? "CENTER LUMINANCE = \(lum)".write(toFile: "/tmp/signature_luminance.txt",
                                                atomically: true, encoding: .utf8)

        // 6. Assert the center is dark — i.e., the signature image rendered.
        XCTAssertLessThan(lum, 0.5,
            "Center luminance \(lum) is not dark — image did NOT render after reload. " +
            "draw(with:in:) override is runtime-only; need appearance stream or flatten.")
    }

    // MARK: - Pixel-sampling helper

    private func centerLuminance(of image: UIImage) -> CGFloat {
        let cg = image.cgImage!
        let w = cg.width, h = cg.height
        var px: [UInt8] = [0, 0, 0, 0]
        let cs = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(
            data: &px,
            width: 1, height: 1,
            bitsPerComponent: 8, bytesPerRow: 4,
            space: cs,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        // Translate so the source center maps to our 1×1 destination pixel.
        ctx.draw(cg, in: CGRect(x: -w / 2, y: -h / 2, width: w, height: h))
        return (0.299 * CGFloat(px[0]) + 0.587 * CGFloat(px[1]) + 0.114 * CGFloat(px[2])) / 255.0
    }
}
