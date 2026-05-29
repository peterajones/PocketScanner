import Foundation
import Observation

protocol LibraryStoring: AnyObject {
    var summaries: [DocumentSummary] { get }
    func refresh()
}

/// Testable in-memory store. Originally `nonisolated` to opt out of the project's
/// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` default; that setting was removed
/// in commit d2782f8, so this can be `@Observable` again — needed so XCUITest
/// mode can use it as the library store behind LibraryView<Store: Observable>.
@Observable
final class InMemoryLibraryStore: LibraryStoring {
    private(set) var summaries: [DocumentSummary] = []

    /// Optional URL the UI-test wiring sets so `refresh()` can rescan a real
    /// temp directory the stub storage writes to. When `nil`, refresh is a
    /// no-op and callers are expected to drive state via `append`.
    var documentsURL: URL?

    func append(_ summary: DocumentSummary) {
        summaries.append(summary)
        summaries.sort { $0.createdAt > $1.createdAt }
    }

    func refresh() {
        guard let documentsURL else { return }
        // Recursive so docs moved into folders still appear in store.summaries.
        // LibraryView and FolderContentsView each filter to their own scope.
        var pdfs: [URL] = []
        if let enumerator = FileManager.default.enumerator(
            at: documentsURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) {
            for case let url as URL in enumerator where url.pathExtension.lowercased() == "pdf" {
                pdfs.append(url)
            }
        }
        let built = pdfs.map { DocumentSummary.fromFile(at: $0) }
        summaries = built.sorted { $0.createdAt > $1.createdAt }
    }
}
