import XCTest
@testable import DocumentScanner

final class DateStampFormatTests: XCTestCase {

    /// Build a date at noon in the current calendar so formatting (which uses the
    /// current time zone) can't roll it to an adjacent day.
    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var c = DateComponents(); c.year = y; c.month = m; c.day = d; c.hour = 12
        return Calendar.current.date(from: c)!
    }

    func test_allFormats_knownDate() {
        let d = date(2026, 7, 9)
        XCTAssertEqual(DateStampFormat.iso.string(for: d), "2026-07-09")
        XCTAssertEqual(DateStampFormat.numericUS.string(for: d), "07/09/2026")
        XCTAssertEqual(DateStampFormat.numericIntl.string(for: d), "09/07/2026")
        XCTAssertEqual(DateStampFormat.longUS.string(for: d), "July 9, 2026")
        XCTAssertEqual(DateStampFormat.longIntl.string(for: d), "9 July 2026")
    }

    func test_singleDigitDayAndMonth_padding() {
        let d = date(2026, 3, 5)
        XCTAssertEqual(DateStampFormat.iso.string(for: d), "2026-03-05")       // zero-padded
        XCTAssertEqual(DateStampFormat.numericUS.string(for: d), "03/05/2026") // zero-padded
        XCTAssertEqual(DateStampFormat.longUS.string(for: d), "March 5, 2026") // day NOT padded
        XCTAssertEqual(DateStampFormat.longIntl.string(for: d), "5 March 2026")
    }

    func test_caseIterable_hasFiveStableOrder() {
        XCTAssertEqual(DateStampFormat.allCases,
                       [.iso, .numericUS, .numericIntl, .longUS, .longIntl])
    }
}
