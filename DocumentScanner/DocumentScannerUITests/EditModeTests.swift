import XCTest

final class EditModeTests: XCTestCase {

    @MainActor
    func test_editMode_addAndDeletePage() async throws {
        let app = TestHelpers.launchedApp()

        // Camera permission may prompt on the first scanner present — accept it.
        let permissionMonitor = addUIInterruptionMonitor(withDescription: "Camera permission") { alert in
            for label in ["Allow", "OK", "Continue", "Allow While Using App"] {
                if alert.buttons[label].exists {
                    alert.buttons[label].tap()
                    return true
                }
            }
            return false
        }
        defer { removeUIInterruptionMonitor(permissionMonitor) }

        // --- 1. Create initial 1-page document.
        app.buttons["Library.AddButton"].waitForElementOrFail()
        app.buttons["Library.AddButton"].tap()
        app.tap() // wake interruption monitor if needed

        app.buttons["StubScanner.Finish"].waitForElementOrFail()
        app.buttons["StubScanner.Finish"].tap()

        let nameField = app.textFields["NameSheet.NameField"]
        nameField.waitForElementOrFail()
        nameField.tap()
        if let existing = nameField.value as? String, !existing.isEmpty {
            nameField.press(forDuration: 1.0)
            if app.menuItems["Select All"].waitForExistence(timeout: 2) {
                app.menuItems["Select All"].tap()
            }
        }
        nameField.typeText("EditModeDoc")
        app.buttons["NameSheet.Save"].tap()

        // --- 2. Open the document.
        let row = app.descendants(matching: .any)
            .matching(identifier: "Library.Row.EditModeDoc").firstMatch
        row.waitForElementOrFail()
        row.tap()

        // --- 3. Enter edit mode.
        let editToggle = app.buttons["Viewer.EditToggle"]
        editToggle.waitForElementOrFail()
        editToggle.tap()

        // --- 4. Add a second page via the + tile.
        let addPages = app.buttons["EditMode.AddPages"]
        addPages.waitForElementOrFail()
        addPages.tap()
        app.tap() // wake interruption monitor if needed

        app.buttons["StubScanner.Finish"].waitForElementOrFail()
        app.buttons["StubScanner.Finish"].tap()

        // --- 5. Both thumbnails exist.
        let thumb0 = app.descendants(matching: .any)
            .matching(identifier: "EditMode.Thumbnail.0").firstMatch
        let thumb1 = app.descendants(matching: .any)
            .matching(identifier: "EditMode.Thumbnail.1").firstMatch
        XCTAssertTrue(thumb0.waitForExistence(timeout: 10),
                      "expected first thumbnail")
        XCTAssertTrue(thumb1.waitForExistence(timeout: 10),
                      "expected second thumbnail after Add Pages")

        // --- 6. Long-press second thumbnail; pick Delete page.
        thumb1.press(forDuration: 1.0)
        let deleteButton = app.buttons["Delete page"]
        if !deleteButton.waitForExistence(timeout: 4) {
            // Fall back: context-menu items may surface as menuItems on iOS.
            XCTAssertTrue(app.menuItems["Delete page"].waitForExistence(timeout: 4),
                          "expected Delete page item in context menu")
            app.menuItems["Delete page"].tap()
        } else {
            deleteButton.tap()
        }

        // --- 7. Second thumbnail is gone.
        // After delete, the second thumbnail should no longer exist; the first
        // still does.
        let thumb1Gone = !app.descendants(matching: .any)
            .matching(identifier: "EditMode.Thumbnail.1").firstMatch
            .waitForExistence(timeout: 3)
        XCTAssertTrue(thumb1Gone,
                      "expected second thumbnail to be removed after delete")
        XCTAssertTrue(app.descendants(matching: .any)
            .matching(identifier: "EditMode.Thumbnail.0").firstMatch.exists,
                      "expected first thumbnail still present")

        // --- 8. Exit Edit mode.
        editToggle.tap()
    }
}
