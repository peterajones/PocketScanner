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

    /// Regression: URL == is byte-exact, so a percent-encoded URL (like the
    /// ones NSMetadataQuery hands us) doesn't equal the non-encoded URL
    /// produced by appendingPathComponent — even when they point to the same
    /// file. The uniqueURL collision check then thinks a different doc exists
    /// at the candidate path and renames with " (2)" suffix, silently moving
    /// the file away from the URL the library is holding.
    func test_storageWrite_percentEncodedExistingURL_doesNotRename() throws {
        let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("DocStorageEncodingTest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let storage = DocumentStorage(documentsURL: tmpDir)
        let img = blankImage(size: CGSize(width: 612, height: 792))
        let scanned = ScannedPage(image: img, observations: [])

        // Seed a file directly on disk with the em-dash name, then construct
        // an "existing URL" using percent-encoded form (mimicking what
        // NSMetadataQuery returns to the library).
        let onDiskURL = tmpDir.appendingPathComponent("Receipt — Jun 2.pdf")
        let seed = try PDFAssembler().assemble(pages: [scanned], createdAt: Date())
        try XCTUnwrap(seed.dataRepresentation()).write(to: onDiskURL)

        let baseString = tmpDir.absoluteString.hasSuffix("/")
            ? tmpDir.absoluteString
            : tmpDir.absoluteString + "/"
        let encodedString = "\(baseString)Receipt%20%E2%80%94%20Jun%202.pdf"
        let encodedURL = try XCTUnwrap(URL(string: encodedString),
                                       "couldn't construct percent-encoded URL")
        // Sanity: the two URLs are NOT == but point to the same file.
        XCTAssertNotEqual(encodedURL, onDiskURL,
                          "URL == should differ when one is percent-encoded")
        XCTAssertEqual(encodedURL.standardizedFileURL.path,
                       onDiskURL.standardizedFileURL.path,
                       "...but the standardized paths should match")

        // Now "save" replacing the encoded URL.
        let pdf2 = try PDFAssembler().assemble(pages: [scanned], createdAt: Date())
        let resultURL = try storage.write(pdf2, replacing: encodedURL, withName: "Receipt — Jun 2")

        XCTAssertEqual(resultURL.standardizedFileURL.path,
                       onDiskURL.standardizedFileURL.path,
                       "replace should overwrite the existing file, not rename to ' (2)'")
        XCTAssertTrue(FileManager.default.fileExists(atPath: onDiskURL.path),
                      "Original on-disk file should still exist after replace")
        let suffixedPath = tmpDir.appendingPathComponent("Receipt — Jun 2 (2).pdf").path
        XCTAssertFalse(FileManager.default.fileExists(atPath: suffixedPath),
                       "Should NOT have written a ' (2)' suffixed file")
    }

    /// Regression for the /private/var prefix mismatch that was actually
    /// causing filter saves to rename docs. NSMetadataQuery hands the
    /// library URLs with /private/var/...; appendingPathComponent against
    /// FileManager.documentDirectory produces /var/... . Both resolve via
    /// the /private symlink, but URL == treats them as different. We need
    /// the collision check to recognize them as the same file.
    func test_storageWrite_privatePrefixExistingURL_doesNotRename() throws {
        let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("DocStoragePrivateTest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let storage = DocumentStorage(documentsURL: tmpDir)
        let img = blankImage(size: CGSize(width: 612, height: 792))
        let scanned = ScannedPage(image: img, observations: [])

        // Seed a file at the documents URL.
        let onDiskURL = tmpDir.appendingPathComponent("MyDoc.pdf")
        let seed = try PDFAssembler().assemble(pages: [scanned], createdAt: Date())
        try XCTUnwrap(seed.dataRepresentation()).write(to: onDiskURL)

        // Construct an "existing URL" with /private/var prefix when the
        // tmpDir is under /var (or vice versa) — whichever applies on the
        // test platform. We use NSString.standardizingPath inverse: prefix
        // the path with "/private" if it starts with "/var", or strip it.
        let altPath: String
        if onDiskURL.path.hasPrefix("/var/") {
            altPath = "/private" + onDiskURL.path
        } else if onDiskURL.path.hasPrefix("/private/var/") {
            altPath = String(onDiskURL.path.dropFirst("/private".count))
        } else {
            // Test environment doesn't have a /var symlink in tmp; skip.
            throw XCTSkip("Test environment doesn't have /var or /private/var prefix on tmp; can't reproduce.")
        }
        let altURL = URL(fileURLWithPath: altPath)
        XCTAssertNotEqual(altURL, onDiskURL, "URL == should distinguish /private/var from /var")
        XCTAssertEqual(altURL.resolvingSymlinksInPath().path,
                       onDiskURL.resolvingSymlinksInPath().path,
                       "...but resolved paths should match")

        // Replace using the alt-prefixed URL — should overwrite in place.
        let pdf2 = try PDFAssembler().assemble(pages: [scanned], createdAt: Date())
        let resultURL = try storage.write(pdf2, replacing: altURL, withName: "MyDoc")
        XCTAssertEqual(resultURL.resolvingSymlinksInPath().path,
                       onDiskURL.resolvingSymlinksInPath().path,
                       "Replace should hit the same path, not rename to ' (2)'")
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: tmpDir.appendingPathComponent("MyDoc (2).pdf").path),
            "Should NOT have written a ' (2)' suffixed file")
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
