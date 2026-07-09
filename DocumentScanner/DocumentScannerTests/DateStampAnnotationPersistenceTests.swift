import XCTest
import PDFKit
@testable import DocumentScanner

/// A date stamp is an ImageStampAnnotation tagged as a date, carrying the rendered
/// date string in `contents` so Move can re-render it — even after a save→reload.
/// This proves the tag + string survive the PDF data round-trip.
final class DateStampAnnotationPersistenceTests: XCTestCase {

    func test_dateStamp_tagAndContents_persistAcrossReload() throws {
        let pdf = PDFDocument(); let page = PDFPage(); pdf.insert(page, at: 0)
        let img = DateStampRenderer.image(for: "2026-07-09")
        let stamp = ImageStampAnnotation(image: img,
                                         bounds: CGRect(x: 20, y: 20, width: 120, height: 36),
                                         userName: DocumentSession.dateStampAnnotationName)
        stamp.contents = "2026-07-09"
        page.addAnnotation(stamp)

        let data = try XCTUnwrap(pdf.dataRepresentation())
        let reloaded = try XCTUnwrap(PDFDocument(data: data))
        let anno = try XCTUnwrap(reloaded.page(at: 0)?.annotations.first {
            $0.userName == DocumentSession.dateStampAnnotationName
        })
        XCTAssertEqual(anno.contents, "2026-07-09",
                       "rendered date must survive in contents so Move can re-render it")
    }
}
