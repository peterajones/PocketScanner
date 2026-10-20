import UIKit

/// The no-UI save path for instant scan: OCR, auto-name, apply the default filter and
/// write to the Main Library root. Same sequence as `NameDocumentSheet.save()`, minus
/// the sheet. The caller supplies the filter and paper size (the user's defaults).
struct SilentScanSaver {
    let pipeline: ScanPipeline
    let storage: DocumentStorage

    func save(images: [UIImage], filter: ImageFilter, paperSize: PaperSize, now: Date = .init()) async throws -> URL {
        let pages = await pipeline.recognize(images: images)
        let ocrText = pages.flatMap(\.observations).map(\.string).joined(separator: "\n")
        let name = DefaultDocumentName.suggest(from: ocrText, now: now) ?? DefaultDocumentName.fallback(now: now)
        let result = try await pipeline.assemble(pages: pages, filter: filter, paperSize: paperSize, createdAt: now)
        return try storage.write(result.pdf, preferredName: name)
    }
}
