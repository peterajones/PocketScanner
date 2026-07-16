import Foundation
import Observation

@MainActor
@Observable
final class MetadataQueryLibraryStore: NSObject, LibraryStoring {
    private(set) var summaries: [DocumentSummary] = []

    /// Discards stale results when rapid iCloud notifications spawn overlapping
    /// builds that finish out of order (see GenerationGuard).
    private let updateGuard = GenerationGuard()

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
        let token = updateGuard.begin()
        Task {
            let built = await Task.detached(priority: .userInitiated) {
                urls.map { DocumentSummary.fromFile(at: $0) }
                    .sorted(by: { $0.createdAt > $1.createdAt })
            }.value
            // A newer notification may have started (and possibly already
            // finished) while this build ran. Only the latest may publish, so a
            // slow stale snapshot can't clobber fresher summaries.
            guard updateGuard.isCurrent(token) else { return }
            self.summaries = built
            self.query.enableUpdates()
        }
    }
}
