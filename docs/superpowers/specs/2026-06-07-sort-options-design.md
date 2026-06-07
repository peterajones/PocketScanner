# Sort Options — Design

**Date:** 2026-06-07
**Release:** v1.5 (build 10)
**Status:** Approved

## Problem

The document library is always ordered newest-first (both library stores sort
`summaries` by `createdAt` descending, and the views preserve that order). Users
want to reorder — by name to find a document alphabetically, or by page count to
spot the big multi-page scans.

## Goal

A sort control offering three keys — **Date**, **Name**, **Page Count** — each in
ascending or descending order. The choice is a single global preference that
applies to every document list (main library and every folder) and persists across
launches. Default stays Date / newest-first, so existing users see no change until
they pick a sort.

## Interaction

A **toolbar sort menu** (SF Symbol `arrow.up.arrow.down.circle`) in both
`LibraryView` and `FolderContentsView`, following the Apple Files pattern:

- The menu lists the three keys. The active key shows a checkmark and an up/down
  chevron indicating its current direction.
- Tapping a **different** key switches to it, applying that key's natural default
  direction.
- Tapping the **active** key flips its direction.

Natural default direction per key (applied when switching to a key):

- **Name** → ascending (A–Z)
- **Date** → descending (newest first)
- **Page Count** → descending (most pages first)

## Non-Goals (YAGNI)

- No per-folder sort (one global setting — decided in brainstorming).
- Folders are **not** re-sorted by this control; the folder section stays
  alphabetical (A–Z) as today.
- No extra keys (kind, size, modified-date), no custom/manual ordering.
- No sort control in the document viewer (it's a library concern).

## Model — `DocumentSort` (pure, testable)

New file `DocumentScanner/DocumentScanner/Library/DocumentSort.swift`:

```swift
enum SortKey: String, CaseIterable {
    case date
    case name
    case pageCount
}

struct DocumentSort: Equatable {
    var key: SortKey
    var ascending: Bool

    /// The natural default direction when first switching to a key.
    static func defaultAscending(for key: SortKey) -> Bool { key == .name }

    /// Returns docs ordered by the current key/direction. Stable: ties break by
    /// case-insensitive name, then url, so order never jitters between runs.
    func sorted(_ docs: [DocumentSummary]) -> [DocumentSummary]
}
```

- **Name** compares `displayName` case-insensitively (`localizedCaseInsensitiveCompare`).
- **Date** compares `createdAt`; **Page Count** compares `pageCount`.
- `ascending` reverses the comparison.
- Tie-break order (always ascending, regardless of `ascending`): case-insensitive
  `displayName`, then `url.path` — guarantees a deterministic, stable result.
- `defaultAscending(for:)` encodes the per-key natural direction (Name asc; Date
  and Page Count desc).

This type has no SwiftUI/PDFKit dependency beyond `DocumentSummary`, so it is unit-
tested directly.

## Persistence

Two `@AppStorage` values store the global preference:

- `@AppStorage("sortKey")` — the `SortKey` raw value (`String`), default `"date"`.
- `@AppStorage("sortAscending")` — `Bool`, default `false` (newest-first).

Both `LibraryView` and `FolderContentsView` read the same keys, so the preference
is shared and survives launches with no extra storage code.

## Where it applies

`DocumentSort(key:ascending:).sorted(...)` is applied to the document lists after
the existing search filter:

- `LibraryView`: the `filteredDocs` computed property (which already filters
  `visibleDocs` by search text) is sorted before rendering.
- `FolderContentsView`: the `filtered` computed property (filters `docsInFolder`)
  is sorted before rendering.

The library stores keep their existing `createdAt`-descending sort as the load
order; the view layer owns the user-facing sort, so the iCloud/store plumbing is
untouched. Folder rows remain alphabetical (`LibraryView.refreshFolders` already
sorts folders by name).

## Data flow

```
@AppStorage(sortKey, sortAscending)
   → DocumentSort(key:ascending:)
   → applied to the already-filtered document array
   → rendered

tap a menu item → update @AppStorage → both views re-render with new order
```

No save, no disk, no network — pure in-memory reordering of already-loaded
summaries.

## Error handling

None required. A malformed/missing `@AppStorage("sortKey")` falls back to the
default via `SortKey(rawValue:) ?? .date`.

## Testing

`DocumentSortTests` (pure):

- Each key sorts correctly ascending and descending (date, name, pageCount).
- Name sort is case-insensitive (e.g. `"apple"` before `"Banana"`).
- Tie-break is stable: equal primary keys order by name then url, identically on
  repeat calls.
- `defaultAscending(for:)` returns ascending only for `.name`.
- Empty and single-element inputs are handled.

The toolbar menu wiring (checkmark/chevron state, tap-to-switch vs tap-to-flip) is
verified by the manual smoke test, consistent with prior releases.

## Version

- `MARKETING_VERSION` 1.4 → **1.5**
- `CURRENT_PROJECT_VERSION` 9 → **10**

Main-app Debug + Release configs only; test targets unchanged. Set in Xcode, as in
prior releases.
