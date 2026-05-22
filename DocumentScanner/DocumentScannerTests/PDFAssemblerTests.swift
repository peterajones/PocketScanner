import XCTest
import PDFKit
import UIKit
@testable import DocumentScanner

final class PDFAssemblerTests: XCTestCase {

    func test_assemble_singlePage_producesPDFWithOnePage() throws {
        let image = whitePageImage()
        let page = ScannedPage(image: image, recognizedStrings: [])
        let pdf = try PDFAssembler().assemble(pages: [page], createdAt: Date())
        XCTAssertEqual(pdf.pageCount, 1)
    }

    func test_assemble_multiplePages_producesCorrectPageCount() throws {
        let image = whitePageImage()
        let pages = (0..<3).map { _ in ScannedPage(image: image, recognizedStrings: []) }
        let pdf = try PDFAssembler().assemble(pages: pages, createdAt: Date())
        XCTAssertEqual(pdf.pageCount, 3)
    }

    func test_assemble_embedsRecognizedTextSoStringIsSearchable() throws {
        let image = whitePageImage()
        let page = ScannedPage(
            image: image,
            recognizedStrings: ["The quick brown fox", "jumps over the lazy dog"]
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
            pages: [ScannedPage(image: image, recognizedStrings: [])],
            createdAt: date
        )
        let attrs = pdf.documentAttributes ?? [:]
        XCTAssertEqual(attrs[PDFDocumentAttribute.creationDateAttribute] as? Date, date)
    }

    func test_assemble_metadataSurvivesByteRoundTrip() throws {
        let image = whitePageImage()
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let pdf = try PDFAssembler().assemble(
            pages: [ScannedPage(image: image, recognizedStrings: [])],
            createdAt: date
        )
        let data = try XCTUnwrap(pdf.dataRepresentation())
        let reloaded = try XCTUnwrap(PDFDocument(data: data))
        XCTAssertEqual(reloaded.documentAttributes?[PDFDocumentAttribute.creationDateAttribute] as? Date, date)
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
            pages: [ScannedPage(image: rotated, recognizedStrings: [])],
            createdAt: Date()
        )
        let bounds = try XCTUnwrap(pdf.page(at: 0)).bounds(for: .mediaBox)
        XCTAssertEqual(bounds.width, 200, accuracy: 0.5)
        XCTAssertEqual(bounds.height, 100, accuracy: 0.5)
    }

    // MARK: - Helpers

    private func whitePageImage() -> UIImage {
        UIGraphicsBeginImageContextWithOptions(CGSize(width: 612, height: 792), true, 1)
        UIColor.white.setFill()
        UIRectFill(CGRect(x: 0, y: 0, width: 612, height: 792))
        let img = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return img
    }
}
