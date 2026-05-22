import Foundation
import PDFKit

enum DocumentStorageError: Error {
    case writeFailed
    case emptyName
}

struct DocumentStorage {
    let documentsURL: URL

    func write(_ pdf: PDFDocument, preferredName: String) throws -> URL {
        let sanitized = Self.sanitize(preferredName)
        guard !sanitized.isEmpty else { throw DocumentStorageError.emptyName }

        let url = try uniqueURL(base: sanitized)

        guard let data = pdf.dataRepresentation() else {
            throw DocumentStorageError.writeFailed
        }

        var coordinatorError: NSError?
        var writeError: Error?
        let coordinator = NSFileCoordinator()
        coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: &coordinatorError) { writeURL in
            do {
                try data.write(to: writeURL, options: .atomic)
            } catch {
                writeError = error
            }
        }
        if let error = coordinatorError ?? (writeError as NSError?) {
            throw error
        }
        return url
    }

    // MARK: - Private

    private func uniqueURL(base: String) throws -> URL {
        let candidate = documentsURL.appendingPathComponent("\(base).pdf")
        if !FileManager.default.fileExists(atPath: candidate.path) { return candidate }
        for index in 2...999 {
            let suffixed = documentsURL.appendingPathComponent("\(base) (\(index)).pdf")
            if !FileManager.default.fileExists(atPath: suffixed.path) { return suffixed }
        }
        throw DocumentStorageError.writeFailed
    }

    private static func sanitize(_ name: String) -> String {
        let illegal = CharacterSet(charactersIn: "/\\:*?\"<>|")
        let cleaned = name
            .components(separatedBy: illegal)
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned
    }
}
