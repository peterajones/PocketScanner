import XCTest
@testable import DocumentScanner

final class SearchContextTests: XCTestCase {

    func test_totalMatches_sumsAcrossDocs() {
        let ctx = SearchContext(
            term: "fox",
            docs: [
                .init(summary: makeSummary(name: "a"), matchCount: 3),
                .init(summary: makeSummary(name: "b"), matchCount: 5),
                .init(summary: makeSummary(name: "c"), matchCount: 1),
            ],
            startDocIndex: 0
        )
        XCTAssertEqual(ctx.totalMatches, 9)
    }

    func test_totalMatches_zeroWhenDocsEmpty() {
        let ctx = SearchContext(term: "fox", docs: [], startDocIndex: 0)
        XCTAssertEqual(ctx.totalMatches, 0)
    }

    func test_hashable_equalContextsAreEqual() {
        let docs: [SearchContext.DocEntry] = [
            .init(summary: makeSummary(name: "a"), matchCount: 2),
        ]
        let a = SearchContext(term: "fox", docs: docs, startDocIndex: 0)
        let b = SearchContext(term: "fox", docs: docs, startDocIndex: 0)
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.hashValue, b.hashValue)
    }

    func test_hashable_differentTermNotEqual() {
        let docs: [SearchContext.DocEntry] = [
            .init(summary: makeSummary(name: "a"), matchCount: 2),
        ]
        let a = SearchContext(term: "fox", docs: docs, startDocIndex: 0)
        let b = SearchContext(term: "dog", docs: docs, startDocIndex: 0)
        XCTAssertNotEqual(a, b)
    }

    func test_hashable_differentStartIndexNotEqual() {
        let docs: [SearchContext.DocEntry] = [
            .init(summary: makeSummary(name: "a"), matchCount: 2),
            .init(summary: makeSummary(name: "b"), matchCount: 1),
        ]
        let a = SearchContext(term: "fox", docs: docs, startDocIndex: 0)
        let b = SearchContext(term: "fox", docs: docs, startDocIndex: 1)
        XCTAssertNotEqual(a, b)
    }

    // MARK: - Helpers

    private func makeSummary(name: String) -> DocumentSummary {
        DocumentSummary(
            url: URL(fileURLWithPath: "/tmp/\(name).pdf"),
            displayName: name,
            createdAt: Date(timeIntervalSince1970: 0),
            pageCount: 1,
            ocrSnippet: "the quick brown \(name)",
            isCorrupt: false
        )
    }
}
