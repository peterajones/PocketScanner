import XCTest
@testable import DocumentScanner

@MainActor
final class ScanDocumentIntentTests: XCTestCase {

    func test_perform_requestsInstantScan() async throws {
        InstantScanCoordinator.shared.resetForTesting()
        defer { InstantScanCoordinator.shared.resetForTesting() }

        _ = try await ScanDocumentIntent().perform()

        XCTAssertEqual(InstantScanCoordinator.shared.phase, .requested)
    }
}
