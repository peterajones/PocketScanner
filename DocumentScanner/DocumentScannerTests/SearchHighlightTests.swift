import XCTest
import PDFKit
@testable import DocumentScanner

@MainActor
final class SearchHighlightTests: XCTestCase {

    func test_empty_hasNoCurrent() {
        let h = SearchHighlight(matches: [])
        XCTAssertNil(h.currentIndex)
        XCTAssertEqual(h.matchCount, 0)
    }

    func test_initialState_isFirstMatch() {
        let h = SearchHighlight(matches: makeMatches(3))
        XCTAssertEqual(h.currentIndex, 0)
        XCTAssertEqual(h.matchCount, 3)
    }

    func test_next_advancesByOne() {
        let h = SearchHighlight(matches: makeMatches(3))
        h.next()
        XCTAssertEqual(h.currentIndex, 1)
    }

    func test_next_wrapsAtEnd() {
        let h = SearchHighlight(matches: makeMatches(3))
        h.next(); h.next()
        h.next()
        XCTAssertEqual(h.currentIndex, 0)
    }

    func test_previous_decrementsByOne() {
        let h = SearchHighlight(matches: makeMatches(3))
        h.next()
        h.previous()
        XCTAssertEqual(h.currentIndex, 0)
    }

    func test_previous_wrapsAtStart() {
        let h = SearchHighlight(matches: makeMatches(3))
        h.previous()
        XCTAssertEqual(h.currentIndex, 2)
    }

    func test_nextOnSingleMatch_staysAtZero() {
        let h = SearchHighlight(matches: makeMatches(1))
        h.next()
        XCTAssertEqual(h.currentIndex, 0)
    }

    // MARK: - Helpers

    /// Returns `count` placeholder PDFSelections. We only need distinct
    /// PDFSelection objects for the index tests — the matched content
    /// doesn't matter here.
    private func makeMatches(_ count: Int) -> [PDFSelection] {
        let doc = PDFDocument()
        for _ in 0..<count {
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100))
            let img = renderer.image { _ in
                UIColor.white.setFill()
                UIRectFill(CGRect(x: 0, y: 0, width: 100, height: 100))
            }
            doc.insert(PDFPage(image: img)!, at: doc.pageCount)
        }
        return (0..<count).compactMap { _ in PDFSelection(document: doc) }
    }
}
