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
        // Long format is locale-natural; pin English explicitly.
        XCTAssertEqual(DateStampFormat.long.string(for: d, locale: Locale(identifier: "en_US")),
                       "July 9, 2026")
    }

    func test_singleDigitDayAndMonth_padding() {
        let d = date(2026, 3, 5)
        XCTAssertEqual(DateStampFormat.iso.string(for: d), "2026-03-05")       // zero-padded
        XCTAssertEqual(DateStampFormat.numericUS.string(for: d), "03/05/2026") // zero-padded
        XCTAssertEqual(DateStampFormat.long.string(for: d, locale: Locale(identifier: "en_US")),
                       "March 5, 2026")                                        // day NOT padded
    }

    func test_caseIterable_hasFourStableOrder() {
        XCTAssertEqual(DateStampFormat.allCases,
                       [.iso, .numericUS, .numericIntl, .long])
    }

    func test_long_rawValueBackCompat() {
        // Old saved preference "longUS" must still resolve to the long format.
        XCTAssertEqual(DateStampFormat(rawValue: "longUS"), .long)
    }

    // Long formats localize month names to the given locale (v3.0); numeric/ISO
    // stay region-neutral regardless of locale.

    func test_longFormat_usesLocaleMonthNameAndParticles() {
        let d = date(2026, 7, 9)
        let es = DateStampFormat.long.string(for: d, locale: Locale(identifier: "es_ES"))
        XCTAssertTrue(es.localizedCaseInsensitiveContains("julio"),
                      "es long format should use the Spanish month, got \(es)")
        XCTAssertTrue(es.contains(" de "),
                      "es long format should include the natural 'de' particles, got \(es)")
        let fr = DateStampFormat.long.string(for: d, locale: Locale(identifier: "fr_FR"))
        XCTAssertTrue(fr.localizedCaseInsensitiveContains("juillet"),
                      "fr long format should use the French month, got \(fr)")
    }

    func test_isoAndNumeric_stayRegionNeutral_regardlessOfLocale() {
        let d = date(2026, 7, 9)
        XCTAssertEqual(DateStampFormat.iso.string(for: d, locale: Locale(identifier: "es_ES")), "2026-07-09")
        XCTAssertEqual(DateStampFormat.numericUS.string(for: d, locale: Locale(identifier: "fr_FR")), "07/09/2026")
    }
}
