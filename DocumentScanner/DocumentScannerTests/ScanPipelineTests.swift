import XCTest
import UIKit
import PDFKit
@testable import DocumentScanner

final class ScanPipelineTests: XCTestCase {

    func test_process_returnsPDFWithSamePageCount() async throws {
        let images = [whiteImage(), whiteImage(), whiteImage()]
        let pipeline = ScanPipeline(ocr: StubOCR(returning: []))
        let result = try await pipeline.process(images: images)
        XCTAssertEqual(result.pdf.pageCount, 3)
    }

    func test_process_failsGracefully_whenOCRFailsForOnePage() async throws {
        let images = [whiteImage(), whiteImage()]
        let pipeline = ScanPipeline(ocr: FailingOnceOCR())
        let result = try await pipeline.process(images: images)
        XCTAssertEqual(result.pdf.pageCount, 2,
                       "page should be included even if OCR fails")
    }

    func test_process_returnsConcatenatedOCRText() async throws {
        let images = [whiteImage(), whiteImage()]
        let pipeline = ScanPipeline(ocr: StubOCR(returning: ["hello", "world"]))
        let result = try await pipeline.process(images: images)
        XCTAssertTrue(result.ocrText.contains("hello"))
        XCTAssertTrue(result.ocrText.contains("world"))
    }

    func test_recognize_returnsPagePerImageWithObservations() async throws {
        let images = [whiteImage(), whiteImage()]
        let pipeline = ScanPipeline(ocr: StubOCR(returning: ["alpha"]))
        let pages = await pipeline.recognize(images: images)
        XCTAssertEqual(pages.count, 2)
        XCTAssertTrue(pages.allSatisfy { page in
            page.observations.contains { $0.string == "alpha" }
        })
    }

    func test_assemble_withFilter_keepsSearchableTextLayer() async throws {
        let needle = "FilterNeedle"
        let pipeline = ScanPipeline(ocr: StubOCR(returning: [needle]))
        let pages = await pipeline.recognize(images: [whiteImage()])
        let result = try await pipeline.assemble(pages: pages, filter: .blackAndWhite)
        XCTAssertEqual(result.pdf.pageCount, 1)
        XCTAssertFalse(result.pdf.findString(needle, withOptions: .caseInsensitive).isEmpty,
                       "the B&W filter must not break the OCR text layer")
        XCTAssertTrue(result.ocrText.contains(needle))
    }

    // MARK: - Helpers

    private func whiteImage() -> UIImage {
        UIGraphicsBeginImageContextWithOptions(CGSize(width: 100, height: 100), true, 1)
        UIColor.white.setFill()
        UIRectFill(CGRect(x: 0, y: 0, width: 100, height: 100))
        let img = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return img
    }

    private struct StubOCR: OCRProviding {
        let observations: [OCRObservation]
        init(returning strings: [String]) {
            // Default bounding box for tests — value doesn't matter for the
            // pipeline tests since they don't inspect positions.
            let defaultBox = CGRect(x: 0.1, y: 0.5, width: 0.8, height: 0.05)
            self.observations = strings.map { OCRObservation(string: $0, boundingBox: defaultBox) }
        }
        func recognizeText(in image: UIImage) async throws -> [OCRObservation] { observations }
    }

    private struct FailingOnceOCR: OCRProviding {
        func recognizeText(in image: UIImage) async throws -> [OCRObservation] {
            throw NSError(domain: "test", code: 1)
        }
    }
}
