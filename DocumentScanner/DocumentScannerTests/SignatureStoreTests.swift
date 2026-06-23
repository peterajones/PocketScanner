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

    func test_migratesLegacySignaturePng() throws {
        let dir = tempDir()
        try image(70, 35).pngData()!.write(to: dir.appendingPathComponent("signature.png"))
        let store = SignatureStore(directory: dir)
        let all = store.all()
        XCTAssertEqual(all.count, 1, "legacy signature folded into the collection")
        XCTAssertFalse(FileManager.default.fileExists(atPath: dir.appendingPathComponent("signature.png").path),
                       "legacy file renamed away")
        XCTAssertEqual(store.all().count, 1, "migration is idempotent")
    }
}
