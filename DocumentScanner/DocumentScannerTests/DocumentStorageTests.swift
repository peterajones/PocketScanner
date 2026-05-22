import XCTest
import PDFKit
@testable import DocumentScanner

final class DocumentStorageTests: XCTestCase {

    var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func test_write_savesPDFToProvidedDirectoryWithExpectedFilename() throws {
        let storage = DocumentStorage(documentsURL: tempDir)
        let url = try storage.write(makeSinglePagePDF(), preferredName: "Receipt")
        XCTAssertEqual(url.lastPathComponent, "Receipt.pdf")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    func test_write_resolvesCollisionsBySuffix() throws {
        let storage = DocumentStorage(documentsURL: tempDir)
        let first = try storage.write(makeSinglePagePDF(), preferredName: "Receipt")
        let second = try storage.write(makeSinglePagePDF(), preferredName: "Receipt")
        let third = try storage.write(makeSinglePagePDF(), preferredName: "Receipt")
        XCTAssertEqual(first.lastPathComponent, "Receipt.pdf")
        XCTAssertEqual(second.lastPathComponent, "Receipt (2).pdf")
        XCTAssertEqual(third.lastPathComponent, "Receipt (3).pdf")
    }

    func test_write_sanitizesIllegalFilenameCharacters() throws {
        let storage = DocumentStorage(documentsURL: tempDir)
        let url = try storage.write(makeSinglePagePDF(), preferredName: "A/B:C")
        XCTAssertFalse(url.lastPathComponent.contains("/"))
        XCTAssertFalse(url.lastPathComponent.contains(":"))
        XCTAssertTrue(url.lastPathComponent.hasSuffix(".pdf"))
    }

    // MARK: - Helpers

    private func makeSinglePagePDF() -> PDFDocument {
        let doc = PDFDocument()
        UIGraphicsBeginImageContextWithOptions(CGSize(width: 100, height: 100), true, 1)
        UIColor.white.setFill()
        UIRectFill(CGRect(x: 0, y: 0, width: 100, height: 100))
        let img = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        doc.insert(PDFPage(image: img)!, at: 0)
        return doc
    }
}
