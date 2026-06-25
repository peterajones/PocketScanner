# Spec: Merge two documents

**Date:** 2026-06-25
**Status:** Approved (design) — ready for implementation plan
**Roadmap origin:** FutureEnhancements ▸ Documents ▸ "Merge two documents".
**Target release:** v2.2 (next after v2.1; build on a feature branch).

## Goal

Combine two existing scans into one PDF — for when something was scanned across two
sessions and should be a single document. The PDF engine already supports it
(`DocumentMutations.append`); this adds the UI and the file-level orchestration.

## Scope decisions (from brainstorming)

- **Entry point: a context-menu "Merge into…" submenu**, mirroring the existing `MoveToMenu`.
  No new multi-select infrastructure (the library has none today). Merges two documents at a
  time.
- **Result: B absorbs A, then A is deleted.** Long-press **A** → "Merge into…" → pick **B**:
  A's pages append to the **end** of B; B keeps its name and folder; **A is removed**. One
  combined document remains. Destructive, so it is gated by a confirmation alert.
- **Target list: all other valid documents** (across folders), folder-labeled. Small libraries
  make a flat list fine; corrupt docs and A itself are excluded.
- **Order: A appended after B** (follows "merge A *into* B"). No reordering step.
- **No naming prompt** — the result is B, so it keeps B's name (unlike extraction's "Save as New").
- **Lossless:** pages are inserted as real `PDFPage` objects, so the OCR text layer and any
  signature/highlight/strikethrough annotations on both documents are preserved.

## Architecture / components

Follows the established library patterns (`MoveToMenu` + `MoveDestinations` + `moveDocument`).

### `MergeCandidates` (new, pure) — `Library/MergeCandidates.swift`
- Input: the source `DocumentSummary` and `store.summaries` — the **complete** library document
  list, which both `LibraryView` and `FolderContentsView` already hold (FolderContentsView only
  *filters* it by folder for display). So merge targets span all folders from either view.
- Output: the documents eligible as merge targets — **all except the source itself and any
  corrupt doc**. Sorted for stable display (reuse the library's current order).
- Pure, no I/O → unit-tested in isolation (like `MoveDestinations`).

### `MergeIntoMenu` (new view) — `Library/MergeIntoMenu.swift`
- Sibling of `MoveToMenu`. Takes the source summary, the candidate `[DocumentSummary]`, and a
  `merge: (DocumentSummary) -> Void` closure.
- Renders a `Menu("Merge into…", systemImage: "arrow.triangle.merge")` whose items are the
  candidate documents (title + folder label where helpful). Each item calls `merge(target)`.
- Rendered only when candidates is non-empty.

### `LibraryView` / `FolderContentsView` wiring
- Add `MergeIntoMenu` to `docContextMenu(_:)` for **valid** docs (the corrupt branch keeps just
  Delete), positioned after `MoveToMenu`.
- New state: `@State private var mergePlan: MergePlan?` where
  `struct MergePlan { let source: DocumentSummary; let target: DocumentSummary }`.
- Picking a target sets `mergePlan` → a confirmation `.alert` (see below).
- A `mergeDocument(_ source:into:)` method performs the merge (see Data flow), mirroring the
  existing `moveDocument(_:to:)` for refresh handling.
- A `mergeError: String?` → error alert, mirroring the move/extract error alerts.

## Data flow

```
Long-press A → "Merge into…" → pick B
  → mergePlan = {source: A, target: B}
  → confirm alert: "Merge \"A\" into \"B\"?  A's pages will be added to the end of \"B\",
                    and \"A\" will be deleted."  [Cancel] [Merge]
  → on Merge: mergeDocument(A, into: B)
       1. load B.pdf and A.pdf as PDFDocument(url:)        (guard both; else mergeError)
       2. DocumentMutations.append(A.pdf, to: B.pdf)        (A's pages → end of B; lossless)
       3. storage.write(B.pdf, replacing: B.url, withName: B.displayName)   (overwrite B in place)
       4. storage.delete(at: A.url)                         (only after step 3 succeeds)
       5. refresh the library (same path as moveDocument / delete)
```

`DocumentStorage.write(_:replacing:withName:)` is atomic + file-coordinated (same as
`DocumentSession.save`), so B is never left half-written. `storage.delete(at:)` is the existing
document delete.

## Error handling / edge cases

- **"Merge into…" hidden when there's no candidate** (`MergeCandidates` empty — e.g. only one
  valid document) so the menu never dead-ends.
- **Corrupt documents** are excluded as both source (the corrupt branch of `docContextMenu` shows
  only Delete) and target (`MergeCandidates` filters them).
- **Load failure** (either PDF unreadable) → `mergeError`, nothing changes.
- **Save failure** (step 3 throws) → `mergeError`, **A is NOT deleted**, B untouched on disk
  (atomic write). The user keeps both originals.
- **A only deleted after B is saved** — same safe ordering as extraction's "Save as New", so a
  failure never loses data.
- **Same-folder vs cross-folder:** B keeps its own location; A is removed from wherever it lived.
- **No undo** (consistent with the app); the confirmation alert is the safety net.

## Testing

- **`MergeCandidates` (pure):** excludes the source and corrupt docs; returns the rest; empty when
  the source is the only valid doc. Unit-tested like `MoveDestinationsTests`.
- **`DocumentMutations.append`:** add/confirm a test that merging yields `A.pageCount + B.pageCount`
  pages in B, B's pages first then A's, and that a page's OCR text / annotation survives the
  insert (lossless).
- **Storage orchestration:** with a temp `DocumentStorage`, a merge writes the combined document
  to B's URL and removes A's file; a forced save failure leaves both files intact (A not deleted).

## Deliverables

- New `Library/MergeCandidates.swift` (+ tests) and `Library/MergeIntoMenu.swift`.
- `Library/LibraryView.swift` + `Library/FolderContentsView.swift`: "Merge into…" in the valid-doc
  context menu, confirm alert, `mergeDocument(_:into:)`, `mergeError`.
- Reuses `DocumentMutations.append`, `DocumentStorage.write(_:replacing:withName:)`,
  `DocumentStorage.delete(at:)`.
- Spec under `docs/superpowers/`. On merge, mark the FutureEnhancements "Merge two documents"
  item shipped (v2.2).

## Non-goals

- Merging more than two documents at once (would need library multi-select).
- A reordering / interleaving step (A always appends after B).
- Renaming the result during the merge (it stays B; rename separately afterward).
- Merging *pages* across documents (page extraction already covers per-page moves).
- Undo / a non-destructive "keep both" mode (rejected during brainstorming).
