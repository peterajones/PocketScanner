import Foundation
import PDFKit

enum PDFImporterError: Error, Equatable {
    case unreadablePDF
}

/// Imports an existing PDF into the library by reusing `DocumentStorage`. Used by
/// both entry points (the document handler and the in-app picker). The source file
/// is never moved or deleted — we copy it in.
enum PDFImporter {
    /// - Parameters:
    ///   - sourceURL: a possibly security-scoped URL from Files / another app.
    ///   - storage: destination storage (root or the current folder).
    /// - Returns: the new document's URL.
    /// - Throws: `PDFImporterError.unreadablePDF` if the file isn't a readable PDF,
    ///   or a `DocumentStorage` error on write failure.
    static func importPDF(from sourceURL: URL, using storage: DocumentStorage) throws -> URL {
        let scoped = sourceURL.startAccessingSecurityScopedResource()
        defer { if scoped { sourceURL.stopAccessingSecurityScopedResource() } }

        guard let pdf = PDFDocument(url: sourceURL) else {
            throw PDFImporterError.unreadablePDF
        }
        let name = sourceURL.deletingPathExtension().lastPathComponent
        return try storage.write(pdf, preferredName: name)
    }
}
