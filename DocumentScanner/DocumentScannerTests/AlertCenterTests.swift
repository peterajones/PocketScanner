import XCTest
@testable import DocumentScanner

@MainActor
final class AlertCenterTests: XCTestCase {

    func test_present_setsCurrent() {
        let center = AlertCenter()
        XCTAssertNil(center.current)
        center.present(AppAlert(title: "Hi", message: "Hello"))
        XCTAssertNotNil(center.current)
        XCTAssertEqual(center.current?.title, "Hi")
    }

    func test_dismiss_clearsCurrent() {
        let center = AlertCenter()
        center.present(AppAlert(title: "Hi", message: "Hello"))
        center.dismiss()
        XCTAssertNil(center.current)
    }

    func test_present_replacesExistingAlert() {
        let center = AlertCenter()
        center.present(AppAlert(title: "First", message: ""))
        center.present(AppAlert(title: "Second", message: ""))
        XCTAssertEqual(center.current?.title, "Second")
    }
}
