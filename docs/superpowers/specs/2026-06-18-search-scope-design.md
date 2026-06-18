# Spec: Search scope — find docs in folders, highlight in-folder results

**Date:** 2026-06-18
**Status:** Approved (design) — ready for implementation plan
**Roadmap entry:** `docs/FutureEnhancements.md` → *Search → "Search scope is broken / incomplete"* (+ supersedes the older "In-folder cross-doc search" note)
**Target release:** the release after v1.9 (user's "v10.0", likely v1.10)

## Goal

Fix two reported search bugs with one coherent model — **"search is scoped to where you are":**

- **Bug 1 — Main Library search misses docs inside folders.** Today `LibraryView.filteredDocs`
  filters `docsAtRoot` (root-level docs only), so a search from the top can never surface a
  document that lives inside a folder.
- **Bug 2 — in-folder search finds but doesn't highlight.** `FolderContentsView`'s document
  rows push a `DocumentSummary` that resolves to the **root** `LibraryView`'s
  `navigationDestination`, which builds the viewer's `SearchContext` from `LibraryView`'s
  `searchText` — empty while searching inside a folder. The doc opens with no context, so
  matches aren't highlighted.

## Scope model (decided in brainstorming)

**Scoped to where you are:**

- **Main Library** search spans **every** document (root + all folders). While the search field
  is non-empty the folder rows hide and the screen flattens to a results list (Files-style);
  each result that lives in a folder shows an **"in &lt;Folder&gt;"** label.
- **Inside a folder**, search is scoped to **that folder only** (already how the list filters
  today — the gap is only that the term never reaches the viewer).
- Tapping a result opens the viewer with its matches highlighted, and cross-document
  next/prev navigation spans **the same scope** that was searched.

Rejected alternatives: global-everywhere (surprising when inside a folder) and a Files-style
scope toggle (more UI than a small-library scanner needs).

## Architecture (Approach A — unified document route)

Replace the fragile "destination reads `LibraryView.searchText`" coupling with a route value
that carries the originating screen's term + scope, so both screens feed the viewer identically.

### Components

1. **`SearchScope`** — `enum { case library; case folder(URL) }`. Describes where the search
   ran. (`.folder` carries the folder URL so the candidate set can be derived.)

2. **`SearchMatcher` (pure, unit-testable)** — the regression-critical core:
   ```
   static func matches(term: String, in summaries: [DocumentSummary], scope: SearchScope) -> [DocumentSummary]
   ```
   - Narrows `summaries` to the scope: `.library` = all; `.folder(F)` = docs whose parent
     directory is `F`.
   - Keeps those whose `displayName` or `ocrSnippet` contains `term` (case-insensitive).
   - Returns the matches (caller applies the existing `DocumentSort`).
   - Used by **both** the results list and as the candidate set for the viewer's context, so
     the two can never diverge.

3. **`DocumentRoute: Hashable`** — `{ summary: DocumentSummary, term: String, scope: SearchScope }`.
   The value pushed by all four document tap sites. `Hashable` (lives in the in-memory
   `NavigationPath`; no Codable/state-restoration requirement).

4. **One destination** — `navigationDestination(for: DocumentRoute.self)` replaces the current
   `navigationDestination(for: DocumentSummary.self)` and the `searchContextStarting(at:)`
   helper. It lazily builds the `SearchContext`:
   - candidates = `SearchMatcher.matches(term: route.term, in: store.summaries, scope: route.scope)`
     (skipped entirely when `route.term` is empty → `searchContext` nil, plain open).
   - run PDFKit `findString` over those candidates to get per-doc match counts (existing logic),
     `startDocIndex` = the route summary's index among the entries.
   - construct `DocumentViewerView` exactly as today (same `onDeleted` / `onDocumentCreated`).
   - Built lazily on open (not per row), so no per-render `findString` cost.

5. **Result label** — row (`DocumentRow`) and tile (`DocumentTile`) show **"in &lt;Folder&gt;"**
   when the summary's parent directory isn't the storage root. Surfaced only meaningfully in
   the flattened library-search results, but computed from the summary so it's presentation-only.

### Tap sites (push `DocumentRoute`)

- `LibraryView` list row (`:290`) and grid tile (`:376`) → `DocumentRoute(summary, searchText, .library)`.
- `FolderContentsView` list row (`:216`) and grid tile (`:236`) → `DocumentRoute(summary, searchText, .folder(folderURL))`.

Corrupt-doc rows keep their existing non-navigating treatment (no route pushed).

## Data flow

```
Library search (term T):
  results list = sort(SearchMatcher.matches(T, store.summaries, .library))   // all docs
  folder rows hidden while T is non-empty; flat results with "in <Folder>" labels
  tap R → push DocumentRoute(R, T, .library)
        → context over all T-matches, start = R → viewer highlights; cross-doc spans library

Folder F search (term T):
  results list = sort(SearchMatcher.matches(T, store.summaries, .folder(F)))  // F only
  tap R → push DocumentRoute(R, T, .folder(F))
        → context over F's T-matches, start = R → viewer highlights; cross-doc spans F

Empty search field: behaviour unchanged — folders + root docs (library) / folder docs (folder).
```

## Error handling / edge cases

- **No results:** show `ContentUnavailableView` (search variant) — "No results for '&lt;term&gt;'".
- **Corrupt doc matching by name:** appears in the results list (name match) but `findString`
  can't open it → excluded from the `SearchContext` entries; if its row is tappable it opens
  with no context (no highlight). Preserves today's "open without context rather than the wrong
  doc" behaviour.
- **Tapped doc not in entries** (ocrSnippet matched but `findString` returned zero): viewer
  opens with `searchContext` nil — unchanged from today.
- **"Show Folders" off:** the library is already a single flat list (`visibleDocs == store.summaries`),
  so search-all is consistent; "in &lt;Folder&gt;" labels still show for any doc with a non-root parent.

## Testing

- **Unit-test `SearchMatcher.matches(...)`** — the two bugs *are* scope-logic bugs, so this is the
  guard: a fixture set spanning root + multiple folders, asserting `.library` returns matches
  everywhere (incl. inside folders) and `.folder(F)` returns only F's matches; case-insensitive;
  name-only and ocr-only matches both surface.
- Verify the context builder still counts/sorts matches (extend existing search tests if present;
  the `findString` step needs real PDF fixtures).
- **On-device:** (a) search from Main Library finds a doc inside a folder and highlights it on
  open; (b) search inside a folder highlights on open; (c) cross-doc next/prev respects scope
  (library search flows across folders; folder search stays within the folder); (d) "in &lt;Folder&gt;"
  labels appear on flattened library results; (e) empty-results state shows.

## Deliverables

- `SearchScope` + `SearchMatcher` (new, pure, tested) under `Library/`.
- `DocumentRoute` + the single `navigationDestination(for: DocumentRoute.self)`; remove
  `searchContextStarting(at:)`.
- `LibraryView`: `filteredDocs` spans all docs while searching + hides folder rows during search;
  its 2 tap sites push `.library`-scoped routes; no-results state.
- `FolderContentsView`: 2 tap sites push folder-scoped routes.
- `DocumentRow` / `DocumentTile`: optional "in &lt;Folder&gt;" label.
- Spec + plan under `docs/superpowers/`. Update the `FutureEnhancements.md` Search section on merge
  (remove the two now-fixed items).

## Non-goals

- A scope toggle / "search everywhere" control.
- Ranking / relevance ordering (results keep the user's current `DocumentSort`).
- Searching folder *names* (search is over documents, as today).
- Changing the highlight rendering itself (covered by the separate highlighter decision).
