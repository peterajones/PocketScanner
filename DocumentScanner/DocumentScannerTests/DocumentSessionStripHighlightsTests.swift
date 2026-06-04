import XCTest
import PDFKit
@testable import DocumentScanner

@MainActor
final class DocumentSessionStripHighlightsTests: XCTestCase {

    /// New semantics: save() strips only annotations tagged as SEARCH highlights.
    /// User marks (highlight + strikethrough) and other annotations survive.
    func test_save_stripsOnlySearchHighlights() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let image = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100)).image { _ in
            UIColor.white.setFill()
            UIRectFill(CGRect(x: 0, y: 0, width: 100, height: 100))
        }
        let pdf = try PDFAssembler().assemble(
            pages: [ScannedPage(image: image, observations: [])],
            createdAt: Date()
        )
        let storage = DocumentStorage(documentsURL: tempDir)
        let initialURL = try storage.write(pdf, preferredName: "Test")
        let summary = DocumentSummary(url: initialURL, displayName: "Test",
                                      createdAt: Date(), pageCount: 1, ocrSnippet: "",
                                      isCorrupt: false)
        let session = try DocumentSession(summary: summary, storage: storage)

        let page = try XCTUnwrap(session.pdf.page(at: 0))
        let bounds = page.bounds(for: .mediaBox)

        // (a) A SEARCH highlight — must be stripped.
        let searchHL = PDFAnnotation(bounds: bounds, forType: .highlight, withProperties: nil)
        searchHL.userName = DocumentSession.searchHighlightAnnotationName
        page.addAnnotation(searchHL)

        // (b) A USER highlight — must survive.
        let userHL = PDFAnnotation(bounds: bounds, forType: .highlight, withProperties: nil)
        userHL.userName = DocumentSession.userAnnotationName
        page.addAnnotation(userHL)

        // (c) A USER strikethrough — must survive.
        let userStrike = PDFAnnotation(bounds: bounds, forType: .strikeOut, withProperties: nil)
        userStrike.userName = DocumentSession.userAnnotationName
        page.addAnnotation(userStrike)

        // (d) A non-mark annotation (free text) — must survive (only search
        // highlights are stripped).
        let note = PDFAnnotation(bounds: bounds, forType: .freeText, withProperties: nil)
        note.contents = "note that should survive"
        page.addAnnotation(note)

        _ = try session.save()

        let reloaded = try XCTUnwrap(PDFDocument(url: initialURL))
        let reloadedPage = try XCTUnwrap(reloaded.page(at: 0))
        let types = reloadedPage.annotations.map(\.type)

        XCTAssertEqual(types.filter { $0 == "Highlight" }.count, 1,
                       "exactly the user highlight should survive; search highlight stripped. types: \(types)")
        XCTAssertTrue(types.contains("StrikeOut"),
                      "user strikethrough should survive. types: \(types)")
        XCTAssertTrue(types.contains("FreeText"),
                      "non-mark annotations should survive. types: \(types)")
    }
}
