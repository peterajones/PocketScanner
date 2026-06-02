# Search polish — design

**Date:** 2026-06-02
**Status:** Spec approved; ready for implementation plan
**Related:** `docs/FutureEnhancements.md` → "Search" section (two items)

## Background

In v1.1, search works end-to-end but has two rough edges that hold it back from feeling "intentional":

1. **Highlights are vertically accurate but horizontally approximate.** `PDFAssembler.drawInvisibleText` writes invisible glyphs at each OCR observation's bounding box using the system font. The system font's glyph widths don't match the original scanned-page glyph widths, so PDFKit's `findString` returns selections whose horizontal extent drifts from the visible text — sometimes underrunning, sometimes overrunning by 10–30%.
2. **Search loses cross-document context when you tap into a doc.** The library lists every doc whose `ocrSnippet` matches, but tapping any one drops the user into single-doc nav — you cycle through that doc's matches and have to back out to see the next doc's hits. There's no signal that other docs even have matches.

User showed v1.1 search to a programmer who was impressed; goal of this rework is to push it past "impressive" into "the demo moment."

## Goals

1. Highlights snap exactly under the scanned text horizontally, so a user reading the highlighted word sees the highlight and the word as the same shape.
2. The viewer's next/prev buttons auto-flow through all matches across all docs, with a counter that surfaces the global state: "Match 3 of 12 · 4 docs."

## Non-goals

- Editing the search term from inside the viewer (still back-out-and-retype).
- Within-library highlighting of matches (no change to library list rendering).
- Search-result preview snippets in the library list.
- Performance hardening for libraries > ~50 docs. See [[project-scale-small-libraries]] — that audience would have moved off the app.
- Re-rendering existing PDFs with the new highlight geometry. Only new scans benefit.

## Design

Two independent changes, both ship in v1.2.

| Item | Layer | Files touched |
| --- | --- | --- |
| Horizontal highlight accuracy | Write path — scan time only | `Pipeline/PDFAssembler.swift` (modify), `DocumentScannerTests/PDFAssemblerHighlightTests.swift` (new) |
| Cross-doc match navigation | Read path — search runtime | `Viewer/SearchContext.swift` (new), `Library/LibraryView.swift` (modify), `Viewer/DocumentViewerView.swift` (modify) |

The items don't interact: Item 1 changes how new PDFs are laid down; Item 2 changes how matches in *any* PDF are navigated.

### Item 1 — Horizontal highlight accuracy

Modify `PDFAssembler.drawInvisibleText`. After building the CTLine, measure its natural width, then scale the graphics CTM horizontally so the rendered glyphs span exactly the OCR observation's rect width:

```swift
let font = UIFont.systemFont(ofSize: rect.height)
let attributed = NSAttributedString(
    string: observation.string,
    attributes: [.font: font, .foregroundColor: UIColor.clear]
)
let ctLine = CTLineCreateWithAttributedString(attributed)

let naturalWidth = CGFloat(CTLineGetTypographicBounds(ctLine, nil, nil, nil))
let scaleX: CGFloat = naturalWidth > 0 ? rect.width / naturalWidth : 1

// Translate to the OCR rect origin, scale the CTM horizontally, then
// draw the line at the local origin. Save/restore the inner state around
// each observation so the transforms don't accumulate.
context.saveGState()
context.translateBy(x: rect.origin.x, y: rect.origin.y)
context.scaleBy(x: scaleX, y: 1)
context.textPosition = .zero
CTLineDraw(ctLine, context)
context.restoreGState()
```

Why it works: scaling the CTM horizontally compresses or stretches every drawn glyph's footprint to fit the OCR rect width. PDFKit's `findString` reads glyph positions from the post-CTM content stream, so the returned `PDFSelection`s match the visible OCR width.

**Important: do NOT use `context.textMatrix` for this.** Setting `textMatrix` to a non-identity transform causes PDFKit's `findString` to return zero matches — PDFKit cannot index glyphs drawn under a non-identity text matrix. The CTM (translate + scale) achieves the same horizontal-scaling effect while keeping the glyphs indexable. Verified empirically during v1.2 implementation; the original spec proposed `textMatrix` and had to be corrected.

**Edge cases:**
- `naturalWidth == 0` (empty string): guard with `scaleX = 1`. Shouldn't occur because observations come from Vision recognition.
- Very wide rect + short string: scale up, invisible glyphs, no visual issue.
- Multi-line OCR observations: each `OCRObservation` is one line per Vision's API; loop already handles per-line.

No other changes in `PDFAssembler`. Callers unchanged.

### Item 2 — Cross-doc match navigation

Three sub-pieces.

#### 2a. `SearchContext` value type (new)

`DocumentScanner/Viewer/SearchContext.swift`:

```swift
struct SearchContext: Hashable {
    let term: String
    /// Ordered list of docs that have matches, in library display order.
    /// Each entry's `matchCount` comes from PDFKit's findString.
    let docs: [DocEntry]
    /// Index into `docs` of the doc the user tapped — viewer starts here.
    let startDocIndex: Int

    struct DocEntry: Hashable {
        let summary: DocumentSummary
        let matchCount: Int
    }

    /// Total matches across all docs in the context.
    var totalMatches: Int { docs.reduce(0) { $0 + $1.matchCount } }
}
```

Deliberately stores only `matchCount` per doc, not full `[PDFSelection]` arrays. `PDFSelection` holds a strong reference to its `PDFDocument`, and keeping every matching doc parsed in memory would waste memory unnecessarily. Per-doc selections are computed lazily by the viewer when that doc is loaded.

#### 2b. `LibraryView` builds the SearchContext

In `Library/LibraryView.swift`, add a computed property:

```swift
private var searchContext: SearchContext? {
    guard !searchText.isEmpty else { return nil }
    let entries: [SearchContext.DocEntry] = filteredDocs.compactMap { summary in
        guard let pdf = PDFDocument(url: summary.url) else { return nil }
        let count = pdf.findString(searchText, withOptions: .caseInsensitive).count
        return count > 0 ? .init(summary: summary, matchCount: count) : nil
    }
    return entries.isEmpty ? nil : SearchContext(term: searchText,
                                                 docs: entries,
                                                 startDocIndex: 0)
}
```

In the `navigationDestination(for: DocumentSummary.self)`, when building the viewer:

```swift
DocumentViewerView(
    summary: summary,
    storage: storage,
    scannerPresenter: scannerPresenter,
    pipeline: pipeline,
    searchContext: searchContext.map { ctx in
        var ctx = ctx
        if let idx = ctx.docs.firstIndex(where: { $0.summary.id == summary.id }) {
            ctx = SearchContext(term: ctx.term, docs: ctx.docs, startDocIndex: idx)
        }
        return ctx
    },
    onDeleted: { ... }
)
```

The `compactMap` drops docs whose `ocrSnippet` matched the substring filter but whose `PDFKit findString` returns 0 (rare but possible with weird whitespace or unicode edge cases).

#### 2c. `DocumentViewerView` + `SearchHighlight` changes

Replace the existing `searchTerm: String?` parameter with `searchContext: SearchContext?`. Add `@State private var currentDocIndex: Int` initialized from `searchContext?.startDocIndex`.

The viewer loads the doc at `searchContext.docs[currentDocIndex].summary`. When `currentDocIndex` changes, `task(id:)` reloads the session and `rebuildHighlight` runs `findString` against the newly loaded `pdf` (same logic as today, just sourced from the context).

Override `SearchHighlight.next()` / `previous()` semantics in the viewer:

```swift
private var hasNextDoc: Bool {
    guard let ctx = searchContext else { return false }
    return currentDocIndex < ctx.docs.count - 1
}
private var hasPreviousDoc: Bool { currentDocIndex > 0 }

private func handleNext(_ h: SearchHighlight) {
    if h.currentIndex == h.matchCount - 1, hasNextDoc {
        currentDocIndex += 1
        // Mutating currentDocIndex changes the viewer's `.task(id: ...)` key,
        // which reloads the session and runs `rebuildHighlight`, landing on
        // match 0 of the new doc by SearchHighlight's default init.
    } else {
        h.next()
    }
}

private func handlePrevious(_ h: SearchHighlight) {
    if h.currentIndex == 0, hasPreviousDoc {
        pendingJumpToLastMatch = true
        currentDocIndex -= 1
        // `rebuildHighlight` checks `pendingJumpToLastMatch` after building
        // SearchHighlight and, if set, advances currentIndex to matchCount-1
        // before clearing the flag.
    } else {
        h.previous()
    }
}
```

The viewer needs `.task(id: currentDocIndex)` on the session-loading block (in addition to / replacing the current one-shot `.task`) so doc changes trigger reloads. `pendingJumpToLastMatch` is a `@State Bool` consumed inside `rebuildHighlight`.

Single-doc behaviour (only one doc in context, or no context at all) collapses to the existing wrap-within-doc semantics because `hasNextDoc` / `hasPreviousDoc` are both false.

The match counter (currently line 99 of `DocumentViewerView.swift`):

```swift
let globalIndex = searchContext.docs[..<currentDocIndex]
    .reduce(0) { $0 + $1.matchCount } + (h.currentIndex ?? 0) + 1
Text("\(globalIndex) of \(searchContext.totalMatches) · \(searchContext.docs.count) docs")
```

`SearchHighlight` itself doesn't need restructuring — it stays per-doc; cross-doc logic lives in the viewer.

### Behaviour at extremes

- **No matches anywhere** → `searchContext = nil`, library shows no rows, viewer never reached.
- **One doc with matches** → counter reads "Match X of Y · 1 docs", next/prev wraps inside that doc. (UX-equivalent to today.)
- **User edits search text inside viewer** → unsupported; `SearchContext` is fixed at presentation time. To re-search, back out to library.
- **Doc deleted from viewer mid-search** → existing flow: viewer pops, library refreshes, `searchContext` rebuilds.

## Testing

| Target | How |
| --- | --- |
| `PDFAssemblerHighlightTests` (new) | Assemble a 1-page PDF from a known `OCRObservation` with a specific boundingBox and string. Call `pdf.findString` on the result, take the first selection, assert its `bounds(for:)` x and width match the observation rect within ~5pt tolerance (gives headroom for PDFKit's glyph-position rounding while still being orders of magnitude tighter than the pre-fix drift of 30-100pt). |
| `SearchContext` tests | Pure value-type tests: `totalMatches` correctness, `Hashable` equality, behaviour when `docs` is empty. |
| LibraryView `searchContext` builder | Test that a doc whose `ocrSnippet` matches but `findString` returns 0 is dropped from `docs`. |
| Cross-doc navigation flow | Manual on device — spans LibraryView → DocumentViewerView state with PDFKit rendering, not unit-testable cleanly. Verification: search for a term that hits multiple docs, tap into one, exercise next past end and prev past start, confirm doc transitions + counter updates + highlight jumps. |

Existing `ImageFilterTests` / other tests unaffected.

## Risks / open questions

1. **PDFs with no text layer:** `findString` returns empty → doc gets dropped from `searchContext.docs`. Correct behaviour, no action needed.
2. **Text-matrix scale on very narrow Vision boxes:** Rare, glyphs invisible, no visual impact; PDFKit's resulting highlights still match the OCR rect width — that's the goal.
3. **Search term change inside viewer:** out of scope; documented in non-goals.

## Rollout

Ships in v1.2 alongside the filter rework. No migration. Item 1 only affects highlight geometry of *newly scanned* PDFs; pre-v1.2 PDFs keep their old approximate highlights. We do not retroactively re-render old PDFs.
