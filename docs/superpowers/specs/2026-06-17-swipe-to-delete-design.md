# Spec: Swipe-to-delete documents and folders

**Date:** 2026-06-17
**Status:** Approved (design) — ready for implementation plan
**Roadmap entry:** `docs/FutureEnhancements.md` → *Library → Swipe to delete*
**Target release:** next release after v1.8

## Goal

Make deleting library items fast: a **left-swipe Delete** on document and folder rows
(List mode), plus a **Delete** item in the document context menu (Grid tiles + long-press
parity). Replaces the current 3-tap path (tap doc → ⋯ → Remove → confirm) for clearing
unneeded scans. Deletes stay **permanent and confirmed** (the app has no trash/undo).

## Scope decisions (from brainstorming)

- **Swipe reveals a red Delete button → tap → confirm → delete.** `allowsFullSwipe: false`
  so a stray full-swipe can't delete a scan by accident; an explicit tap **and** a
  confirmation are both required.
- **Documents:** a new "Delete this document?" confirmation at the library level (the
  existing one lives only in the viewer). On confirm: `storage.delete(at:)` + `store.refresh()`.
- **Folders:** reuse the **existing** "Delete Folder?" confirmation (which already warns
  when the folder isn't empty) and `deleteFolder()` flow — the swipe just triggers it.
- **Grid + long-press parity:** add a destructive **Delete** to the *document* context menu
  (non-corrupt branch), so Grid tiles and List long-press can delete too.
- **Corrupt documents: unchanged.** Their existing immediate, no-confirm context-menu
  Delete stays as-is (rare edge case; worst case is manual removal from iCloud).
- **Both library screens:** `LibraryView` (root: documents + folders) and
  `FolderContentsView` (documents inside a folder). Folders only exist at the root, so the
  **folder swipe is `LibraryView`-only**.

## Non-goals

- Trash / "Recently Deleted" / undo — deletes remain permanent.
- Full-swipe-to-delete.
- Grid-tile swipe (SwiftUI `.swipeActions` is List-only; Grid uses the context menu).
- Changing the viewer's existing document-delete path or the corrupt-doc delete.

## Architecture / components

### `LibraryView`
- New state: `@State private var docBeingDeleted: DocumentSummary?`.
- New `.confirmationDialog("Delete this document?", …)` bound to `docBeingDeleted`, with a
  destructive **Delete** that runs `try? storage.delete(at: summary.url)` + `store.refresh()`
  and a message naming the file (matching the viewer's wording/pattern). `try?` matches the
  app's existing delete paths (viewer + corrupt-doc both swallow the error).
- `listBody`:
  - **doc row** → `.swipeActions(edge: .trailing, allowsFullSwipe: false)` with a
    destructive Delete that sets `docBeingDeleted = summary`.
  - **folder row** → `.swipeActions(edge: .trailing, allowsFullSwipe: false)` with a
    destructive Delete that sets `folderBeingDeleted = url` (reuses the existing confirm).
- `docContextMenu` (the **non-corrupt** branch): add a destructive **Delete** that sets
  `docBeingDeleted = summary`. The corrupt branch is left exactly as it is.

### `FolderContentsView`
- Same `docBeingDeleted` state + "Delete this document?" confirmation.
- Doc row → the same trailing `.swipeActions(allowsFullSwipe: false)` Delete.
- `docContextMenu` → add the same destructive **Delete** (non-corrupt branch).
- (No folder rows here — folders are root-only.)

## Data flow

```
swipe Delete / menu Delete (document)
  → docBeingDeleted = summary
  → "Delete this document?" confirm
  → try? storage.delete(at: summary.url) ; store.refresh()
  → row disappears (store-driven re-render)

swipe Delete (folder)  → folderBeingDeleted = url → existing "Delete Folder?" → deleteFolder()
```

The local-mode library updates correctly because these deletes call `store.refresh()` from
the **foreground** library view (the same path manual pull-to-refresh and the existing
deletes use — see the page-extraction refresh note).

## Error handling

- `storage.delete` throwing → swallowed via `try?`, consistent with the app's existing
  document-delete paths. (Delete failures are rare; the row simply stays.)
- Guard `docBeingDeleted != nil` in the confirm action.

## Testing

- The delete + refresh logic is **existing** and already covered by storage/store tests
  (incl. `LibraryRefreshAfterWriteTests` for the refresh boundary). No new pure logic is
  introduced.
- The new surface is SwiftUI gesture/menu + confirmation wiring — not meaningfully
  unit-testable; verified **on device** (swipe a doc → Delete → confirm → gone; swipe a
  folder → existing confirm; Grid long-press → Delete; full-swipe does nothing).

## Deliverables

- `LibraryView`: `docBeingDeleted` state, doc-delete confirm, swipe actions (doc + folder),
  context-menu Delete (doc, non-corrupt).
- `FolderContentsView`: `docBeingDeleted` state, doc-delete confirm, swipe action (doc),
  context-menu Delete (doc, non-corrupt).
- Spec + plan under `docs/superpowers/`.
