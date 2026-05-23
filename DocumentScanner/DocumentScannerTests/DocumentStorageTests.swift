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

    func test_replace_overwritesExistingFile() throws {
        let storage = DocumentStorage(documentsURL: tempDir)
        let url = try storage.write(makeSinglePagePDF(), preferredName: "Receipt")
        let originalData = try Data(contentsOf: url)

        // A structurally different PDF (2 pages).
        let twoPagePDF: PDFDocument = {
            let d = PDFDocument()
            d.insert(makeSinglePagePDF().page(at: 0)!, at: 0)
            d.insert(makeSinglePagePDF().page(at: 0)!, at: 1)
            return d
        }()
        let returnedURL = try storage.write(twoPagePDF, replacing: url, withName: "Receipt")

        XCTAssertEqual(returnedURL, url)
        let newData = try Data(contentsOf: returnedURL)
        XCTAssertNotEqual(originalData, newData, "file should have been overwritten")
        let reloaded = try XCTUnwrap(PDFDocument(url: returnedURL))
        XCTAssertEqual(reloaded.pageCount, 2)
    }

    func test_replace_renamesFileWhenNameChanges() throws {
        let storage = DocumentStorage(documentsURL: tempDir)
        let url = try storage.write(makeSinglePagePDF(), preferredName: "Receipt")
        let newURL = try storage.write(makeSinglePagePDF(), replacing: url, withName: "Lease Agreement")
        XCTAssertEqual(newURL.lastPathComponent, "Lease Agreement.pdf")
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path),
                       "old file should have been removed")
        XCTAssertTrue(FileManager.default.fileExists(atPath: newURL.path))
    }

    func test_replace_resolvesCollisionWhenRenamingToExistingName() throws {
        let storage = DocumentStorage(documentsURL: tempDir)
        _ = try storage.write(makeSinglePagePDF(), preferredName: "Lease")
        let other = try storage.write(makeSinglePagePDF(), preferredName: "Receipt")
        let renamedURL = try storage.write(makeSinglePagePDF(), replacing: other, withName: "Lease")
        XCTAssertEqual(renamedURL.lastPathComponent, "Lease (2).pdf")
    }

    func test_delete_removesFile() throws {
        let storage = DocumentStorage(documentsURL: tempDir)
        let url = try storage.write(makeSinglePagePDF(), preferredName: "Receipt")
        try storage.delete(at: url)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
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
