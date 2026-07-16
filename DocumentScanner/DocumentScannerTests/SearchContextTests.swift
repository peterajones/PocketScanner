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

    // MARK: - liveTotalMatches (audit #5 follow-up: stale find-bar total)

    /// Editing pages in the open doc changes its live match count. The find-bar
    /// total must substitute that for the frozen search-time snapshot while
    /// keeping the (unedited) snapshot counts of the other docs.
    func test_liveTotalMatches_substitutesCurrentDocLiveCount() {
        let ctx = makeContext(counts: [5, 3, 2]) // snapshot total = 10
        // Deleted 2 matches from the doc at index 1 (was 3, now 1).
        XCTAssertEqual(ctx.liveTotalMatches(currentDocIndex: 1, liveCurrentDocMatchCount: 1), 8)
    }

    func test_liveTotalMatches_unchangedWhenLiveEqualsSnapshot() {
        let ctx = makeContext(counts: [5, 3, 2])
        XCTAssertEqual(ctx.liveTotalMatches(currentDocIndex: 0, liveCurrentDocMatchCount: 5), 10)
    }

    func test_liveTotalMatches_outOfRangeIndexFallsBackToSnapshotTotal() {
        let ctx = makeContext(counts: [5, 3, 2])
        XCTAssertEqual(ctx.liveTotalMatches(currentDocIndex: 9, liveCurrentDocMatchCount: 0), 10)
    }

    private func makeContext(counts: [Int]) -> SearchContext {
        let docs = counts.enumerated().map { index, count in
            SearchContext.DocEntry(summary: makeSummary(name: "doc\(index)"), matchCount: count)
        }
        return SearchContext(term: "x", docs: docs, startDocIndex: 0)
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
