import PDFKit

enum DocumentMergeError: Error {
    /// The source or target PDF could not be read.
    case unreadable
}

/// File-level orchestration for merging one document into another: append the
/// source's pages to the end of the target, save the target in place, then
/// delete the source. The source is deleted ONLY after the target saves, so a
/// load or save failure never loses data (both originals survive).
enum DocumentMerge {
    static func merge(source: URL, into target: URL, targetName: String) throws {
        guard let targetPDF = PDFDocument(url: target),
              let sourcePDF = PDFDocument(url: source) else {
            throw DocumentMergeError.unreadable
        }
        DocumentMutations.append(sourcePDF, to: targetPDF)
        // Scope storage to the target's own directory so the in-place overwrite
        // (and any collision resolution inside `write`) happens where the target
        // actually lives, regardless of which folder the caller is viewing.
        let storage = DocumentStorage(documentsURL: target.deletingLastPathComponent())
        _ = try storage.write(targetPDF, replacing: target, withName: targetName)
        try storage.delete(at: source)
    }
}
