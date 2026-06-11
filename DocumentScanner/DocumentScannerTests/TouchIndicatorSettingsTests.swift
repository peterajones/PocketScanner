import XCTest
@testable import DocumentScanner

final class TouchIndicatorSettingsTests: XCTestCase {
    func test_defaultsToDisabled() {
        XCTAssertFalse(TouchIndicatorSettings.defaultEnabled)
    }

    func test_usesStableStorageKey() {
        XCTAssertEqual(TouchIndicatorSettings.key, "touchIndicatorsEnabled")
    }
}
