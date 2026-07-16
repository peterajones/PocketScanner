import XCTest
import PDFKit
@testable import DocumentScanner

@MainActor
final class DocumentSessionTests: XCTestCase {

    var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    /// The search-highlight rebuild (audit finding #5) must key on `revision`,
    /// not `ObjectIdentifier(pdf)`: `DocumentMutations` mutates the PDF IN PLACE,
    /// so the object identity is stable and a rebuild keyed on it never fires
    /// after a page delete/reorder. This pins the invariant the fix relies on —
    /// a persisted mutation bumps `revision`.
    func test_save_bumpsRevisionSoHighlightKeyChanges() throws {
        let storage = DocumentStorage(documentsURL: tempDir)
        let url = try storage.write(makeTwoPagePDF(), preferredName: "Doc")
        let session = try DocumentSession(summary: .fromFile(at: url), storage: storage)

        let identityBefore = ObjectIdentifier(session.pdf)
        let revisionBefore = session.revision

        DocumentMutations.deletePage(in: session.pdf, at: 0)
        _ = try session.save()

        XCTAssertEqual(ObjectIdentifier(session.pdf), identityBefore,
                       "in-place mutation keeps the same PDFDocument object — the exact #5 trap")
        XCTAssertGreaterThan(session.revision, revisionBefore,
                             "a persisted mutation must bump revision so the composite rebuild key changes")
    }

    private func makeTwoPagePDF() -> PDFDocument {
        let doc = PDFDocument()
        let img = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100)).image { _ in
            UIColor.white.setFill()
            UIRectFill(CGRect(x: 0, y: 0, width: 100, height: 100))
        }
        doc.insert(PDFPage(image: img)!, at: 0)
        doc.insert(PDFPage(image: img)!, at: 1)
        return doc
    }
}
