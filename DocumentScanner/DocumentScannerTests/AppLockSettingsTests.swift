import XCTest
import SwiftUI
@testable import DocumentScanner

@MainActor
final class AppLockSettingsTests: XCTestCase {

    // MARK: - Scene-phase handling (#6: don't relock on transient .inactive)

    func test_scenePhaseChange_toInactive_doesNotRecordBackground() {
        // Control Center, the incoming-call banner, and the app switcher all
        // fire .inactive WITHOUT the user leaving the app. Recording the
        // re-lock timestamp there would relock them after a >30s peek.
        let settings = AppLockSettings(isEnabled: true, backgroundedAt: nil)
        settings.scenePhaseChanged(to: .inactive)
        XCTAssertNil(settings.recordedBackgroundedAt)
    }

    func test_scenePhaseChange_toBackground_recordsBackground() {
        let settings = AppLockSettings(isEnabled: true, backgroundedAt: nil)
        settings.scenePhaseChanged(to: .background)
        XCTAssertNotNil(settings.recordedBackgroundedAt)
    }

    func test_scenePhaseChange_toActive_relocksWhenElapsedThenClears() {
        let now = Date()
        let settings = AppLockSettings(isEnabled: true, backgroundedAt: now.addingTimeInterval(-31))
        settings.unlock()
        settings.scenePhaseChanged(to: .active, now: now)
        XCTAssertTrue(settings.isLocked)
        XCTAssertNil(settings.recordedBackgroundedAt)
    }

    func test_scenePhaseChange_toActive_doesNotRelockWhenRecent() {
        let now = Date()
        let settings = AppLockSettings(isEnabled: true, backgroundedAt: now.addingTimeInterval(-10))
        settings.unlock()
        settings.scenePhaseChanged(to: .active, now: now)
        XCTAssertFalse(settings.isLocked)
        XCTAssertNil(settings.recordedBackgroundedAt)
    }

    // MARK: - Threshold boundary (#4: pin the exact 30s `>` semantics)

    func test_shouldRelock_falseAtExactThreshold() {
        let now = Date()
        let settings = AppLockSettings(isEnabled: true, backgroundedAt: now.addingTimeInterval(-30))
        XCTAssertFalse(settings.shouldRelock(now: now))
    }

    func test_shouldRelock_trueJustOverThreshold() {
        let now = Date()
        let settings = AppLockSettings(isEnabled: true, backgroundedAt: now.addingTimeInterval(-30.001))
        XCTAssertTrue(settings.shouldRelock(now: now))
    }

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
