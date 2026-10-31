import XCTest
@testable import DocumentScanner

final class ContextualTipPolicyTests: XCTestCase {

    private func current(scans: Int = 0,
                         documents: Int = 0,
                         usedInstantScan: Bool = false,
                         dismissed: Set<ContextualTip> = []) -> ContextualTip? {
        ContextualTipPolicy.current(scanCount: scans,
                                    documentCount: documents,
                                    hasUsedInstantScan: usedInstantScan,
                                    dismissed: dismissed)
    }

    func test_freshInstall_showsNothing() {
        XCTAssertNil(current())
    }

    func test_afterThreeScans_suggestsInstantScan() {
        XCTAssertNil(current(scans: 2))
        XCTAssertEqual(current(scans: 3), .instantScan)
    }

    func test_someoneAlreadyUsingInstantScan_isNotToldAboutIt() {
        XCTAssertNil(current(scans: 10, usedInstantScan: true))
    }

    func test_fiveDocuments_suggestsSearch() {
        XCTAssertNil(current(documents: 4))
        XCTAssertEqual(current(documents: 5), .search)
    }

    func test_onlyOneTipAtATime_instantScanFirst() {
        XCTAssertEqual(current(scans: 3, documents: 5), .instantScan)
    }

    func test_closingATip_movesOnToTheNext() {
        XCTAssertEqual(current(scans: 3, documents: 5, dismissed: [.instantScan]), .search)
        XCTAssertEqual(current(scans: 3, documents: 5, dismissed: [.instantScan, .search]), .contextMenu)
    }

    func test_contextMenuTip_waitsForFiveDocuments() {
        XCTAssertNil(current(scans: 3, documents: 4, dismissed: [.instantScan]))
    }

    func test_everyTipClosed_showsNothing() {
        XCTAssertNil(current(scans: 3, documents: 5, dismissed: Set(ContextualTip.allCases)))
    }
}

final class ContextualTipTrackerTests: XCTestCase {

    private var defaults: UserDefaults!
    private let suite = "ContextualTipTrackerTests"

    override func setUp() {
        super.setUp()
        UserDefaults().removePersistentDomain(forName: suite)
        defaults = UserDefaults(suiteName: suite)
    }

    override func tearDown() {
        UserDefaults().removePersistentDomain(forName: suite)
        super.tearDown()
    }

    func test_instantScanUse_isRemembered() {
        ContextualTipTracker(defaults: defaults, isEnabled: true).recordInstantScanUsed()
        let reloaded = ContextualTipTracker(defaults: defaults, isEnabled: true)
        XCTAssertNil(reloaded.current(scanCount: 3, documentCount: 0),
                     "Instant Scan tip shown to someone who has used it")
    }

    func test_disabled_showsNothing() {
        let tracker = ContextualTipTracker(defaults: defaults, isEnabled: false)
        XCTAssertNil(tracker.current(scanCount: 10, documentCount: 10))
    }

    func test_enabled_followsThePolicy() {
        let tracker = ContextualTipTracker(defaults: defaults, isEnabled: true)
        XCTAssertEqual(tracker.current(scanCount: 3, documentCount: 0), .instantScan)
    }

    // A closed tip must be known the moment the library appears. TipKit's own record
    // loads after launch, so a card that asked TipKit at that point saw nothing closed,
    // picked a tip TipKit would not draw, and showed nothing at all (device check T4).
    func test_closedTips_areRememberedAcrossLaunches() {
        let tracker = ContextualTipTracker(defaults: defaults, isEnabled: true)
        tracker.recordDismissed(.instantScan)
        tracker.recordDismissed(.search)
        let relaunched = ContextualTipTracker(defaults: defaults, isEnabled: true)
        XCTAssertEqual(relaunched.current(scanCount: 3, documentCount: 5), .contextMenu)
    }

    func test_closingATip_movesOnToTheNextAtOnce() {
        let tracker = ContextualTipTracker(defaults: defaults, isEnabled: true)
        XCTAssertEqual(tracker.current(scanCount: 3, documentCount: 5), .instantScan)
        tracker.recordDismissed(.instantScan)
        XCTAssertEqual(tracker.current(scanCount: 3, documentCount: 5), .search)
    }

    #if DEBUG
    func test_deviceCheckReset_bringsEveryTipBack() {
        let tracker = ContextualTipTracker(defaults: defaults, isEnabled: true)
        tracker.recordInstantScanUsed()
        tracker.recordDismissed(.instantScan)
        tracker.resetForDeviceChecks()
        XCTAssertEqual(tracker.current(scanCount: 3, documentCount: 5), .instantScan)
    }
    #endif
}

final class ContextualTipContentTests: XCTestCase {

    // The cards reuse the Tips screen's translated text by id. A renamed id there
    // would otherwise leave a card with no text and no failing build.
    func test_everyContextualTip_hasTipsScreenText() {
        for tip in ContextualTip.allCases {
            XCTAssertNotNil(tip.entry, "\(tip) has no entry in Tip.all")
        }
        XCTAssertEqual(ContextualTip.instantScan.entry?.id, "instant-scan")
        XCTAssertEqual(ContextualTip.search.entry?.id, "search")
        XCTAssertEqual(ContextualTip.contextMenu.entry?.id, "context-menu")
    }
}
