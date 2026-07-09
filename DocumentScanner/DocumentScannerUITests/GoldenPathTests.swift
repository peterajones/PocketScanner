import XCTest

final class GoldenPathTests: XCTestCase {

    @MainActor
    func test_scan_save_viewLibrary_openViewer() async throws {
        let app = TestHelpers.launchedApp()

        // In -UITestMode the scanner is stubbed and CameraPermission reports
        // authorized, so no system permission dialog appears — no interruption
        // monitor needed.

        // 1. Empty state visible.
        XCTAssertTrue(app.staticTexts["No documents yet"].waitForExistence(timeout: 8),
                      "expected empty-state title on first launch")

        // 2. Tap + button.
        let addButton = app.buttons["Library.AddButton"]
        addButton.waitForElementOrFail()
        addButton.tap()
        // v2.4+ the library + is a menu (Scan Document / New Folder) —
        // choose Scan Document to launch the (stub) scanner.
        app.buttons["Scan Document"].waitForElementOrFail()
        app.buttons["Scan Document"].tap()

        // 3. Stub scanner appears; tap Finish.
        let finishButton = app.buttons["StubScanner.Finish"]
        finishButton.waitForElementOrFail()
        finishButton.tap()

        // 4. Name sheet appears. Replace default contents with a known string.
        let nameField = app.textFields["NameSheet.NameField"]
        nameField.waitForElementOrFail()
        nameField.tap()
        // Clear: select all then type.
        if let existing = nameField.value as? String, !existing.isEmpty {
            nameField.press(forDuration: 1.0)
            if app.menuItems["Select All"].waitForExistence(timeout: 2) {
                app.menuItems["Select All"].tap()
            }
        }
        nameField.typeText("UITestDocument")

        // 5. Save.
        app.buttons["NameSheet.Save"].tap()

        // 6. New row appears in library. SwiftUI may expose the row as a
        // cell, other-element, or static text depending on accessibility
        // wiring, so look across the major element types.
        let rowMatch = app.descendants(matching: .any)
            .matching(identifier: "Library.Row.UITestDocument").firstMatch
        XCTAssertTrue(rowMatch.waitForExistence(timeout: 8),
                      "expected library row for UITestDocument to appear")

        // 7. Tap row to open viewer.
        rowMatch.tap()

        // 8. Viewer is presented (Edit toggle visible in bottom bar).
        app.buttons["Viewer.EditToggle"].waitForElementOrFail()

        // 9. Back to library.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(rowMatch.waitForExistence(timeout: 8),
                      "expected to return to library with row still present")
    }
}
