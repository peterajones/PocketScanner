import Foundation
import PDFKit

/// Pure, in-memory helpers operating on `PDFDocument`. No disk I/O.
/// Most mutate the document in place; `extractPages` returns a new document.
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

    /// Bulk-delete the pages at the given indices. Deletes in descending
    /// order so an earlier removal doesn't shift the meaning of later indices.
    /// Out-of-range entries are skipped.
    static func deletePages(in pdf: PDFDocument, at indices: Set<Int>) {
        for index in indices.sorted(by: >) {
            guard index >= 0, index < pdf.pageCount else { continue }
            pdf.removePage(at: index)
        }
    }

    /// Append all pages from `other` onto `pdf`. Used by "Add Pages" after the
    /// new scans run through ScanPipeline -> PDFAssembler.
    static func append(_ other: PDFDocument, to pdf: PDFDocument) {
        for i in 0..<other.pageCount {
            guard let page = other.page(at: i) else { continue }
            pdf.insert(page, at: pdf.pageCount)
        }
    }

    /// Replace the page at `index` in `pdf` with the first page of `replacement`.
    /// No-op if either bound is invalid.
    static func replacePage(in pdf: PDFDocument, at index: Int, with replacement: PDFDocument) {
        guard index >= 0, index < pdf.pageCount,
              let newPage = replacement.page(at: 0) else { return }
        pdf.removePage(at: index)
        pdf.insert(newPage, at: index)
    }

    /// Rotate the page at `index` 90° clockwise (or counter-clockwise) by setting
    /// its `/Rotate` attribute. Lossless: the page image, the invisible OCR text
    /// layer, and any annotations all rotate together. Normalized to
    /// {0, 90, 180, 270}. No-op if the index is out of range.
    static func rotatePage(in pdf: PDFDocument, at index: Int, clockwise: Bool) {
        guard index >= 0, index < pdf.pageCount, let page = pdf.page(at: index) else { return }
        let delta = clockwise ? 90 : -90
        page.rotation = ((page.rotation + delta) % 360 + 360) % 360
    }

    /// Build a NEW `PDFDocument` containing deep copies of the pages at `indices`,
    /// in ascending index order. The source `pdf` is NOT mutated. Out-of-range
    /// indices are skipped; an empty set yields an empty document. Pages are
    /// extracted via a byte-level copy of the source so that the full content
    /// stream (incl. the invisible OCR text layer) and `/Rotate` value are
    /// preserved. Save the result via `DocumentStorage.write(_:preferredName:)`.
    static func extractPages(from pdf: PDFDocument, at indices: Set<Int>) -> PDFDocument {
        let result = PDFDocument()
        let sorted = indices.sorted().filter { $0 >= 0 && $0 < pdf.pageCount }
        guard !sorted.isEmpty else { return result }

        // Snapshot the source to data so we can pull byte-backed pages from it
        // without re-parenting any page of the original document. Pages taken
        // from `snapshot` will have their full content streams (including the
        // invisible OCR text layer) intact and extractable via `PDFPage.string`.
        guard let data = pdf.dataRepresentation(),
              let snapshot = PDFDocument(data: data) else { return result }

        for index in sorted {
            guard let page = snapshot.page(at: index) else { continue }
            result.insert(page, at: result.pageCount)
        }
        return result
    }
}
