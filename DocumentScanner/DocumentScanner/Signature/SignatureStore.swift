import UIKit

/// Persists the user's reusable signatures as a single binary-plist archive
/// (`signatures.dat`). Local-only in this task; Task 3 adds iCloud resolution.
/// The public API (all/add/remove/rename/signature(withID:)) is unchanged so
/// callers stay untouched.
struct SignatureStore {
    private let localDirectory: URL
    private let iCloudDirectoryProvider: () -> URL?
    private let archiveName = "signatures.dat"

    init(
        localDirectory: URL = SignatureStore.defaultLocalDirectory,
        iCloudDirectoryProvider: @escaping () -> URL? = { nil }
    ) {
        self.localDirectory = localDirectory
        self.iCloudDirectoryProvider = iCloudDirectoryProvider
        try? FileManager.default.createDirectory(at: localDirectory, withIntermediateDirectories: true)
    }

    /// Convenience for tests / local-only callers.
    init(directory: URL) {
        self.init(localDirectory: directory, iCloudDirectoryProvider: { nil })
    }

    static var defaultLocalDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Signature", isDirectory: true)
    }

    // MARK: - Public API

    /// All saved signatures, newest first.
    func all() -> [Signature] {
        loadArchive().entries
            .sorted { $0.createdAt > $1.createdAt }
            .compactMap { entry in
                guard let img = UIImage(data: entry.pngData) else { return nil }
                return Signature(id: entry.id, image: img, name: entry.name)
            }
    }

    @discardableResult
    func add(_ image: UIImage) throws -> Signature {
        guard let data = image.pngData() else { throw NSError(domain: "SignatureStore", code: 1) }
        var archive = loadArchive()
        let entry = SignatureArchive.Entry(id: UUID().uuidString, pngData: data, name: nil, createdAt: Date())
        archive.entries.append(entry)
        try writeArchive(archive, to: preferredArchiveURL())
        return Signature(id: entry.id, image: image, name: nil)
    }

    func remove(id: String) {
        var archive = loadArchive()
        archive.entries.removeAll { $0.id == id }
        try? writeArchive(archive, to: preferredArchiveURL())
    }

    /// Sets or clears a signature's name. A blank/whitespace-only name reverts it
    /// to unnamed. Name is trimmed before saving.
    func rename(id: String, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        var archive = loadArchive()
        guard let idx = archive.entries.firstIndex(where: { $0.id == id }) else { return }
        archive.entries[idx].name = trimmed.isEmpty ? nil : trimmed
        try? writeArchive(archive, to: preferredArchiveURL())
    }

    func signature(withID id: String) -> Signature? {
        guard let entry = loadArchive().entries.first(where: { $0.id == id }),
              let img = UIImage(data: entry.pngData) else { return nil }
        return Signature(id: entry.id, image: img, name: entry.name)
    }

    // MARK: - Location

    /// The archive location writes/reads target. Local-only in this task.
    private func preferredArchiveURL() -> URL {
        localDirectory.appendingPathComponent(archiveName)
    }

    // MARK: - Load / converge

    /// Loads the archive, seeding it once from the old PNG format if needed.
    /// NEVER overwrites an existing file — a corrupt file degrades to empty.
    private func loadArchive() -> SignatureArchive {
        let url = preferredArchiveURL()
        if FileManager.default.fileExists(atPath: url.path) {
            return readArchive(at: url) ?? .empty
        }
        if let seed = localSeedArchive() {
            try? writeArchive(seed, to: url)
            return seed
        }
        return .empty
    }

    /// Builds a seed archive from local data: an existing local archive, else the
    /// old-format `<uuid>.png` files (+ `names.json`). Returns nil if nothing to migrate.
    private func localSeedArchive() -> SignatureArchive? {
        let localURL = localDirectory.appendingPathComponent(archiveName)
        if FileManager.default.fileExists(atPath: localURL.path),
           let existing = readArchive(at: localURL) {
            return existing
        }
        return buildArchiveFromLegacy()
    }

    /// One-time migration: fold old `<uuid>.png` files (+ legacy single
    /// `signature.png`, + `names.json`) into an archive. Leaves the PNGs on disk
    /// as a local backup. Returns nil when there are no PNGs.
    private func buildArchiveFromLegacy() -> SignatureArchive? {
        let fm = FileManager.default
        guard let urls = try? fm.contentsOfDirectory(
            at: localDirectory, includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]) else { return nil }
        let pngs = urls.filter { $0.pathExtension.lowercased() == "png" }
        guard !pngs.isEmpty else { return nil }
        let names = loadLegacyNames()
        var entries: [SignatureArchive.Entry] = []
        for url in pngs {
            guard let data = try? Data(contentsOf: url) else { continue }
            let stem = url.deletingPathExtension().lastPathComponent
            // Legacy single "signature.png" has no UUID stem — assign one.
            let id = (stem == "signature") ? UUID().uuidString : stem
            let created = (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date()
            entries.append(.init(id: id, pngData: data, name: names[stem], createdAt: created))
        }
        return entries.isEmpty ? nil : SignatureArchive(entries: entries)
    }

    private func loadLegacyNames() -> [String: String] {
        let url = localDirectory.appendingPathComponent("names.json")
        guard let data = try? Data(contentsOf: url),
              let dict = try? JSONDecoder().decode([String: String].self, from: data)
        else { return [:] }
        return dict
    }

    // MARK: - Coordinated I/O

    private func readArchive(at url: URL) -> SignatureArchive? {
        var archive: SignatureArchive?
        var coordError: NSError?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordError) { readURL in
            guard let data = try? Data(contentsOf: readURL) else { return }
            archive = try? SignatureArchive.deserialized(from: data)
        }
        return archive
    }

    private func writeArchive(_ archive: SignatureArchive, to url: URL) throws {
        let data = try archive.serialized()
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        var coordError: NSError?
        var writeError: Error?
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forReplacing, error: &coordError) { writeURL in
            do { try data.write(to: writeURL, options: .atomic) } catch { writeError = error }
        }
        if let error = coordError ?? (writeError as NSError?) { throw error }
    }
}
