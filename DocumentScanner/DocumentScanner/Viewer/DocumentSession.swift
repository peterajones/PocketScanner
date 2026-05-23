import Foundation
import Observation
import PDFKit

/// Per-screen view-model owning the document the viewer is showing. Wraps
/// the file URL, the parsed PDFDocument, and the document's display name
/// (filename without extension). Saves back to disk via DocumentStorage
/// at explicit save points.
@MainActor
@Observable
final class DocumentSession {
    private(set) var url: URL
    private(set) var pdf: PDFDocument
    var displayName: String

    private let storage: DocumentStorage

    /// Annotation `userName` that marks PDFAnnotations added by the search-highlight
    /// view layer. `save()` strips these before writing so they don't persist.
    static let searchHighlightAnnotationName = "DocumentScanner.searchHighlight"

    enum InitError: Error { case unreadablePDF }

    init(summary: DocumentSummary, storage: DocumentStorage) throws {
        guard let pdf = PDFDocument(url: summary.url) else { throw InitError.unreadablePDF }
        self.url = summary.url
        self.pdf = pdf
        self.displayName = summary.displayName
        self.storage = storage
    }

    /// Persist the current `pdf` over the current `url`. Used after edit-mode
    /// mutations or rename. Returns the (possibly new) URL.
    @discardableResult
    func save() throws -> URL {
        stripSearchHighlightAnnotations()
        let newURL = try storage.write(pdf, replacing: url, withName: displayName)
        self.url = newURL
        return newURL
    }

    private func stripSearchHighlightAnnotations() {
        for i in 0..<pdf.pageCount {
            guard let page = pdf.page(at: i) else { continue }
            for annotation in page.annotations
                where annotation.userName == Self.searchHighlightAnnotationName {
                page.removeAnnotation(annotation)
            }
        }
    }
}
