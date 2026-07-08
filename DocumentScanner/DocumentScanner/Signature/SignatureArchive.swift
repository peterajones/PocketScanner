import Foundation

/// The complete set of saved signatures, serialized as a single binary-plist
/// file (`signatures.dat`). One file keeps iCloud sync trivial: a fresh device
/// materializes it with one coordinated read, with no per-file placeholder
/// guesswork. Binary plist stores the raw PNG bytes compactly (no base64 bloat).
struct SignatureArchive: Codable {
    struct Entry: Codable {
        let id: String
        let pngData: Data
        var name: String?
        let createdAt: Date
    }

    var entries: [Entry]

    static let empty = SignatureArchive(entries: [])

    func serialized() throws -> Data {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        return try encoder.encode(self)
    }

    static func deserialized(from data: Data) throws -> SignatureArchive {
        try PropertyListDecoder().decode(SignatureArchive.self, from: data)
    }
}
