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
        guard let pdf = PDFDocument(url: url) else {
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

extension DocumentSummary {
    /// The "date · pages" line shown under the name in list rows and grid tiles
    /// (or a read-error message for corrupt documents). Shared so the two
    /// presentations never diverge.
    var formattedSubtitle: String {
        if isCorrupt { return "Couldn't read this file" }
        let date = createdAt.formatted(date: .abbreviated, time: .omitted)
        let pages = pageCount == 1 ? "1 page" : "\(pageCount) pages"
        return "\(date) · \(pages)"
    }
}
