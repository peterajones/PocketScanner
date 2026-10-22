import XCTest
@testable import DocumentScanner

@MainActor
final class InstantDeleteTests: XCTestCase {

    private func summary(_ path: String) -> DocumentSummary {
        DocumentSummary(url: URL(fileURLWithPath: path), displayName: path,
                        createdAt: Date(), pageCount: 1, ocrSnippet: "", isCorrupt: false)
    }

    // MARK: - PendingDeletions (the iCloud store's reconciliation)

    func test_pending_coversTheDocumentAndEverythingInADeletedFolder() {
        var pending = PendingDeletions()
        pending.add(URL(fileURLWithPath: "/lib/Receipts", isDirectory: true))
        pending.add(URL(fileURLWithPath: "/lib/Lease.pdf"))

        XCTAssertTrue(pending.covers(URL(fileURLWithPath: "/lib/Lease.pdf")))
        XCTAssertTrue(pending.covers(URL(fileURLWithPath: "/lib/Receipts/Costco.pdf")))
        XCTAssertTrue(pending.covers(URL(fileURLWithPath: "/lib/Receipts/2025/Tax.pdf")))
        XCTAssertFalse(pending.covers(URL(fileURLWithPath: "/lib/Receipts 2/Other.pdf")),
                       "a sibling whose name starts the same is not inside the folder")
        XCTAssertFalse(pending.covers(URL(fileURLWithPath: "/lib/Lease 2.pdf")))
    }

    /// The bug this guards: a query update already in flight when the user deleted
    /// still lists the file, and without the filter the row would flash back.
    func test_pending_hidesADeletedDocumentFromAStaleUpdate() {
        var pending = PendingDeletions()
        pending.add(URL(fileURLWithPath: "/lib/Lease.pdf"))
        let stale = [summary("/lib/Lease.pdf"), summary("/lib/Recipe.pdf")]

        XCTAssertEqual(pending.filter(stale, exists: { _ in false }).map(\.url.path), ["/lib/Recipe.pdf"])
    }

    func test_pending_isKeptWhileTheQueryStillListsIt_andDroppedOnceItIsGone() {
        var pending = PendingDeletions()
        pending.add(URL(fileURLWithPath: "/lib/Lease.pdf"))

        pending.prune(keepingThoseStillIn: [URL(fileURLWithPath: "/lib/Lease.pdf")])
        XCTAssertTrue(pending.covers(URL(fileURLWithPath: "/lib/Lease.pdf")))

        pending.prune(keepingThoseStillIn: [URL(fileURLWithPath: "/lib/Recipe.pdf")])
        XCTAssertFalse(pending.covers(URL(fileURLWithPath: "/lib/Lease.pdf")),
                       "a re-created file with the same name must show up again")
    }

    func test_pending_folderIsKeptWhileAnyDocumentInsideIsStillListed() {
        var pending = PendingDeletions()
        pending.add(URL(fileURLWithPath: "/lib/Receipts", isDirectory: true))

        pending.prune(keepingThoseStillIn: [URL(fileURLWithPath: "/lib/Receipts/Costco.pdf")])
        XCTAssertTrue(pending.covers(URL(fileURLWithPath: "/lib/Receipts/Costco.pdf")))

        pending.prune(keepingThoseStillIn: [])
        XCTAssertFalse(pending.covers(URL(fileURLWithPath: "/lib/Receipts/Costco.pdf")))
    }

    /// Deleting "Scan.pdf" and importing a new "Scan.pdf" seconds later: the query keeps
    /// listing the name, so only the file being back on disk can tell them apart.
    func test_pending_doesNotHideAFileRecreatedAtTheSamePath() {
        var pending = PendingDeletions()
        pending.add(URL(fileURLWithPath: "/lib/Scan.pdf"))
        let listed = [summary("/lib/Scan.pdf")]

        XCTAssertEqual(pending.filter(listed, exists: { _ in true }).count, 1)
        XCTAssertEqual(pending.filter(listed, exists: { _ in false }).count, 0)
    }

    func test_pending_expiresAfterItsLifetime_evenIfStillListed() {
        var pending = PendingDeletions()
        let deletedAt = Date(timeIntervalSince1970: 1_000)
        pending.add(URL(fileURLWithPath: "/lib/Lease.pdf"), at: deletedAt)
        let listed = [URL(fileURLWithPath: "/lib/Lease.pdf")]

        pending.prune(keepingThoseStillIn: listed, now: deletedAt + PendingDeletions.lifetime - 1)
        XCTAssertTrue(pending.covers(URL(fileURLWithPath: "/lib/Lease.pdf")))

        pending.prune(keepingThoseStillIn: listed, now: deletedAt + PendingDeletions.lifetime + 1)
        XCTAssertFalse(pending.covers(URL(fileURLWithPath: "/lib/Lease.pdf")))
    }

    // MARK: - Local store

    func test_inMemoryStore_didDelete_removesTheDocumentAtOnce() {
        let store = InMemoryLibraryStore()
        store.append(summary("/lib/Lease.pdf"))
        store.append(summary("/lib/Recipe.pdf"))

        store.didDelete(at: URL(fileURLWithPath: "/lib/Lease.pdf"))

        XCTAssertEqual(store.summaries.map(\.url.path), ["/lib/Recipe.pdf"])
    }

    func test_inMemoryStore_didDelete_ofAFolder_removesItsDocuments() {
        let store = InMemoryLibraryStore()
        store.append(summary("/lib/Receipts/Costco.pdf"))
        store.append(summary("/lib/Receipts/2025/Tax.pdf"))
        store.append(summary("/lib/Lease.pdf"))

        store.didDelete(at: URL(fileURLWithPath: "/lib/Receipts", isDirectory: true))

        XCTAssertEqual(store.summaries.map(\.url.path), ["/lib/Lease.pdf"])
    }
}
