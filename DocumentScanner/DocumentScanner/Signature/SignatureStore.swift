import UIKit

/// Persists the user's reusable signatures as transparent PNGs (one `<uuid>.png`
/// per signature) in Application Support. Local only; the injectable directory
/// keeps it testable and makes a future iCloud move a localized change.
struct SignatureStore {
    private let directory: URL

    init(directory: URL = SignatureStore.defaultDirectory) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        self.directory = directory
    }

    static var defaultDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Signature", isDirectory: true)
    }

    /// All saved signatures, newest first.
    func all() -> [Signature] {
        migrateLegacyIfNeeded()
        let fm = FileManager.default
        guard let urls = try? fm.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]) else { return [] }
        let pngs = urls.filter { $0.pathExtension.lowercased() == "png" }
        let newestFirst = pngs.sorted {
            let a = (try? $0.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            let b = (try? $1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            return a > b
        }
        return newestFirst.compactMap { url in
            guard let data = try? Data(contentsOf: url), let img = UIImage(data: data) else { return nil }
            return Signature(id: url.deletingPathExtension().lastPathComponent, image: img)
        }
    }

    @discardableResult
    func add(_ image: UIImage) throws -> Signature {
        migrateLegacyIfNeeded()
        guard let data = image.pngData() else { throw NSError(domain: "SignatureStore", code: 1) }
        let id = UUID().uuidString
        try data.write(to: directory.appendingPathComponent("\(id).png"), options: .atomic)
        return Signature(id: id, image: image)
    }

    func remove(id: String) {
        try? FileManager.default.removeItem(at: directory.appendingPathComponent("\(id).png"))
    }

    func signature(withID id: String) -> Signature? {
        let url = directory.appendingPathComponent("\(id).png")
        guard let data = try? Data(contentsOf: url), let img = UIImage(data: data) else { return nil }
        return Signature(id: id, image: img)
    }

    /// One-time: fold a legacy single `signature.png` into the collection by
    /// renaming it to a `<uuid>.png`. Idempotent (no-op once gone).
    private func migrateLegacyIfNeeded() {
        let legacy = directory.appendingPathComponent("signature.png")
        guard FileManager.default.fileExists(atPath: legacy.path) else { return }
        let dest = directory.appendingPathComponent("\(UUID().uuidString).png")
        try? FileManager.default.moveItem(at: legacy, to: dest)
    }
}
