import XCTest
import UIKit
@testable import DocumentScanner

@MainActor
final class InstantScanCoordinatorTests: XCTestCase {

    let url = URL(fileURLWithPath: "/tmp/a.pdf")

    func test_request_fromIdle_becomesRequested() {
        let c = InstantScanCoordinator()
        c.request()
        XCTAssertEqual(c.phase, .requested)
        XCTAssertTrue(c.isBusy)
    }

    func test_request_ignoredWhileBusy() {
        let c = InstantScanCoordinator()
        c.request()
        _ = c.beginCapture()
        c.request()
        XCTAssertEqual(c.phase, .capturing)
    }

    func test_request_fromSaved_startsNewScan() {
        let c = InstantScanCoordinator()
        c.request()
        _ = c.beginCapture()
        c.beginSaving(images: [UIImage()])
        c.saveSucceeded(url: url)
        c.request()
        XCTAssertEqual(c.phase, .requested)
        XCTAssertNil(c.documentToOpen(isLocked: false))
    }

    func test_beginCapture_onlyFromRequested() {
        let c = InstantScanCoordinator()
        XCTAssertFalse(c.beginCapture())
        c.request()
        XCTAssertTrue(c.beginCapture())
    }

    func test_cancel_returnsToIdle() {
        let c = InstantScanCoordinator()
        c.request()
        _ = c.beginCapture()
        c.cancel()
        XCTAssertEqual(c.phase, .idle)
        XCTAssertFalse(c.isBusy)
    }

    func test_failure_returnsToCapturedWithImagesKept() {
        let c = InstantScanCoordinator()
        c.request()
        _ = c.beginCapture()
        c.beginSaving(images: [UIImage(), UIImage()])
        c.saveFailed()
        XCTAssertEqual(c.phase, .capturing)
        XCTAssertEqual(c.capturedImages.count, 2)
    }

    func test_documentToOpen_heldUntilUnlocked() {
        let c = InstantScanCoordinator()
        c.request()
        _ = c.beginCapture()
        c.beginSaving(images: [UIImage()])
        c.saveSucceeded(url: url)
        XCTAssertNil(c.documentToOpen(isLocked: true))
        XCTAssertFalse(c.isBusy)
        XCTAssertEqual(c.documentToOpen(isLocked: false), url)
        c.markOpened()
        XCTAssertEqual(c.phase, .idle)
        XCTAssertTrue(c.capturedImages.isEmpty)
    }
}
