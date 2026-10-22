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

    /// A PDF whose pages are described by `kinds`: `.image(text)` draws `text` as a
    /// bitmap (no text layer, like a camera scan saved as PDF); `.text(text)` draws it
    /// as real PDF text (like an emailed contract). Letter-size pages.
    private func makeMixedPDF(_ kinds: [PageKind], rotation: Int = 0) -> URL {
        let bounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        let data = UIGraphicsPDFRenderer(bounds: bounds).pdfData { ctx in
            for kind in kinds {
                ctx.beginPage()
                switch kind {
                case .image(let text):
                    textImage(text).draw(in: CGRect(x: 36, y: 72, width: 540, height: 135))
                case .text(let text):
                    (text as NSString).draw(at: CGPoint(x: 72, y: 72),
                                            withAttributes: [.font: UIFont.systemFont(ofSize: 24)])
                }
            }
        }
        let pdf = PDFDocument(data: data)!
        if rotation != 0 {
            for i in 0..<pdf.pageCount { pdf.page(at: i)!.rotation = rotation }
        }
        let url = tempDir().appendingPathComponent("Source.pdf")
        pdf.write(to: url)
        return url
    }

    private enum PageKind { case image(String), text(String) }

    /// Black text on white, rendered to a bitmap so it carries no PDF text.
    private func textImage(_ text: String) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: CGSize(width: 1600, height: 400), format: format).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 1600, height: 400))
            (text as NSString).draw(at: CGPoint(x: 40, y: 120),
                                    withAttributes: [.font: UIFont.boldSystemFont(ofSize: 120),
                                                     .foregroundColor: UIColor.black])
        }
    }

    private func pageText(_ url: URL, _ index: Int) throws -> String {
        try XCTUnwrap(PDFDocument(url: url)?.page(at: index)).string ?? ""
    }

    // MARK: - Existing behaviour

    func test_import_validPDF_writesReadableCopy() async throws {
        let dest = tempDir()
        let storage = DocumentStorage(documentsURL: dest)
        let source = makeSourcePDF(named: "Contract", pages: 3)

        let url = try await PDFImporter.importPDF(from: source, using: storage, ocr: StubOCR([]))

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(url.deletingPathExtension().lastPathComponent, "Contract")
        XCTAssertEqual(try XCTUnwrap(PDFDocument(url: url)).pageCount, 3)
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path), "source not moved/deleted")
    }

    func test_import_collision_getsUniqueName() async throws {
        let dest = tempDir()
        let storage = DocumentStorage(documentsURL: dest)

        _ = try await PDFImporter.importPDF(from: makeSourcePDF(named: "Doc", pages: 1), using: storage, ocr: StubOCR([]))
        let second = try await PDFImporter.importPDF(from: makeSourcePDF(named: "Doc", pages: 1), using: storage, ocr: StubOCR([]))

        XCTAssertNotEqual(second.lastPathComponent, "Doc.pdf", "collision resolved to a new name")
        let pdfs = try FileManager.default.contentsOfDirectory(atPath: dest.path).filter { $0.hasSuffix(".pdf") }
        XCTAssertEqual(pdfs.count, 2, "both imports kept")
    }

    func test_import_invalidPDF_throws_andWritesNothing() async throws {
        let dest = tempDir()
        let storage = DocumentStorage(documentsURL: dest)
        let bad = tempDir().appendingPathComponent("notreal.pdf")
        try Data("not a pdf".utf8).write(to: bad)

        do {
            _ = try await PDFImporter.importPDF(from: bad, using: storage, ocr: StubOCR([]))
            XCTFail("expected unreadablePDF")
        } catch {
            XCTAssertEqual(error as? PDFImporterError, .unreadablePDF)
        }
        let contents = (try? FileManager.default.contentsOfDirectory(atPath: dest.path)) ?? []
        XCTAssertTrue(contents.isEmpty, "nothing written on failure")
    }

    // MARK: - Text layer for image-only pages

    func test_import_imageOnlyPage_gainsTextLayer() async throws {
        let storage = DocumentStorage(documentsURL: tempDir())
        let source = makeMixedPDF([.image("LAB")])

        let url = try await PDFImporter.importPDF(from: source, using: storage, ocr: StubOCR(["Lab Results"]))

        XCTAssertTrue(try pageText(url, 0).contains("Lab Results"))
    }

    func test_import_pageWithText_isNotOCRed() async throws {
        let storage = DocumentStorage(documentsURL: tempDir())
        let ocr = CountingOCR()
        let source = makeMixedPDF([.text("Consulting Agreement")])

        let url = try await PDFImporter.importPDF(from: source, using: storage, ocr: ocr)

        XCTAssertEqual(ocr.calls, 0)
        XCTAssertEqual(try pageText(url, 0), try pageText(source, 0))
    }

    func test_import_mixedPDF_onlyImagePagesAreOCRed() async throws {
        let storage = DocumentStorage(documentsURL: tempDir())
        let ocr = CountingOCR()
        let source = makeMixedPDF([.text("Cover letter"), .image("SCAN"), .text("Terms")])

        let url = try await PDFImporter.importPDF(from: source, using: storage, ocr: ocr)

        XCTAssertEqual(ocr.calls, 1)
        XCTAssertEqual(try XCTUnwrap(PDFDocument(url: url)).pageCount, 3)
        XCTAssertTrue(try pageText(url, 0).contains("Cover letter"))
        XCTAssertTrue(try pageText(url, 1).contains("counted"))
        XCTAssertTrue(try pageText(url, 2).contains("Terms"))
    }

    func test_import_ocrFailure_stillImportsThePage() async throws {
        let storage = DocumentStorage(documentsURL: tempDir())
        let source = makeMixedPDF([.image("LAB"), .image("RX")])

        let url = try await PDFImporter.importPDF(from: source, using: storage, ocr: FailingOCR())

        XCTAssertEqual(try XCTUnwrap(PDFDocument(url: url)).pageCount, 2)
    }

    func test_import_reportsProgressPerOCRedPage() async throws {
        let storage = DocumentStorage(documentsURL: tempDir())
        let source = makeMixedPDF([.image("A"), .text("B"), .image("C")])
        let recorder = ProgressRecorder()

        _ = try await PDFImporter.importPDF(from: source, using: storage, ocr: StubOCR(["x"]),
                                            onProgress: { recorder.record($0, $1) })

        XCTAssertEqual(recorder.steps.map { [$0.0, $0.1] }, [[1, 2], [2, 2]])
    }

    func test_import_imageOnlyPDF_realOCR_isSearchable() async throws {
        let storage = DocumentStorage(documentsURL: tempDir())
        let source = makeMixedPDF([.image("PRESCRIPTION")])

        let url = try await PDFImporter.importPDF(from: source, using: storage)

        let doc = try XCTUnwrap(PDFDocument(url: url))
        XCTAssertFalse(doc.findString("prescription", withOptions: .caseInsensitive).isEmpty,
                       "got text: \(doc.string ?? "nil")")
    }

    func test_import_rotatedImageOnlyPage_keepsItsLookAndIsSearchable() async throws {
        let storage = DocumentStorage(documentsURL: tempDir())
        // A landscape scan stored as a portrait page rotated 90°: the text only reads
        // upright as displayed, so OCR must run on the page as the viewer shows it.
        let source = makeMixedPDF([.image("RECEIPT")], rotation: 90)
        let before = try XCTUnwrap(PDFDocument(url: source)?.page(at: 0))
        let shownBefore = before.bounds(for: .cropBox).applying(CGAffineTransform(rotationAngle: .pi / 2))

        let url = try await PDFImporter.importPDF(from: source, using: storage)

        let doc = try XCTUnwrap(PDFDocument(url: url))
        let page = try XCTUnwrap(doc.page(at: 0))
        let shown = page.bounds(for: .cropBox).applying(CGAffineTransform(rotationAngle: CGFloat(page.rotation) * .pi / 180))
        XCTAssertEqual(abs(shown.width), abs(shownBefore.width), accuracy: 1)
        XCTAssertEqual(abs(shown.height), abs(shownBefore.height), accuracy: 1)
        XCTAssertFalse(doc.findString("receipt", withOptions: .caseInsensitive).isEmpty,
                       "got text: \(doc.string ?? "nil")")
    }

    // MARK: - Doubles

    private struct StubOCR: OCRProviding {
        let strings: [String]
        init(_ strings: [String]) { self.strings = strings }
        func recognizeText(in image: UIImage) async throws -> [OCRObservation] {
            strings.map { OCRObservation(string: $0, boundingBox: CGRect(x: 0.1, y: 0.5, width: 0.8, height: 0.05)) }
        }
    }

    private final class CountingOCR: OCRProviding, @unchecked Sendable {
        private let lock = NSLock()
        private var _calls = 0
        var calls: Int { lock.withLock { _calls } }
        func recognizeText(in image: UIImage) async throws -> [OCRObservation] {
            lock.withLock { _calls += 1 }
            return [OCRObservation(string: "counted", boundingBox: CGRect(x: 0.1, y: 0.5, width: 0.8, height: 0.05))]
        }
    }

    private struct FailingOCR: OCRProviding {
        func recognizeText(in image: UIImage) async throws -> [OCRObservation] {
            throw NSError(domain: "test", code: 1)
        }
    }

    private final class ProgressRecorder: @unchecked Sendable {
        private let lock = NSLock()
        private var _steps: [(Int, Int)] = []
        var steps: [(Int, Int)] { lock.withLock { _steps } }
        func record(_ current: Int, _ total: Int) { lock.withLock { _steps.append((current, total)) } }
    }
}
