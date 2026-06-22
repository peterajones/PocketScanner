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
}
