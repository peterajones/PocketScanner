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

    // MARK: - Folders

    /// Create a folder at the root documents URL. Sanitizes the name the same
    /// way doc names get sanitized so paths stay portable. Throws if the name
    /// is empty or collides with an existing folder.
    @discardableResult
    func createFolder(named name: String) throws -> URL {
        let sanitized = Self.sanitize(name)
        guard !sanitized.isEmpty else { throw DocumentStorageError.emptyName }
        let folderURL = documentsURL.appendingPathComponent(sanitized, isDirectory: true)

        var coordinatorError: NSError?
        var createError: Error?
        let coordinator = NSFileCoordinator()
        coordinator.coordinate(writingItemAt: folderURL, options: .forReplacing, error: &coordinatorError) { url in
            do {
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false, attributes: nil)
            } catch {
                createError = error
            }
        }
        if let error = coordinatorError ?? (createError as NSError?) { throw error }
        return folderURL
    }

    /// Move a document from its current URL into the given folder. Returns the
    /// document's new URL. If the destination already contains a file with the
    /// same name, the moved file gets a `(N)` suffix.
    @discardableResult
    func moveDocument(at sourceURL: URL, toFolder folderURL: URL) throws -> URL {
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let destinationURL = try uniqueURL(in: folderURL, base: baseName)

        var coordinatorError: NSError?
        var moveError: Error?
        let coordinator = NSFileCoordinator()
        coordinator.coordinate(
            writingItemAt: sourceURL, options: .forMoving,
            writingItemAt: destinationURL, options: .forReplacing,
            error: &coordinatorError
        ) { src, dst in
            do {
                try FileManager.default.moveItem(at: src, to: dst)
            } catch {
                moveError = error
            }
        }
        if let error = coordinatorError ?? (moveError as NSError?) { throw error }
        return destinationURL
    }

    /// List folder URLs at the root level (non-recursive).
    func listFolders() throws -> [URL] {
        let contents = try FileManager.default.contentsOfDirectory(
            at: documentsURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        return contents.filter { url in
            (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        }
    }

    /// Delete a folder including all of its contents. Coordinated so iCloud
    /// sees the removal as a single operation.
    func deleteFolder(at folderURL: URL) throws {
        var coordinatorError: NSError?
        var removeError: Error?
        let coordinator = NSFileCoordinator()
        coordinator.coordinate(writingItemAt: folderURL, options: .forDeleting, error: &coordinatorError) { url in
            do { try FileManager.default.removeItem(at: url) }
            catch { removeError = error }
        }
        if let error = coordinatorError ?? (removeError as NSError?) { throw error }
    }

    // MARK: - Private

    private func uniqueURL(base: String, allowingMatch: URL? = nil) throws -> URL {
        try uniqueURL(in: documentsURL, base: base, allowingMatch: allowingMatch)
    }

    private func uniqueURL(in parent: URL, base: String, allowingMatch: URL? = nil) throws -> URL {
        let candidate = parent.appendingPathComponent("\(base).pdf")
        if candidate == allowingMatch || !FileManager.default.fileExists(atPath: candidate.path) {
            return candidate
        }
        for index in 2...999 {
            let suffixed = parent.appendingPathComponent("\(base) (\(index)).pdf")
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
