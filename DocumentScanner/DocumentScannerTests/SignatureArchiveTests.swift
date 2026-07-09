import XCTest
@testable import DocumentScanner

final class SignatureArchiveTests: XCTestCase {

    func test_binaryRoundTrip_preservesEntries() throws {
        let now = Date()
        let archive = SignatureArchive(entries: [
            .init(id: "a", pngData: Data([0x89, 0x50]), name: "Work", createdAt: now),
            .init(id: "b", pngData: Data([0x01, 0x02, 0x03]), name: nil, createdAt: now.addingTimeInterval(1))
        ])

        let data = try archive.serialized()
        let decoded = try SignatureArchive.deserialized(from: data)

        XCTAssertEqual(decoded.entries.map(\.id), ["a", "b"])
        XCTAssertEqual(decoded.entries[0].name, "Work")
        XCTAssertNil(decoded.entries[1].name)
        XCTAssertEqual(decoded.entries[1].pngData, Data([0x01, 0x02, 0x03]))
    }

    func test_empty_hasNoEntries() {
        XCTAssertTrue(SignatureArchive.empty.entries.isEmpty)
    }

    func test_deserialize_garbage_throws() {
        XCTAssertThrowsError(try SignatureArchive.deserialized(from: Data("nope".utf8)))
    }
}
