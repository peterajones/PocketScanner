/// Cross-document search state passed from `LibraryView` into
/// `DocumentViewerView`. Holds the search term and an ordered list of
/// docs that have matches; `startDocIndex` selects which doc the viewer
/// opens first.
///
/// Per-doc `[PDFSelection]` arrays are *not* stored here — they hold
/// strong references to their `PDFDocument`, and we don't want every
/// matching doc parsed in memory just to know the cross-doc counts.
/// The viewer recomputes selections lazily when it loads each doc.
struct SearchContext: Hashable {
    let term: String
    let docs: [DocEntry]
    /// Index into `docs` where the viewer should open. Caller is responsible
    /// for ensuring it's a valid index — out-of-bounds will trap when the
    /// viewer indexes into `docs[currentDocIndex]`.
    let startDocIndex: Int

    /// One entry per doc that has at least one match for the search term.
    struct DocEntry: Hashable {
        let summary: DocumentSummary
        /// Number of matches PDFKit's `findString` returned for the search
        /// term in this doc's PDF, computed at library search time.
        let matchCount: Int
    }

    /// Total matches across every doc in `docs`.
    var totalMatches: Int {
        docs.reduce(0) { $0 + $1.matchCount }
    }

    /// Total matches with the currently-open doc's LIVE match count substituted
    /// for its search-time snapshot. Page edits in the viewer change how many
    /// matches the open doc has; the other docs are unedited, so their snapshot
    /// counts stay correct. Falls back to the snapshot total if the index is
    /// out of range.
    func liveTotalMatches(currentDocIndex: Int, liveCurrentDocMatchCount: Int) -> Int {
        guard docs.indices.contains(currentDocIndex) else { return totalMatches }
        return totalMatches - docs[currentDocIndex].matchCount + liveCurrentDocMatchCount
    }
}
