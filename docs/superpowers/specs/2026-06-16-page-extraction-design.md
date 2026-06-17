# Spec: Page extraction (copy selected pages to a new document)

**Date:** 2026-06-16
**Status:** Approved (design) — ready for implementation plan
**Roadmap entry:** `docs/FutureEnhancements.md` → *Editing → Page extraction*
**Target release:** v1.8 (13)

## Goal

Let the user select pages in edit mode and save **copies** of them as a new document —
to break a multi-page scan into separate documents — **non-destructively** (the original
keeps all its pages).

## Scope decisions (from brainstorming)

- **Copy, not move.** Selected pages are copied into a new document; the original is
  unchanged. No confirmation dialog and no "can't extract all pages" guard needed.
- **Name prompt with a sensible default.** On extract, show a name field pre-filled with
  `"{original displayName} extract"`; the user accepts or edits, then Save.
- **Lands in the same folder as the source.** Consistent with the app's existing
  folder-aware saving (`FolderContentsView` saves new scans into the current folder).
  Implemented by writing to the source document's parent directory.
- **Two entry points:** the multi-select header gets a **Save as New** action, and the
  single-page context menu gets a **Save page as new** item.
- **Lightweight name UI** — a SwiftUI `.alert` with a `TextField`, not the scan
  `NameDocumentSheet` (which carries a filter preview irrelevant to extraction).

## Non-goals

- Moving/splitting (destructive removal from the original) — deferred; copy only.
- Choosing a different destination folder at extract time — it lands next to the source;
  the user can Move it afterward (the Move feature already exists).
- Reordering pages during extraction (extracted in ascending page order).
- Re-running OCR or filters — copied pages already carry their text layer and baked-in
  filter.

## Architecture / components

### 1. `DocumentMutations.extractPages(from:at:) -> PDFDocument` (new, pure, unit-tested)
Builds and returns a fresh `PDFDocument` containing **deep copies** of the pages at the
given indices, in **ascending index order**. Each page is copied via `PDFPage.copy()`
(NSCopying), which preserves the page's content stream (incl. the invisible OCR text
layer), its `/Rotate` value, and its annotations. The source `PDFDocument` is **not
mutated**. Out-of-range indices are ignored; an empty index set yields an empty
`PDFDocument` (caller guards against this — see below).

Signature mirrors the existing `deletePages(in:at:)` / `rotatePage(in:at:)` helpers.

### 2. `EditModeView`
- New closure property: `onExtract: (Set<Int>) -> Void` (same pattern as the existing
  `onAddPages` / `onEditPage` closures).
- **Multi-select header:** add a **Save as New** button (SF Symbol
  `square.and.arrow.up.on.square` or `doc.badge.plus`), enabled when `!selectedIndices.isEmpty`,
  that calls `onExtract(selectedIndices)` then exits multi-select.
- **Single-page context menu:** add a **Save page as new** item (between Rotate Right and
  Delete page) that calls `onExtract([index])`.

### 3. `DocumentViewerView` (hosts the strip, owns `storage` + `session`)
Implements `onExtract`:
1. `let newPDF = DocumentMutations.extractPages(from: session.pdf, at: indices)` — guard
   `newPDF.pageCount > 0`.
2. Present the **name alert** with default `"\(session.displayName) extract"`.
3. On Save: `let folderStorage = DocumentStorage(documentsURL: session.url.deletingLastPathComponent())`,
   then `try folderStorage.write(newPDF, preferredName: name)`.
4. The new file is now on disk in the source's folder. It surfaces in the library when
   the user navigates back: iCloud mode updates automatically via `NSMetadataQuery`.
   *(As-built: the local-mode `InMemoryLibraryStore` does NOT auto-detect new files, and
   refreshing it while `LibraryView` is buried behind the pushed viewer doesn't re-render
   it — so `LibraryView` re-scans the store when navigation pops back toward it. A
   write-time refresh alone was insufficient; found during on-device smoke testing.)*
5. Brief confirmation; stay in the current document's viewer (original untouched).
On `write` throwing → surface via the existing `AlertCenter`.

### 4. Name alert
SwiftUI `.alert("Save as New Document", isPresented:)` with a `TextField` bound to a
`@State` name (default `"{displayName} extract"`); **Save** disabled when the trimmed name
is empty. Sanitization and `(N)` collision-suffixing are already handled by
`DocumentStorage.write`.

## Data flow

```
selectedIndices
  → DocumentMutations.extractPages(from: session.pdf, at:)   // new PDFDocument (copies)
  → name alert (default "{displayName} extract")
  → DocumentStorage(documentsURL: source-parent).write(preferredName:)   // new file on disk
  → (library shows it on return: iCloud query auto-updates; local store refreshes on appear)
```

## Error handling

- `write` throws (e.g., I/O) → routed to `AlertCenter` as a user-facing alert.
- Empty/whitespace name → **Save** disabled; `DocumentStorage` also throws `emptyName` as a
  backstop.
- Zero pages selected → the multi-select **Save as New** button is disabled; the
  single-page path always passes exactly one index.

## Testing

- **`DocumentMutationsTests` (new cases):**
  - `extractPages` returns a document with the selected pages in ascending order.
  - Original document is unchanged (page count + page identity).
  - A rotated page extracts with its rotation preserved.
  - The extracted page's text is searchable (OCR layer survived the copy).
  - Out-of-range indices are ignored; empty set → empty document.
- **Manual (on device):** multi-select → Save as New → name → the new doc appears in the
  same folder; original intact; extracting a rotated/annotated page carries those over.

## Deliverables

- `DocumentMutations.extractPages` + tests in `DocumentMutationsTests`.
- `EditModeView`: `onExtract` closure, header **Save as New** button, context-menu
  **Save page as new** item.
- `DocumentViewerView`: `onExtract` handler, name alert, folder-scoped write, library refresh.
- Spec + plan under `docs/superpowers/`.
