import UIKit

/// Persists the user's single reusable signature as a transparent PNG. Stored in
/// Application Support (local, not iCloud-synced in v1). Injectable directory so
/// it's unit-testable.
struct SignatureStore {
    private let fileURL: URL

    init(directory: URL = SignatureStore.defaultDirectory) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        self.fileURL = directory.appendingPathComponent("signature.png")
    }

    static var defaultDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Signature", isDirectory: true)
    }

    var hasSignature: Bool { FileManager.default.fileExists(atPath: fileURL.path) }

    func save(_ image: UIImage) throws {
        guard let data = image.pngData() else {
            throw NSError(domain: "SignatureStore", code: 1)
        }
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: fileURL, options: .atomic)
    }

    func load() -> UIImage? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }

    func clear() { try? FileManager.default.removeItem(at: fileURL) }
}
