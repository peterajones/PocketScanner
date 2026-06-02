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

    /// Reproduces the production filter-corrupts-PDF flow:
    ///   1. assemble + serialize → disk-like bytes
    ///   2. reload from bytes (mimics PDFDocument(url:))
    ///   3. assemble a replacement
    ///   4. replacePage on the reloaded doc
    ///   5. serialize again — production calls dataRepresentation here
    ///   6. reload — production tries to open the file later
    /// If the bytes from step 5 are unreadable, this test fails.
    func test_loadReplacePageReserialize_roundTripsCleanly() throws {
        let pageSize = CGSize(width: 612, height: 792)
        let ocrRect = CGRect(x: 100, y: 200, width: 400, height: 30)
        let normalized = CGRect(
            x: ocrRect.origin.x / pageSize.width,
            y: ocrRect.origin.y / pageSize.height,
            width: ocrRect.width / pageSize.width,
            height: ocrRect.height / pageSize.height
        )
        let obsA = OCRObservation(string: "Page A first line", boundingBox: normalized)
        let obsB = OCRObservation(string: "Page B first line", boundingBox: normalized)
        let obsReplacement = OCRObservation(string: "Replacement page line", boundingBox: normalized)

        let assembler = PDFAssembler()
        let img = blankImage(size: pageSize)

        // Step 1+2: build, serialize, reload (mimics disk round-trip).
        let built = try assembler.assemble(pages: [
            ScannedPage(image: img, observations: [obsA]),
            ScannedPage(image: img, observations: [obsB]),
        ], createdAt: Date())
        let builtBytes = try XCTUnwrap(built.dataRepresentation(),
                                       "initial dataRepresentation returned nil")
        let loaded = try XCTUnwrap(PDFDocument(data: builtBytes),
                                   "reload of initial bytes failed")

        // Step 3: assemble a replacement.
        let replacement = try assembler.assemble(pages: [
            ScannedPage(image: img, observations: [obsReplacement]),
        ], createdAt: Date())

        // Step 4: mutate the loaded doc.
        DocumentMutations.replacePage(in: loaded, at: 0, with: replacement)
        XCTAssertEqual(loaded.pageCount, 2)

        // Step 5: serialize again — production save path.
        let mutatedBytes = try XCTUnwrap(loaded.dataRepresentation(),
                                         "dataRepresentation returned nil after replacePage on loaded doc")

        // Step 6: reload — production reopen path.
        let reloaded = try XCTUnwrap(PDFDocument(data: mutatedBytes),
                                     "PDFDocument(data:) couldn't parse bytes after replacePage on loaded doc — THIS IS THE BUG")
        XCTAssertEqual(reloaded.pageCount, 2,
                       "Reloaded doc lost pages after the full disk-like round-trip")
    }

    /// Mimics the production case where the original PDF on disk was built by
    /// v1.1 PDFAssembler (no CTM ops in the invisible-text stream) and the
    /// replacement page is built by v1.2 PDFAssembler (with CTM ops).
    func test_mixedFormatRoundTrip_v11OriginalV12Replacement() throws {
        let pageSize = CGSize(width: 612, height: 792)
        let img = blankImage(size: pageSize)

        // Build a 2-page "v1.1 style" PDF by hand (no CTM scaling).
        let oldFormatBytes = makeV11StylePDF(image: img, pageSize: pageSize, pageCount: 2)
        let loaded = try XCTUnwrap(PDFDocument(data: oldFormatBytes),
                                   "Built v1.1-style PDF doesn't load")
        XCTAssertEqual(loaded.pageCount, 2)

        // Build a v1.2 replacement via the current PDFAssembler.
        let normalized = CGRect(x: 0.1, y: 0.25, width: 0.6, height: 0.04)
        let obs = OCRObservation(string: "Replacement line", boundingBox: normalized)
        let replacement = try PDFAssembler().assemble(pages: [
            ScannedPage(image: img, observations: [obs]),
        ], createdAt: Date())

        // Mutate + reserialize + reload — the production save path.
        DocumentMutations.replacePage(in: loaded, at: 0, with: replacement)
        let mutatedBytes = try XCTUnwrap(loaded.dataRepresentation(),
                                         "dataRepresentation returned nil after mixed-format replacePage")
        let reloaded = try XCTUnwrap(PDFDocument(data: mutatedBytes),
                                     "PDFDocument(data:) couldn't parse mixed-format bytes — BUG REPRODUCED")
        XCTAssertEqual(reloaded.pageCount, 2)
    }

    /// Builds a PDF the way v1.1 PDFAssembler did: invisible text drawn at
    /// textPosition only, no CTM ops. Used to simulate docs already on disk.
    private func makeV11StylePDF(image: UIImage, pageSize: CGSize, pageCount: Int) -> Data {
        let data = NSMutableData()
        let consumer = CGDataConsumer(data: data)!
        var defaultBox = CGRect(origin: .zero, size: pageSize)
        let context = CGContext(consumer: consumer, mediaBox: &defaultBox, nil)!
        let cgImage = image.cgImage!

        for i in 0..<pageCount {
            var pageRect = CGRect(origin: .zero, size: pageSize)
            context.beginPage(mediaBox: &pageRect)
            context.draw(cgImage, in: pageRect)

            context.saveGState()
            context.setTextDrawingMode(.invisible)
            let str = "Page \(i + 1) v1.1 format"
            let font = UIFont.systemFont(ofSize: 30)
            let attributed = NSAttributedString(string: str, attributes: [
                .font: font, .foregroundColor: UIColor.clear
            ])
            let ctLine = CTLineCreateWithAttributedString(attributed)
            context.textPosition = CGPoint(x: 100, y: 200)
            CTLineDraw(ctLine, context)
            context.restoreGState()

            context.endPage()
        }
        context.closePDF()
        return data as Data
    }

    /// Closer to production: render a v1.1-style page to an image, run it
    /// through ImageFilterEngine with .greyscale, then assemble + replace +
    /// reserialize. If the filtered image is what causes corruption, this
    /// reproduces.
    func test_filteredImageInReplacePageRoundTrip() throws {
        let pageSize = CGSize(width: 1240, height: 1748) // A4-ish at ~150dpi
        let original = blankImage(size: pageSize)
        let oldFormatBytes = makeV11StylePDF(image: original, pageSize: pageSize, pageCount: 2)
        let loaded = try XCTUnwrap(PDFDocument(data: oldFormatBytes))

        // Apply greyscale via the real filter engine.
        let filtered = try XCTUnwrap(ImageFilterEngine().apply(.blackAndWhite, to: original),
                                     "ImageFilterEngine returned nil")

        let normalized = CGRect(x: 0.08, y: 0.20, width: 0.7, height: 0.025)
        let obs = OCRObservation(string: "Filtered replacement line", boundingBox: normalized)
        let replacement = try PDFAssembler().assemble(pages: [
            ScannedPage(image: filtered, observations: [obs]),
        ], createdAt: Date())

        DocumentMutations.replacePage(in: loaded, at: 0, with: replacement)

        let mutatedBytes = try XCTUnwrap(loaded.dataRepresentation(),
                                         "dataRepresentation returned nil")
        let reloaded = try XCTUnwrap(PDFDocument(data: mutatedBytes),
                                     "PDFDocument couldn't parse bytes after filtered replacement — BUG REPRODUCED")
        XCTAssertEqual(reloaded.pageCount, 2)
    }

    /// Most production-like reproduction: load an actual demo-seeded PDF
    /// from disk, run the FULL processAndReplaceFilterOnly logic against it
    /// (render via PageImageRenderer, greyscale via ImageFilterEngine, real
    /// OCR via OCREngine, assemble via PDFAssembler, replacePage,
    /// dataRepresentation), then try to reload the bytes.
    func test_realDemoPDF_greyscaleFilterRoundTrip() async throws {
        let url = URL(fileURLWithPath: "/tmp/demo-lease-before.pdf")
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("demo PDF not present at \(url.path)")
        }
        let loaded = try XCTUnwrap(PDFDocument(url: url), "Demo PDF didn't load")
        let originalPageCount = loaded.pageCount
        XCTAssertGreaterThan(originalPageCount, 0)

        let page = try XCTUnwrap(loaded.page(at: 0))
        let rendered = try XCTUnwrap(PageImageRenderer().image(from: page),
                                     "PageImageRenderer returned nil")

        let filtered = try XCTUnwrap(ImageFilterEngine().apply(.blackAndWhite, to: rendered),
                                     "ImageFilterEngine returned nil for .blackAndWhite")

        let observations = (try? await OCREngine().recognizeText(in: filtered)) ?? []
        print("--- OCR observations: \(observations.count)")

        let replacement = try PDFAssembler().assemble(pages: [
            ScannedPage(image: filtered, observations: observations),
        ], createdAt: Date())

        DocumentMutations.replacePage(in: loaded, at: 0, with: replacement)

        let mutatedBytes = try XCTUnwrap(loaded.dataRepresentation(),
                                         "dataRepresentation returned nil")
        print("--- mutated bytes length: \(mutatedBytes.count)")
        try mutatedBytes.write(to: URL(fileURLWithPath: "/tmp/demo-lease-after.pdf"))

        let reloaded = try XCTUnwrap(PDFDocument(data: mutatedBytes),
                                     "PDFDocument couldn't parse — BUG REPRODUCED")
        XCTAssertEqual(reloaded.pageCount, originalPageCount)
    }

    /// Adds PerspectiveCorrector to the pipeline since that's what Apply
    /// (single-page) actually invokes (processAndReplaceCurrentPage).
    func test_fullProductionFlow_greyscaleApply() async throws {
        let url = URL(fileURLWithPath: "/tmp/demo-lease-before.pdf")
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("demo PDF not present at \(url.path)")
        }
        let loaded = try XCTUnwrap(PDFDocument(url: url))
        let page = try XCTUnwrap(loaded.page(at: 0))
        let rendered = try XCTUnwrap(PageImageRenderer().image(from: page))
        let quad = Quad.fullRect(in: rendered.size)

        // The full Apply path: correct + (no rotation) + filter + OCR + assemble + replace.
        let corrected = try XCTUnwrap(PerspectiveCorrector().correct(rendered, quad: quad),
                                      "corrector returned nil")
        print("--- corrected size: \(corrected.size), scale: \(corrected.scale)")
        let filtered = try XCTUnwrap(ImageFilterEngine().apply(.greyscale, to: corrected),
                                     "filter returned nil")
        print("--- filtered size: \(filtered.size)")
        let observations = (try? await OCREngine().recognizeText(in: filtered)) ?? []

        let replacement = try PDFAssembler().assemble(pages: [
            ScannedPage(image: filtered, observations: observations),
        ], createdAt: Date())
        DocumentMutations.replacePage(in: loaded, at: 0, with: replacement)

        let mutatedBytes = try XCTUnwrap(loaded.dataRepresentation())
        try mutatedBytes.write(to: URL(fileURLWithPath: "/tmp/demo-lease-greyscale.pdf"))
        let reloaded = try XCTUnwrap(PDFDocument(data: mutatedBytes),
                                     "PDFKit couldn't parse — BUG REPRODUCED")
        XCTAssertEqual(reloaded.pageCount, loaded.pageCount)
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
