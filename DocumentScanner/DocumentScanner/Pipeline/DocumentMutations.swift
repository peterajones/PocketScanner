import Foundation
import PDFKit

/// Pure helpers that mutate a `PDFDocument` in place. No disk I/O.
/// Save the document via `DocumentStorage.write(_:replacing:withName:)` after.
enum DocumentMutations {

    static func reorder(in pdf: PDFDocument, from: Int, to: Int) {
        guard from != to, let page = pdf.page(at: from) else { return }
        pdf.removePage(at: from)
        let clampedTo = min(to, pdf.pageCount)
        pdf.insert(page, at: clampedTo)
    }

    static func deletePage(in pdf: PDFDocument, at index: Int) {
        guard index >= 0, index < pdf.pageCount else { return }
        pdf.removePage(at: index)
    }

    /// Append all pages from `other` onto `pdf`. Used by "Add Pages" after the
    /// new scans run through ScanPipeline -> PDFAssembler.
    static func append(_ other: PDFDocument, to pdf: PDFDocument) {
        for i in 0..<other.pageCount {
            guard let page = other.page(at: i) else { continue }
            pdf.insert(page, at: pdf.pageCount)
        }
    }
}
