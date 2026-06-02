import Foundation
import PDFKit

enum DocumentStorageError: Error, LocalizedError {
    case writeFailed
    case emptyName
    case corruptOutput(badBytesURL: URL?)

    var errorDescription: String? {
        switch self {
        case .writeFailed: return "Could not write document."
        case .emptyName: return "Document name is empty."
        case .corruptOutput(let url):
            if let url {
                return "Save produced an unreadable PDF. Bad bytes saved to \(url.lastPathComponent) for diagnosis."
            }
            return "Save produced an unreadable PDF."
        }
    }
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

        // Self-check: if dataRepresentation produces bytes that PDFKit
        // can't subsequently parse, refuse to write — we'd just be
        // persisting a corrupt file. Dump the bad bytes to a sibling
        // location for offline diagnosis.
        if PDFDocument(data: data) == nil {
            let badURL = try? saveBadBytesForDiagnosis(data, originalName: sanitized)
            throw DocumentStorageError.corruptOutput(badBytesURL: badURL)
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

    /// Writes corrupt-output bytes to a `_failed-save-<timestamp>-<name>.pdf`
    /// in the documents directory so the user can share them for debugging.
    /// Returns the URL of the written file, or throws if it couldn't write.
    private func saveBadBytesForDiagnosis(_ data: Data, originalName: String) throws -> URL {
        let stamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let url = documentsURL.appendingPathComponent("_failed-save-\(stamp)-\(originalName).pdf")
        try data.write(to: url, options: .atomic)
        return url
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

    /// Rename a folder in place. Sanitizes the new name and resolves
    /// collisions with the same `(N)` suffix scheme used elsewhere.
    @discardableResult
    func renameFolder(at folderURL: URL, to newName: String) throws -> URL {
        let sanitized = Self.sanitize(newName)
        guard !sanitized.isEmpty else { throw DocumentStorageError.emptyName }
        let parent = folderURL.deletingLastPathComponent()
        let desired = parent.appendingPathComponent(sanitized, isDirectory: true)

        // No-op if the user typed the same name back in.
        if desired.standardizedFileURL.path == folderURL.standardizedFileURL.path {
            return folderURL
        }

        let target = try uniqueFolderURL(in: parent, base: sanitized)

        var coordinatorError: NSError?
        var moveError: Error?
        let coordinator = NSFileCoordinator()
        coordinator.coordinate(
            writingItemAt: folderURL, options: .forMoving,
            writingItemAt: target, options: .forReplacing,
            error: &coordinatorError
        ) { src, dst in
            do {
                try FileManager.default.moveItem(at: src, to: dst)
            } catch {
                moveError = error
            }
        }
        if let error = coordinatorError ?? (moveError as NSError?) { throw error }
        return target
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

    private func uniqueFolderURL(in parent: URL, base: String) throws -> URL {
        let candidate = parent.appendingPathComponent(base, isDirectory: true)
        if !FileManager.default.fileExists(atPath: candidate.path) {
            return candidate
        }
        for index in 2...999 {
            let suffixed = parent.appendingPathComponent("\(base) (\(index))", isDirectory: true)
            if !FileManager.default.fileExists(atPath: suffixed.path) {
                return suffixed
            }
        }
        throw DocumentStorageError.writeFailed
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
