import XCTest
import PDFKit
@testable import DocumentScanner

final class PDFImporterTests: XCTestCase {

    private func tempDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pdfimport-\(UUID())", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// A real, readable multi-page PDF at `<fresh temp dir>/<name>.pdf`.
    private func makeSourcePDF(named name: String, pages: Int) -> URL {
        let pdf = PDFDocument()
        for i in 0..<pages { pdf.insert(PDFPage(), at: i) }
        let url = tempDir().appendingPathComponent("\(name).pdf")
        pdf.write(to: url)
        return url
    }

    func test_import_validPDF_writesReadableCopy() throws {
        let dest = tempDir()
        let storage = DocumentStorage(documentsURL: dest)
        let source = makeSourcePDF(named: "Contract", pages: 3)

        let url = try PDFImporter.importPDF(from: source, using: storage)

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(url.deletingPathExtension().lastPathComponent, "Contract")
        XCTAssertEqual(try XCTUnwrap(PDFDocument(url: url)).pageCount, 3)
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path), "source not moved/deleted")
    }

    func test_import_collision_getsUniqueName() throws {
        let dest = tempDir()
        let storage = DocumentStorage(documentsURL: dest)

        _ = try PDFImporter.importPDF(from: makeSourcePDF(named: "Doc", pages: 1), using: storage)
        let second = try PDFImporter.importPDF(from: makeSourcePDF(named: "Doc", pages: 1), using: storage)

        XCTAssertNotEqual(second.lastPathComponent, "Doc.pdf", "collision resolved to a new name")
        let pdfs = try FileManager.default.contentsOfDirectory(atPath: dest.path).filter { $0.hasSuffix(".pdf") }
        XCTAssertEqual(pdfs.count, 2, "both imports kept")
    }

    func test_import_invalidPDF_throws_andWritesNothing() throws {
        let dest = tempDir()
        let storage = DocumentStorage(documentsURL: dest)
        let bad = tempDir().appendingPathComponent("notreal.pdf")
        try Data("not a pdf".utf8).write(to: bad)

        XCTAssertThrowsError(try PDFImporter.importPDF(from: bad, using: storage)) { error in
            XCTAssertEqual(error as? PDFImporterError, .unreadablePDF)
        }
        let contents = (try? FileManager.default.contentsOfDirectory(atPath: dest.path)) ?? []
        XCTAssertTrue(contents.isEmpty, "nothing written on failure")
    }
}
