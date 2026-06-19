import XCTest
@testable import DocumentScanner

final class TipTests: XCTestCase {

    func test_all_isNonEmpty() {
        XCTAssertFalse(Tip.all.isEmpty)
    }

    func test_all_haveUniqueIDs() {
        XCTAssertEqual(Set(Tip.all.map(\.id)).count, Tip.all.count, "tip ids must be unique")
    }

    func test_all_haveNonEmptyTitleAndBody() {
        for tip in Tip.all {
            XCTAssertFalse(tip.title.isEmpty, "tip \(tip.id) has an empty title")
            XCTAssertFalse(tip.body.isEmpty, "tip \(tip.id) has an empty body")
        }
    }

    func test_highlightsTip_isPresent() {
        XCTAssertTrue(Tip.all.contains { $0.id == "highlights" },
                      "the highlights/handwriting note is the reason this screen exists")
    }
}
