import XCTest
import PDFKit
@testable import DocumentScanner

final class DocumentMergeTests: XCTestCase {

    var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    /// Writes a PDF with `pageCount` pages to `tempDir` and returns its URL.
    private func writePDF(_ name: String, pages pageCount: Int) throws -> URL {
        let pdf = PDFDocument()
        for _ in 0..<pageCount {
            pdf.insert(PDFPage(), at: pdf.pageCount)
        }
        let url = tempDir.appendingPathComponent("\(name).pdf")
        let data = try XCTUnwrap(pdf.dataRepresentation())
        try data.write(to: url)
        return url
    }

    func test_merge_appendsSourcePagesToTargetAndDeletesSource() throws {
        let storage = DocumentStorage(documentsURL: tempDir)
        let target = try writePDF("Target", pages: 2)
        let source = try writePDF("Source", pages: 3)

        try DocumentMerge.merge(source: source, into: target,
                                targetName: "Target", using: storage)

        let merged = try XCTUnwrap(PDFDocument(url: target))
        XCTAssertEqual(merged.pageCount, 5, "target should hold both docs' pages")
        XCTAssertFalse(FileManager.default.fileExists(atPath: source.path),
                       "source file should be deleted after a successful merge")
    }

    func test_merge_unreadableSource_throwsAndDeletesNothing() throws {
        let storage = DocumentStorage(documentsURL: tempDir)
        let target = try writePDF("Target", pages: 2)
        // A non-PDF file standing in for a corrupt/unreadable source.
        let source = tempDir.appendingPathComponent("Source.pdf")
        try Data("not a pdf".utf8).write(to: source)

        XCTAssertThrowsError(
            try DocumentMerge.merge(source: source, into: target,
                                    targetName: "Target", using: storage))

        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path),
                      "source must NOT be deleted when the merge fails")
        let untouched = try XCTUnwrap(PDFDocument(url: target))
        XCTAssertEqual(untouched.pageCount, 2, "target must be unchanged on failure")
    }
}
