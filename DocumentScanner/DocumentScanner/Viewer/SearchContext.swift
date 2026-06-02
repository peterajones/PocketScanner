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
}
