import XCTest
@testable import DocumentScanner

final class DocumentSortTests: XCTestCase {

    private func doc(_ name: String, _ daysAgo: Int, _ pages: Int) -> DocumentSummary {
        DocumentSummary(
            url: URL(fileURLWithPath: "/docs/\(name).pdf"),
            displayName: name,
            createdAt: Date(timeIntervalSince1970: 1_000_000 - Double(daysAgo) * 86_400),
            pageCount: pages,
            ocrSnippet: "",
            isCorrupt: false
        )
    }

    func test_date_descending_isNewestFirst() {
        let a = doc("A", 0, 1)   // newest
        let b = doc("B", 5, 1)
        let c = doc("C", 10, 1)  // oldest
        let sort = DocumentSort(key: .date, ascending: false)
        XCTAssertEqual(sort.sorted([c, a, b]).map(\.displayName), ["A", "B", "C"])
    }

    func test_date_ascending_isOldestFirst() {
        let a = doc("A", 0, 1)
        let b = doc("B", 5, 1)
        let c = doc("C", 10, 1)
        let sort = DocumentSort(key: .date, ascending: true)
        XCTAssertEqual(sort.sorted([a, b, c]).map(\.displayName), ["C", "B", "A"])
    }

    func test_name_ascending_isCaseInsensitive() {
        let apple = doc("apple", 1, 1)
        let banana = doc("Banana", 2, 1)
        let cherry = doc("Cherry", 3, 1)
        let sort = DocumentSort(key: .name, ascending: true)
        XCTAssertEqual(sort.sorted([cherry, banana, apple]).map(\.displayName),
                       ["apple", "Banana", "Cherry"])
    }

    func test_name_descending() {
        let apple = doc("apple", 1, 1)
        let banana = doc("Banana", 2, 1)
        let sort = DocumentSort(key: .name, ascending: false)
        XCTAssertEqual(sort.sorted([apple, banana]).map(\.displayName),
                       ["Banana", "apple"])
    }

    func test_pageCount_descending_isMostFirst() {
        let a = doc("A", 1, 2)
        let b = doc("B", 2, 9)
        let c = doc("C", 3, 5)
        let sort = DocumentSort(key: .pageCount, ascending: false)
        XCTAssertEqual(sort.sorted([a, b, c]).map(\.displayName), ["B", "C", "A"])
    }

    func test_tieBreak_isStableByNameThenURL() {
        // Same date and page count → tie-break by case-insensitive name.
        let x = doc("Xerox", 5, 3)
        let a = doc("apple", 5, 3)
        let m = doc("Mango", 5, 3)
        let sort = DocumentSort(key: .date, ascending: false)
        // Primary (date) is equal for all, so order falls to name asc.
        XCTAssertEqual(sort.sorted([x, a, m]).map(\.displayName),
                       ["apple", "Mango", "Xerox"])
    }

    func test_defaultAscending_isTrueOnlyForName() {
        XCTAssertTrue(DocumentSort.defaultAscending(for: .name))
        XCTAssertFalse(DocumentSort.defaultAscending(for: .date))
        XCTAssertFalse(DocumentSort.defaultAscending(for: .pageCount))
    }

    func test_emptyAndSingle() {
        let sort = DocumentSort(key: .name, ascending: true)
        XCTAssertEqual(sort.sorted([]).count, 0)
        let only = doc("Solo", 1, 1)
        XCTAssertEqual(sort.sorted([only]).map(\.displayName), ["Solo"])
    }
}
