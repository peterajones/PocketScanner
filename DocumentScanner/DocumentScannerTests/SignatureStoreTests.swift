import XCTest
import UIKit
@testable import DocumentScanner

final class SignatureStoreTests: XCTestCase {

    private func tempDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("sigstore-\(UUID())", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func image(_ w: Int = 60, _ h: Int = 24) -> UIImage {
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: w, height: h), format: fmt).image { ctx in
            UIColor.black.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        }
    }

    func test_add_then_all_returnsIt() throws {
        let store = SignatureStore(directory: tempDir())
        XCTAssertTrue(store.all().isEmpty)
        let sig = try store.add(image())
        let all = store.all()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.id, sig.id)
    }

    func test_multipleAdds_newestFirst() throws {
        let store = SignatureStore(directory: tempDir())
        let a = try store.add(image(40, 10))
        Thread.sleep(forTimeInterval: 0.05)
        let b = try store.add(image(80, 20))
        XCTAssertEqual(store.all().map(\.id), [b.id, a.id], "newest first")
    }

    func test_remove_dropsOne() throws {
        let store = SignatureStore(directory: tempDir())
        let a = try store.add(image())
        Thread.sleep(forTimeInterval: 0.05)
        let b = try store.add(image())
        store.remove(id: a.id)
        XCTAssertEqual(store.all().map(\.id), [b.id])
    }

    func test_signatureWithID_roundTrips() throws {
        let store = SignatureStore(directory: tempDir())
        let a = try store.add(image(50, 30))
        let loaded = store.signature(withID: a.id)
        XCTAssertEqual(loaded?.id, a.id)
        XCTAssertEqual(loaded?.image.cgImage?.width, 50)
        XCTAssertNil(store.signature(withID: "does-not-exist"))
    }

    func test_all_freshStore_namesAreNil() throws {
        let store = SignatureStore(directory: tempDir())
        _ = try store.add(image())
        XCTAssertNil(store.all().first?.name, "a fresh signature is unnamed")
    }

    func test_rename_setsName_roundTrips() throws {
        let store = SignatureStore(directory: tempDir())
        let sig = try store.add(image())
        store.rename(id: sig.id, to: "Work")
        XCTAssertEqual(store.all().first?.name, "Work")
    }

    func test_rename_overwritesPreviousName() throws {
        let store = SignatureStore(directory: tempDir())
        let sig = try store.add(image())
        store.rename(id: sig.id, to: "Work")
        store.rename(id: sig.id, to: "Personal")
        XCTAssertEqual(store.all().first?.name, "Personal")
    }

    func test_rename_blankClearsName() throws {
        let store = SignatureStore(directory: tempDir())
        let sig = try store.add(image())
        store.rename(id: sig.id, to: "Work")
        store.rename(id: sig.id, to: "   ")
        XCTAssertNil(store.all().first?.name, "whitespace-only clears the name")
    }

    func test_rename_trimsWhitespace() throws {
        let store = SignatureStore(directory: tempDir())
        let sig = try store.add(image())
        store.rename(id: sig.id, to: "  Work  ")
        XCTAssertEqual(store.all().first?.name, "Work")
    }

    func test_remove_dropsNameToo() throws {
        let store = SignatureStore(directory: tempDir())
        let a = try store.add(image())
        store.rename(id: a.id, to: "Work")
        store.remove(id: a.id)
        XCTAssertTrue(store.all().isEmpty)
        let b = try store.add(image())
        XCTAssertNil(store.all().first(where: { $0.id == b.id })?.name, "removed name does not linger")
    }

    // MARK: - Migration from the old PNG format

    func test_migratesOldFormatPngsAndNames() throws {
        let dir = tempDir()
        let id1 = UUID().uuidString, id2 = UUID().uuidString
        try image(50, 20).pngData()!.write(to: dir.appendingPathComponent("\(id1).png"))
        try image(60, 20).pngData()!.write(to: dir.appendingPathComponent("\(id2).png"))
        try JSONEncoder().encode([id1: "Work"]).write(to: dir.appendingPathComponent("names.json"))

        let store = SignatureStore(directory: dir)
        let all = store.all()
        XCTAssertEqual(all.count, 2, "both old PNGs migrated into the archive")
        XCTAssertEqual(all.first(where: { $0.id == id1 })?.name, "Work", "name migrated from sidecar")
        XCTAssertNil(all.first(where: { $0.id == id2 })?.name)
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent("\(id1).png").path),
                      "old PNGs left in place as backup")
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent("signatures.dat").path),
                      "archive written")
        XCTAssertEqual(store.all().count, 2, "migration is idempotent")
    }

    func test_migratesLegacySingleSignaturePng() throws {
        let dir = tempDir()
        try image(70, 35).pngData()!.write(to: dir.appendingPathComponent("signature.png"))
        let store = SignatureStore(directory: dir)
        XCTAssertEqual(store.all().count, 1, "legacy signature.png folded into the archive")
        XCTAssertEqual(store.all().count, 1, "idempotent")
    }
}
