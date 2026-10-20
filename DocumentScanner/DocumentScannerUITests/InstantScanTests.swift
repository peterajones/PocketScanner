import XCTest

final class InstantScanTests: XCTestCase {

    @MainActor
    func test_instantScan_savesToMainLibrary_andOpensViewer() async throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestMode", "-InstantScanOnLaunch"]
        app.launch()

        // The stub scanner stands in for the camera, exactly as in GoldenPathTests.
        let finishButton = app.buttons["StubScanner.Finish"]
        finishButton.waitForElementOrFail()
        finishButton.tap()

        // Saved silently, then the viewer opens. The name sheet never appears.
        app.buttons["Viewer.DateButton"].waitForElementOrFail(timeout: 15)
        XCTAssertFalse(app.buttons["NameSheet.Save"].exists,
                       "instant scan must not show the name sheet")

        // Back to the library: exactly one document was saved.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let rows = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'Library.Row.'"))
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 8),
                      "expected the saved document in the library")
        // One row exposes several accessibility elements; its row button is the unit to count.
        let rowButtons = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'Library.Row.'"))
        let desc = rowButtons.allElementsBoundByIndex.map(\.identifier)
        XCTAssertEqual(rowButtons.count, 1, "\(desc)")
        XCTAssertFalse(app.buttons["NameSheet.Save"].exists)
    }
}
