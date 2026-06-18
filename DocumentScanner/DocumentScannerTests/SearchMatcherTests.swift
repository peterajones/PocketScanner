import XCTest
@testable import DocumentScanner

final class SearchMatcherTests: XCTestCase {

    // Root is /tmp/docs; one folder /tmp/docs/Receipts.
    private let root = URL(fileURLWithPath: "/tmp/docs/Lease.pdf")          // root doc
    private let rootB = URL(fileURLWithPath: "/tmp/docs/Insurance.pdf")     // root doc
    private let inFolder = URL(fileURLWithPath: "/tmp/docs/Receipts/Costco.pdf")
    private let folderURL = URL(fileURLWithPath: "/tmp/docs/Receipts")

    private func summary(_ url: URL, name: String, ocr: String = "") -> DocumentSummary {
        DocumentSummary(url: url, displayName: name,
                        createdAt: Date(timeIntervalSince1970: 0),
                        pageCount: 1, ocrSnippet: ocr, isCorrupt: false)
    }

    private var all: [DocumentSummary] {
        [summary(root, name: "Lease", ocr: "rent montreal"),
         summary(rootB, name: "Insurance", ocr: "policy montreal"),
         summary(inFolder, name: "Costco", ocr: "groceries montreal")]
    }

    func test_libraryScope_includesDocsInsideFolders() {
        let result = SearchMatcher.matches(term: "montreal", in: all, scope: .library)
        XCTAssertEqual(Set(result.map(\.displayName)), ["Lease", "Insurance", "Costco"])
    }

    func test_folderScope_returnsOnlyThatFoldersDocs() {
        let result = SearchMatcher.matches(term: "montreal", in: all, scope: .folder(folderURL))
        XCTAssertEqual(result.map(\.displayName), ["Costco"])
    }

    func test_matchesDisplayName_caseInsensitive() {
        let result = SearchMatcher.matches(term: "LEASE", in: all, scope: .library)
        XCTAssertEqual(result.map(\.displayName), ["Lease"])
    }

    func test_matchesOcrSnippet() {
        let result = SearchMatcher.matches(term: "groceries", in: all, scope: .library)
        XCTAssertEqual(result.map(\.displayName), ["Costco"])
    }

    func test_emptyTerm_returnsEverythingInScope_unfiltered() {
        XCTAssertEqual(SearchMatcher.matches(term: "", in: all, scope: .library).count, 3)
        XCTAssertEqual(SearchMatcher.matches(term: "", in: all, scope: .folder(folderURL)).map(\.displayName), ["Costco"])
    }

    func test_noMatch_returnsEmpty() {
        XCTAssertTrue(SearchMatcher.matches(term: "xyzzy", in: all, scope: .library).isEmpty)
    }
}
