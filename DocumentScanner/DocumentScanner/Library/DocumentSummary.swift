import Foundation
import PDFKit

struct DocumentSummary: Identifiable, Hashable {
    let url: URL
    let displayName: String
    let createdAt: Date
    let pageCount: Int
    let ocrSnippet: String
    let isCorrupt: Bool

    var id: URL { url }

    static func fromFile(at url: URL) -> DocumentSummary {
        let displayName = url.deletingPathExtension().lastPathComponent
        // Load via Data rather than URL: PDFKit caches PDFDocument(url:)
        // results process-wide and returns stale nils for files that have
        // been atomic-replaced (e.g. after a filter save). Reading the bytes
        // and passing to PDFDocument(data:) avoids that cache.
        guard let data = try? Data(contentsOf: url),
              let pdf = PDFDocument(data: data) else {
            let fsCreated = (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date()
            return DocumentSummary(url: url, displayName: displayName,
                                   createdAt: fsCreated, pageCount: 0, ocrSnippet: "",
                                   isCorrupt: true)
        }
        let attrs = pdf.documentAttributes ?? [:]
        let created = (attrs[PDFDocumentAttribute.creationDateAttribute] as? Date)
            ?? (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate)
            ?? Date()
        return DocumentSummary(url: url, displayName: displayName,
                               createdAt: created, pageCount: pdf.pageCount,
                               ocrSnippet: pdf.string ?? "", isCorrupt: false)
    }
}
