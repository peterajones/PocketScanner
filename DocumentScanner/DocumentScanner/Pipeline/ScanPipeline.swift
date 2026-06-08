import UIKit
import PDFKit
import OSLog

/// The combined output of a scan pipeline run.
struct ScanResult {
    /// Searchable PDF assembled from the input page images. Caller writes this
    /// to disk via `DocumentStorage`.
    let pdf: PDFDocument
    /// All OCR-recognized text across pages, joined with newlines in input order.
    /// Used to populate `DocumentSummary.ocrSnippet` for library search.
    let ocrText: String
}

/// Orchestrates OCR + PDF assembly. Implemented as an actor so concurrent calls
/// (rare but possible if the user kicks off two scans quickly) are serialized.
actor ScanPipeline {
    private let ocr: OCRProviding
    private let assembler: PDFAssembler
    private let filterEngine = ImageFilterEngine()
    private let logger = Logger(subsystem: "ca.peter-jones.DocumentScanner", category: "Pipeline")

    init(ocr: OCRProviding = OCREngine(), assembler: PDFAssembler = PDFAssembler()) {
        self.ocr = ocr
        self.assembler = assembler
    }

    /// OCR each image. OCR runs on the ORIGINAL (unfiltered) image so that a
    /// later visual filter never degrades text recognition. Per-page OCR
    /// failures are logged and absorbed — the page is still returned, without a
    /// text layer.
    func recognize(images: [UIImage]) async -> [ScannedPage] {
        var pages: [ScannedPage] = []
        pages.reserveCapacity(images.count)
        for (index, image) in images.enumerated() {
            let observations: [OCRObservation]
            do {
                observations = try await ocr.recognizeText(in: image)
            } catch {
                logger.error("OCR failed on page \(index + 1, privacy: .public): \(error.localizedDescription, privacy: .public)")
                observations = []
            }
            pages.append(ScannedPage(image: image, observations: observations))
        }
        return pages
    }

    /// Apply `filter` to each page's image, then assemble the searchable PDF from
    /// the filtered images + the (original-image) observations. A filter that
    /// fails to render falls back to the original image.
    func assemble(pages: [ScannedPage], filter: ImageFilter, createdAt: Date = .init()) throws -> ScanResult {
        let filteredPages = pages.map { page -> ScannedPage in
            let image = filterEngine.apply(filter, to: page.image) ?? page.image
            return ScannedPage(image: image, observations: page.observations)
        }
        let pdf = try assembler.assemble(pages: filteredPages, createdAt: createdAt)
        let ocrText = pages
            .flatMap(\.observations)
            .map(\.string)
            .joined(separator: "\n")
        return ScanResult(pdf: pdf, ocrText: ocrText)
    }

    /// Convenience: recognize + assemble with no filter. Used by add-pages and
    /// any caller that doesn't offer a filter choice.
    func process(images: [UIImage], createdAt: Date = .init()) async throws -> ScanResult {
        let pages = await recognize(images: images)
        return try assemble(pages: pages, filter: .none, createdAt: createdAt)
    }
}
