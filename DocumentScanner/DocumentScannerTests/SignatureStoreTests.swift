import XCTest
import UIKit
@testable import DocumentScanner

final class SignatureStoreTests: XCTestCase {

    private func tempStore() -> SignatureStore {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("sigstore-\(UUID())", isDirectory: true)
        return SignatureStore(directory: dir)
    }

    private func image(_ size: CGSize = CGSize(width: 60, height: 24)) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor.black.setFill(); ctx.fill(CGRect(origin: .zero, size: size))
        }
    }

    func test_save_then_load_roundTrips() throws {
        let store = tempStore()
        XCTAssertFalse(store.hasSignature)
        try store.save(image())
        XCTAssertTrue(store.hasSignature)
        let loaded = try XCTUnwrap(store.load())
        XCTAssertGreaterThan(loaded.size.width, 0)
        XCTAssertGreaterThan(loaded.size.height, 0)
    }

    func test_clear_removes() throws {
        let store = tempStore()
        try store.save(image())
        store.clear()
        XCTAssertFalse(store.hasSignature)
        XCTAssertNil(store.load())
    }

    func test_load_whenEmpty_isNil() {
        XCTAssertNil(tempStore().load())
    }
}
