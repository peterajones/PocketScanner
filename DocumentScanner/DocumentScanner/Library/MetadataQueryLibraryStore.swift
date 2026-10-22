import Foundation
import Observation

@MainActor
@Observable
final class MetadataQueryLibraryStore: NSObject, LibraryStoring {
    private(set) var summaries: [DocumentSummary] = []
    private var pendingDeletions = PendingDeletions()

    private let query: NSMetadataQuery = {
        let q = NSMetadataQuery()
        q.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        q.predicate = NSPredicate(format: "%K LIKE '*.pdf'", NSMetadataItemFSNameKey)
        q.sortDescriptors = [NSSortDescriptor(key: NSMetadataItemFSCreationDateKey, ascending: false)]
        return q
    }()

    override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self, selector: #selector(queryDidUpdate(_:)),
            name: .NSMetadataQueryDidFinishGathering, object: query
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(queryDidUpdate(_:)),
            name: .NSMetadataQueryDidUpdate, object: query
        )
        query.start()
    }

    deinit {
        query.stop()
        NotificationCenter.default.removeObserver(self)
    }

    func didDelete(at url: URL) {
        pendingDeletions.add(url)
        summaries = pendingDeletions.filter(summaries)
    }

    func refresh() {
        query.disableUpdates()
        query.enableUpdates()
    }

    @objc private func queryDidUpdate(_ note: Notification) {
        query.disableUpdates()

        let items = (query.results as? [NSMetadataItem]) ?? []
        let urls = items.compactMap { $0.value(forAttribute: NSMetadataItemURLKey) as? URL }

        // `fromFile` opens each PDF via mmap to read page count + OCR text.
        // When iCloud hasn't fully synced, that mmap can block waiting for the
        // file to download. Doing this on the main thread freezes the launch.
        Task {
            let built = await Task.detached(priority: .userInitiated) {
                urls.map { DocumentSummary.fromFile(at: $0) }
                    .sorted(by: { $0.createdAt > $1.createdAt })
            }.value
            // `urls` may predate a delete made while this update was being built;
            // the pending entry keeps that row hidden until the query drops it.
            self.pendingDeletions.prune(keepingThoseStillIn: urls)
            self.summaries = self.pendingDeletions.filter(built)
            self.query.enableUpdates()
        }
    }
}
