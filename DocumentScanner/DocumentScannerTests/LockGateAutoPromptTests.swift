import XCTest
import SwiftUI
@testable import DocumentScanner

final class LockGateAutoPromptTests: XCTestCase {

    func test_autoPrompt_whenLockedAndIdle() {
        XCTAssertTrue(LockGate<EmptyView>.shouldAutoPrompt(isLocked: true, instantScanBusy: false))
    }

    func test_autoPrompt_suppressedWhileInstantScanBusy() {
        XCTAssertFalse(LockGate<EmptyView>.shouldAutoPrompt(isLocked: true, instantScanBusy: true))
    }

    func test_autoPrompt_neverWhenUnlocked() {
        XCTAssertFalse(LockGate<EmptyView>.shouldAutoPrompt(isLocked: false, instantScanBusy: false))
    }
}
