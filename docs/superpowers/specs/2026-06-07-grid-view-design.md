# Grid View — Design

**Date:** 2026-06-07
**Release:** v1.5 (build 10) — ships together with Sort Options
**Status:** Approved

## Problem

The library and folders render only as a single-column `List`. For visually-driven
browsing (lots of similar-looking scans) a thumbnail grid is faster to scan than a
list of small 44×56 thumbnails.

## Goal

A list/grid toggle for the document library. In grid mode the library and folders
render as a `LazyVGrid` of thumbnail tiles. The choice is one global, persisted
preference applied to both the main library and folder views. List mode is the
default, so existing users see no change until they toggle.

## Interaction

A **layout toggle button** in the toolbar of both `LibraryView` and
`FolderContentsView`. Its icon reflects the *other* mode you'd switch to:
`square.grid.2x2` while in list mode, `list.bullet` while in grid mode. Tapping
flips the global preference.

## Non-Goals (YAGNI)

- No per-folder layout (one global setting, like sort).
- No adjustable tile size / column-count control (adaptive columns only).
- No reordering, multi-select, or drag-and-drop in the grid.
- No change to list mode's appearance.

## View-mode preference

A single `@AppStorage("libraryUsesGrid")` `Bool`, default `false` (list). Both
views read the same key, so the preference is shared globally and survives
launches — the same pattern used by `showFolders` and the sort preference.

A small reusable **`LayoutToggle`** view (mirroring `SortMenu`) renders the toolbar
button: it takes the current `usesGrid` value and an `onToggle` closure.

## Rendering

Each view branches on `usesGrid`:

- **List mode** — the existing `List` (with its sections), unchanged.
- **Grid mode** — a `ScrollView` containing a `LazyVGrid` with adaptive columns:
  `[GridItem(.adaptive(minimum: 110), spacing: 12)]` (~3 columns on a phone, more
  on larger screens), with `.searchable` attached as today.

The grid iterates the **same** already-filtered, already-sorted arrays the list
uses (`LibraryView.filteredDocs`, `FolderContentsView.filtered`), so search and
sort behave identically in both modes. Documents follow the sort; folders stay
alphabetical.

### LibraryView grid contents

One `LazyVGrid` rendering, in order:

1. **Folder tiles** (when `showFolders` and folders exist) — alphabetical, same
   order as the list's folder section.
2. **Document tiles** — the `filteredDocs` array.

### FolderContentsView grid contents

Document tiles only (a folder has no sub-folders) — the `filtered` array. The
existing empty-folder `ContentUnavailableView` still shows when the folder is
empty.

## Components

1. **`DocumentThumbnail(url:size:)`** (new, shared) — promote the private
   `ThumbnailView` currently inside `DocumentRow.swift` into its own reusable view,
   parameterized by render size. `DocumentRow` uses it at 44×56 (unchanged
   behavior); grid tiles use it larger (e.g. a 220×280 render) for crispness. Same
   `PDFDocument(url:)` → `page(at: 0)?.thumbnail(of:for:)` async-detached approach.

2. **`DocumentTile(summary:)`** (new) — a vertical tile: `DocumentThumbnail`
   (paper-aspect, fills tile width) over the document name (1 line, semibold) and a
   small "date · pages" subtitle — the same text `DocumentRow` shows. Corrupt
   documents show the ⚠️ placeholder tile (mirroring `DocumentRow`'s corrupt
   branch). Used inside a `NavigationLink(value: summary)` and carries the **same
   `.contextMenu`** the list's `docRow` does (Move to…; for corrupt docs, Delete).

3. **`FolderTile(url:)`** (new, LibraryView only) — a tile with a folder glyph
   (`folder.fill`, tinted) over the folder name. Used inside
   `NavigationLink(value: folderURL)` and carries the **same** rename/delete
   `.contextMenu` the list's folder row does.

4. **`LayoutToggle(usesGrid:onToggle:)`** (new) — the toolbar button.

The context-menu *contents* (the buttons and their actions) are identical between
list and grid; to avoid duplicating that logic, the existing context-menu builders
in `LibraryView`/`FolderContentsView` are reused by both the row and the tile
(extract into a small `@ViewBuilder` helper per view where the menu body currently
lives inline).

## Data flow

```
@AppStorage("libraryUsesGrid")
   → branch: List  OR  ScrollView + LazyVGrid
   → both render the same filtered + sorted arrays
toggle button → flip libraryUsesGrid → view re-renders in the other layout
```

No disk, no network, no store changes — pure presentation.

## Error handling

None new. Corrupt documents render the placeholder tile; a thumbnail that fails to
render shows the same empty/placeholder state it does in the list today.

## Testing

Grid view is presentation; the sortable/filterable/movable model it renders is
already unit-tested (DocumentSort, MoveDestinations, etc.). There is no new pure
logic to unit-test, so — consistent with how `SortMenu`, `MoveToMenu`, and
`MarkupPDFView` were handled — the gates are:

- A clean `xcodebuild build`.
- The existing unit suite (`DocumentScannerTests`) still green (no regressions from
  extracting `DocumentThumbnail` or the context-menu helpers).
- A manual smoke test: toggle list↔grid in the library and inside a folder; folder
  tiles navigate; document tiles open the viewer; context menus (Move to…, rename,
  delete) work from tiles; an active search and the chosen sort both still apply in
  grid mode; the preference persists across a relaunch.

## Version

**No version bump.** This ships under the already-merged **v1.5 (build 10)**, which
was pushed to git but never uploaded to App Store Connect. We submit 1.5 (10) with
both Sort Options and Grid View. (If build 10 has been uploaded by the time this
lands, bump the build to 11.)
