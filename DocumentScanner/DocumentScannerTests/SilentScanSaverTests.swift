import XCTest
import UIKit
import PDFKit
@testable import DocumentScanner

final class SilentScanSaverTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SilentScanSaverTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    func test_save_writesPDFAtRootNamedFromOCR() async throws {
        let saver = SilentScanSaver(
            pipeline: ScanPipeline(ocr: StubOCR(returning: ["Banana Bread", "Ingredients", "3 ripe bananas", "Directions"])),
            storage: DocumentStorage(documentsURL: root))
        let images = [whiteImage(), whiteImage()]

        let url = try await saver.save(images: images, filter: .none, paperSize: .auto)

        XCTAssertEqual(url.deletingLastPathComponent().standardizedFileURL.path, root.standardizedFileURL.path)
        XCTAssertEqual(url.lastPathComponent, "Recipe, Banana Bread.pdf")
        XCTAssertEqual(PDFDocument(url: url)?.pageCount, images.count)
    }

    func test_save_noSuggestion_usesFallbackName() async throws {
        let saver = SilentScanSaver(
            pipeline: ScanPipeline(ocr: StubOCR(returning: [])),
            storage: DocumentStorage(documentsURL: root))
        let now = Date(timeIntervalSince1970: 1_780_000_000)

        let url = try await saver.save(images: [whiteImage()], filter: .none, paperSize: .auto, now: now)

        // DocumentStorage replaces ":" (illegal in file names) with "-" in "Scan 2026-05-28 14:30".
        let expected = DefaultDocumentName.fallback(now: now).replacingOccurrences(of: ":", with: "-")
        XCTAssertEqual(url.lastPathComponent, expected + ".pdf")
    }

    func test_save_writeFailure_throwsAndWritesNothing() async throws {
        let saver = SilentScanSaver(
            pipeline: ScanPipeline(ocr: StubOCR(returning: ["hello"])),
            storage: DocumentStorage(documentsURL: URL(fileURLWithPath: "/dev/null/x")))

        do {
            _ = try await saver.save(images: [whiteImage()], filter: .none, paperSize: .auto)
            XCTFail("expected save to throw")
        } catch {}

        let contents = try FileManager.default.contentsOfDirectory(atPath: root.path)
        XCTAssertTrue(contents.filter { $0.hasSuffix(".pdf") }.isEmpty)
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
            let box = CGRect(x: 0.1, y: 0.5, width: 0.8, height: 0.05)
            self.observations = strings.map { OCRObservation(string: $0, boundingBox: box) }
        }
        func recognizeText(in image: UIImage) async throws -> [OCRObservation] { observations }
    }
}
