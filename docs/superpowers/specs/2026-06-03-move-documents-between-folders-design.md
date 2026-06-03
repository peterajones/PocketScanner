# Move Documents Between Folders — Design

**Date:** 2026-06-03
**Release:** v1.3 (build 8)
**Status:** Approved

## Problem

Folders are currently a one-way trip. A document can be scanned into a folder or
moved into one from the main library, but it can never be moved *out* of a folder
or relocated from one folder to another. Real-world case: a doc lands in folder A,
then a later, more-related scan makes it clear it belongs in folder B — there is no
way to move it.

Concretely, today:

- **Root documents** have a `Move to Folder` submenu in their context menu that
  lists folders and moves the doc in (`LibraryView.docRow`).
- **Documents inside a folder** have *no* move action — a `FolderContentsView`
  non-corrupt row is a plain `NavigationLink` with no context menu.
- There is **no "move to main library / root" option** anywhere.

## Goal

A single unified "Move to…" action that handles every case:

- folder → another folder
- folder → main library (root)
- main library → folder

Available from the **root list** context menu and the **folder list** context
menu (long-press a document). Not in the document viewer (decided out of scope for
this release).

## Non-Goals (YAGNI)

- No confirmation dialog on move.
- No multi-select / batch move.
- No nested folders (folders are flat today; destinations are root + one level).
- No "Move to…" from the document viewer's ⋯ menu.

## Storage Layer

`DocumentStorage.moveDocument(at:toFolder:)` already does what we need: it moves a
file into any destination directory URL and resolves name collisions at the
destination with the existing `(N)` suffix scheme (`uniqueURL(in:base:)`).

Moving a document to the **main library** is simply calling it with
`storage.documentsURL` (the root) as the destination directory. No new storage
method is required.

**Change:** none to production code beyond confirming the root-destination case
works. Add test coverage for moving *out* to root and folder→folder.

## UI: Shared `MoveToMenu`

Both entry points render the same submenu, so factor it into one small reusable
SwiftUI view, `MoveToMenu`, in `Library/`.

Inputs:

- `currentParentURL: URL` — the document's current containing directory.
- `rootURL: URL` — `storage.documentsURL`.
- `folders: [URL]` — the root-level folder list.
- `move: (URL) -> Void` — closure invoked with the chosen destination directory.

Rendering (a `Menu("Move to…")` with `systemImage: "folder"`):

```
Move to… ▸
   Main Library      (only when currentParentURL != rootURL)
   <folder name>     (one Button per folder, current folder excluded)
```

Destination computation: `[rootURL] + folders`, minus any destination whose
`standardizedFileURL.path` equals `currentParentURL.standardizedFileURL.path`
(matching the path-comparison style used elsewhere in these views). The root entry
is labelled **"Main Library"**; folders use `lastPathComponent`.

If the computed destination list is empty (a root document and no folders exist),
`MoveToMenu` renders nothing — the caller can place it unconditionally and it
self-hides.

## Wiring

### LibraryView (`docRow`)

Replace the existing inline `Move to Folder` submenu with `MoveToMenu`:

- `currentParentURL` = `summary.url.deletingLastPathComponent()`
- `rootURL` = `storage.documentsURL`
- `folders` = existing `folders` state
- `move` = existing `moveDocument(summary, to:)`

Net behavior change for root docs: the menu now reads "Move to…" instead of
"Move to Folder"; "Main Library" is hidden because the doc is already at root. The
existing `moveDocument(_:to:)` and `folderActionError` alert are reused unchanged.

### FolderContentsView

Non-corrupt doc rows gain a `.contextMenu` containing `MoveToMenu`. This view
needs two additions it lacks today:

1. A `folders` source — load via `storage.listFolders()` in a `.task`/refresh,
   mirroring LibraryView's `refreshFolders()`.
2. Its own error surface — a `folderActionError` `@State` + an alert, mirroring
   LibraryView's "Couldn't update folder" alert.

A local `moveDocument(_:to:)` calls `storage.moveDocument(at:toFolder:)` then
`store.refresh()`. After refresh the moved doc drops out of `docsInFolder`
automatically.

`currentParentURL` for a folder doc is the folder itself (`folderURL`), so
"Main Library" appears and the current folder is excluded.

## Data Flow

```
tap destination
  → storage.moveDocument(at: summary.url, toFolder: dest)
  → store.refresh()
  → moved doc leaves its old list, appears in the new location
```

No navigation change; the user stays on the current screen.

## Error Handling

- Move failures (rare — e.g. an iCloud coordination hiccup) surface through a
  `folderActionError` alert in each view (LibraryView already has one;
  FolderContentsView gains one).
- Name collisions at the destination are **not** errors — the moved file gets the
  existing `(N)` suffix silently, consistent with current move-into-folder
  behavior.

## Testing

New storage unit tests in `DocumentStorageTests.swift` (which already covers
`moveDocument` into a folder via `test_moveDocument_relocatesPDFIntoFolder` and
`test_moveDocument_resolvesCollisionsBySuffix`):

- Move a doc from a folder back to **root** → file lands at root, removed from the
  folder.
- Move a doc from folder A → folder B → file lands in B, removed from A.
- Move to a **root** destination that already has a same-named file → result gets a
  `(N)` suffix; both files exist. (The into-folder collision case is already
  covered.)

Extend the existing into-folder coverage rather than duplicating it.

## Version

- `MARKETING_VERSION` 1.2 → **1.3**
- `CURRENT_PROJECT_VERSION` 7 → **8**

Main-app Debug + Release configs only; test targets stay at their current values.
Set in Xcode (Target → General), as in prior releases.
