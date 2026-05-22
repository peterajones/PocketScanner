import Foundation
import PDFKit

struct DocumentSummary: Identifiable, Hashable {
    let url: URL
    let displayName: String
    let createdAt: Date
    let pageCount: Int
    let ocrSnippet: String

    var id: URL { url }

    enum LoadError: Error { case unreadablePDF }

    static func fromFile(at url: URL) throws -> DocumentSummary {
        guard let pdf = PDFDocument(url: url) else { throw LoadError.unreadablePDF }
        let attrs = pdf.documentAttributes ?? [:]
        let created = (attrs[PDFDocumentAttribute.creationDateAttribute] as? Date)
            ?? (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate)
            ?? Date()
        return DocumentSummary(
            url: url,
            displayName: url.deletingPathExtension().lastPathComponent,
            createdAt: created,
            pageCount: pdf.pageCount,
            ocrSnippet: pdf.string ?? ""
        )
    }
}
