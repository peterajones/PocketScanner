import Foundation
import Observation

protocol LibraryStoring: AnyObject {
    var summaries: [DocumentSummary] { get async }
    func refresh() async
}

/// Testable in-memory store. The real (NSMetadataQuery-backed) store lands in Task 10.
@Observable
final class InMemoryLibraryStore: LibraryStoring {
    private(set) var summaries: [DocumentSummary] = []

    func append(_ summary: DocumentSummary) async {
        summaries.append(summary)
        summaries.sort { $0.createdAt > $1.createdAt }
    }

    func refresh() async { /* no-op for in-memory */ }
}
