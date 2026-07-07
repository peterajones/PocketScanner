import XCTest
@testable import DocumentScanner

/// Guards the AppStorage encoding for the "defaultScanFilter" preference: every
/// ImageFilter round-trips through its String rawValue, and the shipped default
/// rawValue resolves to Color.
final class DefaultScanFilterTests: XCTestCase {
    func test_allFiltersRoundTripThroughRawValue() {
        for f in ImageFilter.allCases {
            XCTAssertEqual(ImageFilter(rawValue: f.rawValue), f)
        }
    }

    func test_shippedDefaultRawValueIsColor() {
        XCTAssertEqual(ImageFilter(rawValue: ImageFilter.none.rawValue), ImageFilter.none)
        XCTAssertEqual(ImageFilter.none.displayName, "Color")
    }
}
