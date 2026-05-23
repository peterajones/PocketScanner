import XCTest
@testable import DocumentScanner

@MainActor
final class AppLockSettingsTests: XCTestCase {

    func test_shouldRelock_falseWhenLockDisabled() {
        let settings = AppLockSettings(isEnabled: false, backgroundedAt: Date().addingTimeInterval(-9999))
        XCTAssertFalse(settings.shouldRelock(now: Date()))
    }

    func test_shouldRelock_falseWhenNeverBackgrounded() {
        let settings = AppLockSettings(isEnabled: true, backgroundedAt: nil)
        XCTAssertFalse(settings.shouldRelock(now: Date()))
    }

    func test_shouldRelock_falseWhenBackgroundedRecently() {
        let now = Date()
        let settings = AppLockSettings(isEnabled: true, backgroundedAt: now.addingTimeInterval(-10))
        XCTAssertFalse(settings.shouldRelock(now: now))
    }

    func test_shouldRelock_trueWhenBackgroundedLongerThanThreshold() {
        let now = Date()
        let settings = AppLockSettings(isEnabled: true, backgroundedAt: now.addingTimeInterval(-31))
        XCTAssertTrue(settings.shouldRelock(now: now))
    }

    func test_recordBackground_setsTimestamp() {
        let settings = AppLockSettings(isEnabled: true, backgroundedAt: nil)
        let before = Date()
        settings.recordBackground()
        XCTAssertNotNil(settings.recordedBackgroundedAt)
        XCTAssertGreaterThanOrEqual(settings.recordedBackgroundedAt!, before)
    }

    func test_clearBackground_nilsTimestamp() {
        let settings = AppLockSettings(isEnabled: true, backgroundedAt: Date())
        settings.clearBackground()
        XCTAssertNil(settings.recordedBackgroundedAt)
    }

    func test_lock_setsLocked() {
        let settings = AppLockSettings(isEnabled: true, backgroundedAt: nil)
        settings.lock()
        XCTAssertTrue(settings.isLocked)
    }

    func test_unlock_clearsLocked() {
        let settings = AppLockSettings(isEnabled: true, backgroundedAt: nil)
        settings.lock()
        settings.unlock()
        XCTAssertFalse(settings.isLocked)
    }
}
