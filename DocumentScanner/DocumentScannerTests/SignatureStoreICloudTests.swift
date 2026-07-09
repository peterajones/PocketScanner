import XCTest
import UIKit
@testable import DocumentScanner

/// Exercises the iCloud convergence logic with an injected fake iCloud directory
/// (a temp dir) — no real iCloud account needed. "Signed out" = nil provider.
final class SignatureStoreICloudTests: XCTestCase {

    private func tempDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("sigicloud-\(UUID())", isDirectory: true)
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

    private func datExists(in dir: URL) -> Bool {
        FileManager.default.fileExists(atPath: dir.appendingPathComponent("signatures.dat").path)
    }

    func test_iCloudArchiveIsSourceOfTruth() throws {
        let local = tempDir(); let cloud = tempDir()
        let store = SignatureStore(localDirectory: local, iCloudDirectoryProvider: { cloud })
        let a = try store.add(image())
        XCTAssertTrue(datExists(in: cloud), "add writes to the iCloud location")
        XCTAssertFalse(datExists(in: local), "not written locally when signed into iCloud")
        XCTAssertEqual(store.all().map(\.id), [a.id])
    }

    func test_promotesLocalArchiveToICloud() throws {
        let local = tempDir(); let cloud = tempDir()
        // Signed out: writes go local.
        let localStore = SignatureStore(localDirectory: local, iCloudDirectoryProvider: { nil })
        let a = try localStore.add(image())
        XCTAssertTrue(datExists(in: local))

        // Signed in later: reading promotes the local archive up to iCloud.
        let cloudStore = SignatureStore(localDirectory: local, iCloudDirectoryProvider: { cloud })
        XCTAssertEqual(cloudStore.all().map(\.id), [a.id], "reads promoted signatures")
        XCTAssertTrue(datExists(in: cloud), "archive promoted into the iCloud directory")
    }

    func test_promotesOldPngFormatDirectlyToICloud() throws {
        let local = tempDir(); let cloud = tempDir()
        // Old-format signatures sit in the local (Application Support) dir.
        let id = UUID().uuidString
        try image(50, 20).pngData()!.write(to: local.appendingPathComponent("\(id).png"))

        let store = SignatureStore(localDirectory: local, iCloudDirectoryProvider: { cloud })
        XCTAssertEqual(store.all().map(\.id), [id], "old PNG migrated")
        XCTAssertTrue(datExists(in: cloud), "migrated archive lands in iCloud")
    }

    func test_fallsBackToLocalWhenSignedOut() throws {
        let local = tempDir()
        let store = SignatureStore(localDirectory: local, iCloudDirectoryProvider: { nil })
        _ = try store.add(image())
        XCTAssertTrue(datExists(in: local))
        XCTAssertEqual(store.all().count, 1)
    }

    func test_corruptICloudArchive_returnsEmpty_andIsPreserved() throws {
        let cloud = tempDir()
        let corrupt = Data("not a plist".utf8)
        try corrupt.write(to: cloud.appendingPathComponent("signatures.dat"))
        let store = SignatureStore(localDirectory: tempDir(), iCloudDirectoryProvider: { cloud })
        XCTAssertTrue(store.all().isEmpty, "corrupt archive → empty, no crash")
        let after = try Data(contentsOf: cloud.appendingPathComponent("signatures.dat"))
        XCTAssertEqual(after, corrupt, "corrupt file left intact, never overwritten by a read")
    }

    func test_orderNewestFirst_acrossReopen() throws {
        let cloud = tempDir(); let local = tempDir()
        let store = SignatureStore(localDirectory: local, iCloudDirectoryProvider: { cloud })
        let a = try store.add(image())
        Thread.sleep(forTimeInterval: 0.05)
        let b = try store.add(image())
        let reopened = SignatureStore(localDirectory: tempDir(), iCloudDirectoryProvider: { cloud })
        XCTAssertEqual(reopened.all().map(\.id), [b.id, a.id])
    }
}
