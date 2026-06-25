import XCTest
@testable import DocumentScanner

final class MergeCandidatesTests: XCTestCase {

    private func summary(_ name: String, corrupt: Bool = false) -> DocumentSummary {
        DocumentSummary(
            url: URL(fileURLWithPath: "/docs/\(name).pdf"),
            displayName: name, createdAt: Date(), pageCount: 1,
            ocrSnippet: "", isCorrupt: corrupt
        )
    }

    func test_excludesSourceItself() {
        let a = summary("A"), b = summary("B"), c = summary("C")
        let result = MergeCandidates.list(source: a, all: [a, b, c])
        XCTAssertEqual(result.map(\.displayName), ["B", "C"])
    }

    func test_excludesCorruptDocuments() {
        let a = summary("A"), b = summary("B"), bad = summary("Damaged", corrupt: true)
        let result = MergeCandidates.list(source: a, all: [a, b, bad])
        XCTAssertEqual(result.map(\.displayName), ["B"])
    }

    func test_emptyWhenSourceIsOnlyValidDoc() {
        let a = summary("A"), bad = summary("Damaged", corrupt: true)
        XCTAssertTrue(MergeCandidates.list(source: a, all: [a, bad]).isEmpty)
    }
}
