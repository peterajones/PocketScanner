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

    /// Overwrite the existing file at `existingURL`, possibly renaming it to a new
    /// sanitized name. If the new name collides with another file (other than the
    /// one we're replacing), resolves with `(N)` suffix. Returns the final URL.
    func write(_ pdf: PDFDocument, replacing existingURL: URL, withName preferredName: String) throws -> URL {
        let sanitized = Self.sanitize(preferredName)
        guard !sanitized.isEmpty else { throw DocumentStorageError.emptyName }

        let targetURL = try uniqueURL(base: sanitized, allowingMatch: existingURL)

        guard let data = pdf.dataRepresentation() else {
            throw DocumentStorageError.writeFailed
        }

        var coordinatorError: NSError?
        var writeError: Error?
        let coordinator = NSFileCoordinator()
        coordinator.coordinate(writingItemAt: targetURL, options: .forReplacing, error: &coordinatorError) { url in
            do {
                try data.write(to: url, options: .atomic)
            } catch {
                writeError = error
            }
        }
        if let error = coordinatorError ?? (writeError as NSError?) { throw error }

        if targetURL != existingURL {
            try? FileManager.default.removeItem(at: existingURL)
        }
        return targetURL
    }

    func delete(at url: URL) throws {
        var coordinatorError: NSError?
        var removeError: Error?
        let coordinator = NSFileCoordinator()
        coordinator.coordinate(writingItemAt: url, options: .forDeleting, error: &coordinatorError) { url in
            do { try FileManager.default.removeItem(at: url) }
            catch { removeError = error }
        }
        if let error = coordinatorError ?? (removeError as NSError?) { throw error }
    }

    // MARK: - Private

    private func uniqueURL(base: String, allowingMatch: URL? = nil) throws -> URL {
        let candidate = documentsURL.appendingPathComponent("\(base).pdf")
        if candidate == allowingMatch || !FileManager.default.fileExists(atPath: candidate.path) {
            return candidate
        }
        for index in 2...999 {
            let suffixed = documentsURL.appendingPathComponent("\(base) (\(index)).pdf")
            if suffixed == allowingMatch || !FileManager.default.fileExists(atPath: suffixed.path) {
                return suffixed
            }
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
