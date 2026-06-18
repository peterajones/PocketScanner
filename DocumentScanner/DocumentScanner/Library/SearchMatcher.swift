import Foundation

/// Where a search ran — drives which documents are candidates.
/// `.library` spans every document; `.folder` is limited to the docs whose
/// parent directory is that folder.
enum SearchScope: Hashable {
    case library
    case folder(URL)
}

/// Single source of truth for "which documents match this term in this scope".
/// Pure (operates on already-loaded `DocumentSummary` metadata — `displayName`
/// and `ocrSnippet`, the latter being the doc's full extracted text), so both
/// the results list and the viewer's `SearchContext` candidate set agree.
enum SearchMatcher {
    static func matches(
        term: String,
        in summaries: [DocumentSummary],
        scope: SearchScope
    ) -> [DocumentSummary] {
        let scoped: [DocumentSummary]
        switch scope {
        case .library:
            scoped = summaries
        case .folder(let folderURL):
            let folderPath = folderURL.standardizedFileURL.path
            scoped = summaries.filter {
                $0.url.deletingLastPathComponent().standardizedFileURL.path == folderPath
            }
        }

        let needle = term.lowercased()
        guard !needle.isEmpty else { return scoped }
        return scoped.filter {
            $0.displayName.lowercased().contains(needle)
            || $0.ocrSnippet.lowercased().contains(needle)
        }
    }
}
