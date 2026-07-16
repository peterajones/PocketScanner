import XCTest
@testable import DocumentScanner

@MainActor
final class GenerationGuardTests: XCTestCase {

    func test_latestTokenIsCurrent() {
        let g = GenerationGuard()
        _ = g.begin()
        let latest = g.begin()
        XCTAssertTrue(g.isCurrent(latest))
    }

    func test_priorTokenIsStaleAfterNewerBegin() {
        // Two overlapping iCloud updates: the OLDER result must be discarded so
        // a slow, stale build can't overwrite the newer summaries.
        let g = GenerationGuard()
        let older = g.begin()
        let newer = g.begin()
        XCTAssertFalse(g.isCurrent(older), "older token must be stale once a newer update starts")
        XCTAssertTrue(g.isCurrent(newer))
    }
}
