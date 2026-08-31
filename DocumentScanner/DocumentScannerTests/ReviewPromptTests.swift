import XCTest
@testable import DocumentScanner

final class ReviewPromptPolicyTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func shouldRequest(scans: Int,
                               lastDate: Date? = nil,
                               lastVersion: String? = nil,
                               version: String = "3.4") -> Bool {
        ReviewPromptPolicy.shouldRequest(scanCount: scans,
                                         lastPromptDate: lastDate,
                                         lastPromptVersion: lastVersion,
                                         currentVersion: version,
                                         now: now)
    }

    // MARK: - Scan threshold

    func test_doesNotAskBeforeMinimumScans() {
        for scans in 0..<ReviewPromptPolicy.minimumScans {
            XCTAssertFalse(shouldRequest(scans: scans), "asked after only \(scans) scan(s)")
        }
    }

    func test_asksAtMinimumScans() {
        XCTAssertTrue(shouldRequest(scans: ReviewPromptPolicy.minimumScans))
    }

    func test_asksAboveMinimumScans() {
        XCTAssertTrue(shouldRequest(scans: 50))
    }

    // MARK: - Interval

    func test_doesNotAskAgainInsideTheInterval() {
        let recent = now.addingTimeInterval(-ReviewPromptPolicy.minimumInterval + 1)
        XCTAssertFalse(shouldRequest(scans: 10, lastDate: recent, lastVersion: "3.3"))
    }

    func test_asksAgainAfterTheInterval() {
        let old = now.addingTimeInterval(-ReviewPromptPolicy.minimumInterval - 1)
        XCTAssertTrue(shouldRequest(scans: 10, lastDate: old, lastVersion: "3.3"))
    }

    // MARK: - Once per version

    func test_doesNotAskTwiceOnTheSameVersion() {
        let old = now.addingTimeInterval(-ReviewPromptPolicy.minimumInterval - 1)
        XCTAssertFalse(shouldRequest(scans: 10, lastDate: old, lastVersion: "3.4", version: "3.4"),
                       "interval elapsed, but this version already asked")
    }

    func test_versionGateDoesNotOverrideTheInterval() {
        // New version, but asked yesterday: the interval still wins. Without this, a
        // user updating often could be asked repeatedly in a single week.
        let yesterday = now.addingTimeInterval(-24 * 60 * 60)
        XCTAssertFalse(shouldRequest(scans: 10, lastDate: yesterday, lastVersion: "3.3", version: "3.4"))
    }

    // MARK: - First run

    func test_firstEverPromptNeedsNoHistory() {
        XCTAssertTrue(shouldRequest(scans: 3, lastDate: nil, lastVersion: nil))
    }
}

final class ReviewPromptTrackerTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "ReviewPromptTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    private func makeTracker(isEnabled: Bool = true) -> ReviewPromptTracker {
        ReviewPromptTracker(defaults: defaults, isEnabled: isEnabled)
    }

    func test_scanCountStartsAtZero() {
        XCTAssertEqual(makeTracker().scanCount, 0)
    }

    func test_recordingScansPersistsAcrossInstances() {
        let first = makeTracker()
        first.recordSuccess()
        first.recordSuccess()

        XCTAssertEqual(makeTracker().scanCount, 2, "scan count did not survive a fresh read")
    }

    func test_recordRequestedPersistsDateAndVersion() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        makeTracker().recordRequested(currentVersion: "3.4", now: now)

        let reloaded = makeTracker()
        XCTAssertEqual(reloaded.lastPromptVersion, "3.4")
        XCTAssertEqual(reloaded.lastPromptDate?.timeIntervalSince1970, now.timeIntervalSince1970)
    }

    func test_doesNotRequestUntilEnoughScans() {
        let tracker = makeTracker()
        tracker.recordSuccess()
        XCTAssertFalse(tracker.shouldRequest(currentVersion: "3.4"))
    }

    func test_requestsOnceEnoughScansRecorded() {
        let tracker = makeTracker()
        for _ in 0..<ReviewPromptPolicy.minimumScans { tracker.recordSuccess() }
        XCTAssertTrue(tracker.shouldRequest(currentVersion: "3.4"))
    }

    func test_doesNotRequestAgainAfterRecording() {
        let tracker = makeTracker()
        for _ in 0..<ReviewPromptPolicy.minimumScans { tracker.recordSuccess() }
        tracker.recordRequested(currentVersion: "3.4")

        XCTAssertFalse(tracker.shouldRequest(currentVersion: "3.4"),
                       "asked twice on the same version")
    }

    /// The guard that keeps a Debug-build rating sheet from landing on top of the UI
    /// suite mid-scan. In Debug, `requestReview()` ignores StoreKit throttling.
    func test_disabledTrackerNeverRequests() {
        let tracker = makeTracker(isEnabled: false)
        for _ in 0..<50 { tracker.recordSuccess() }
        XCTAssertFalse(tracker.shouldRequest(currentVersion: "3.4"))
    }

    func test_disabledTrackerStillCountsScans() {
        // Counting continues so that a user who happens to run a UI-test build isn't
        // permanently reset; only the asking is suppressed.
        let tracker = makeTracker(isEnabled: false)
        tracker.recordSuccess()
        XCTAssertEqual(tracker.scanCount, 1)
    }
}
