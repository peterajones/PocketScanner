import XCTest
import PDFKit
import UIKit
@testable import DocumentScanner

final class PDFAssemblerHighlightTests: XCTestCase {

    /// Assembles a 1-page PDF with a single OCR observation, runs findString
    /// for that observation's string, and asserts the resulting PDFSelection's
    /// bounds match the OCR rect within ~5pt horizontal tolerance.
    ///
    /// The previous implementation (no text-matrix scaling) drifts much further
    /// than 5pt because system-font glyph widths don't match the original.
    func test_findStringHighlight_matchesOCRRectWidth() throws {
        // 612x792pt page (US Letter).
        let pageSize = CGSize(width: 612, height: 792)

        // OCR observation: a 30pt-tall band, 400pt wide, positioned 100pt in.
        let ocrRect = CGRect(x: 100, y: 200, width: 400, height: 30)
        let normalized = CGRect(
            x: ocrRect.origin.x / pageSize.width,
            y: ocrRect.origin.y / pageSize.height,
            width: ocrRect.width / pageSize.width,
            height: ocrRect.height / pageSize.height
        )
        let observation = OCRObservation(
            string: "Quick brown fox jumps over the lazy dog",
            boundingBox: normalized
        )

        let image = blankImage(size: pageSize)
        let scanned = ScannedPage(image: image, observations: [observation])
        let pdf = try PDFAssembler().assemble(pages: [scanned], createdAt: Date())

        let selections = pdf.findString(observation.string, withOptions: .caseInsensitive)
        let selection = try XCTUnwrap(selections.first,
                                      "Expected findString to return a match for the observation")

        let page = try XCTUnwrap(pdf.page(at: 0))
        let bounds = selection.bounds(for: page)

        // The OCR rect is in PDF page coordinates (origin bottom-left, y-up).
        // After text-matrix scaling, the selection's x-extent should align
        // with the OCR rect within ~5pt slack.
        XCTAssertEqual(bounds.minX, ocrRect.minX, accuracy: 5,
                       "Selection minX should align with OCR rect minX")
        XCTAssertEqual(bounds.width, ocrRect.width, accuracy: 5,
                       "Selection width should align with OCR rect width")
    }

    /// Regression: same-name save (overwhelmingly common — filter apply,
    /// edit, etc. all save with the same displayName) must overwrite the
    /// existing file in place, not rename to "(2)". The old code did this
    /// via URL comparison which fails on iOS device when the existing URL
    /// has a /private/var prefix and the candidate from appendingPathComponent
    /// has /var. The fix uses a name comparison instead.
    func test_storageWrite_sameNameReplace_doesNotRename() throws {
        let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("DocStorageSameNameTest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let storage = DocumentStorage(documentsURL: tmpDir)
        let img = blankImage(size: CGSize(width: 612, height: 792))
        let scanned = ScannedPage(image: img, observations: [])

        // Seed a file with a name that includes an em-dash (the user's case).
        let firstURL = try storage.write(
            try PDFAssembler().assemble(pages: [scanned], createdAt: Date()),
            preferredName: "Receipt — Jun 2"
        )

        // "Replace" with the same name (mimicking save-after-filter).
        let secondURL = try storage.write(
            try PDFAssembler().assemble(pages: [scanned], createdAt: Date()),
            replacing: firstURL,
            withName: "Receipt — Jun 2"
        )

        XCTAssertEqual(secondURL, firstURL, "Same-name replace should reuse the original URL")
        XCTAssertTrue(FileManager.default.fileExists(atPath: firstURL.path),
                      "Original file should still exist at its URL")
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: tmpDir.appendingPathComponent("Receipt — Jun 2 (2).pdf").path),
            "Should NOT have written a ' (2)' suffixed file")
    }

    /// True-rename case: when the displayName actually changed, save should
    /// write to the new name (no suffix needed if the new name is free).
    func test_storageWrite_actualRename_writesToNewName() throws {
        let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("DocStorageRenameTest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let storage = DocumentStorage(documentsURL: tmpDir)
        let img = blankImage(size: CGSize(width: 612, height: 792))
        let scanned = ScannedPage(image: img, observations: [])

        let originalURL = try storage.write(
            try PDFAssembler().assemble(pages: [scanned], createdAt: Date()),
            preferredName: "Original Name"
        )
        let renamedURL = try storage.write(
            try PDFAssembler().assemble(pages: [scanned], createdAt: Date()),
            replacing: originalURL,
            withName: "New Name"
        )

        XCTAssertEqual(renamedURL.lastPathComponent, "New Name.pdf")
        XCTAssertFalse(FileManager.default.fileExists(atPath: originalURL.path),
                       "Old file should be removed after rename")
        XCTAssertTrue(FileManager.default.fileExists(atPath: renamedURL.path))
    }

    // MARK: - Helpers

    private func blankImage(size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }
}
