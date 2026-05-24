import XCTest

/// Common XCUITest setup helpers.
enum TestHelpers {

    /// Launch the app in hermetic UI-test mode.
    @MainActor
    static func launchedApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestMode"]
        app.launch()
        return app
    }
}

extension XCUIElement {
    /// Fail the current test if the element doesn't appear within the timeout.
    func waitForElementOrFail(timeout: TimeInterval = 8,
                              file: StaticString = #filePath,
                              line: UInt = #line) {
        if !waitForExistence(timeout: timeout) {
            XCTFail("element \(self) not found within \(timeout)s",
                    file: file, line: line)
        }
    }
}
