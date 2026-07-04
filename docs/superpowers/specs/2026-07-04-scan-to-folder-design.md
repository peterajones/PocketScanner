# Scan to a chosen folder + one level of nesting — design (v2.4 / build 23)

## Summary

Two related additions:

1. **Sub-folders (one level of nesting).** Today folders are flat: root → folder →
   documents. Add **one more level**: root → folder → **sub-folder** → documents.
   Documents may live at any level. Depth is **capped at level 2** (a sub-folder
   cannot contain folders), enforced in the **UI only**.
2. **A destination picker in the Save sheet.** After a scan, `NameDocumentSheet`
   gains a **"Save to"** menu so the scan can be filed into any folder/sub-folder,
   defaulting to the **current context** (the scope you scanned from).

## Motivation

Concrete workflow (ties Pocket Scanner to the user's TaxSlipReader project): a
parent folder like `MyNameTaxDocuments2026` containing type sub-folders (`T3`,
`T4RSP`, `Expenses`), with scans filed into the sub-folders. TaxSlipReader
consumes exactly that structure. Today you'd have to fake it with flat folder
names; this makes the real structure possible and makes filing scans into it
low-friction.

## Depth model & why the cap is cheap

Levels, as array indices from the root: **root [0] → folder [1] → sub-folder [2]**.
Cap = max index **2**. The cap is **UI-enforced only** — the data layer already
supports arbitrary depth:

- `InMemoryLibraryStore.refresh()` walks the tree with `FileManager.enumerator`
  (recursive) and collects every `*.pdf` at any depth.
- `MetadataQueryLibraryStore` scopes to `NSMetadataQueryUbiquitousDocumentsScope`
  with a filename-only `*.pdf` predicate — also every PDF, any depth.
- Views filter to their own scope: `FolderContentsView.docsInFolder` keeps only
  docs whose **immediate parent** equals the folder
  (`url.deletingLastPathComponent().path == folderPath`). A sub-folder's docs are
  therefore excluded from the parent's list — no leakage.

So nesting is a **UI addition, not a data-model change**, and relaxing the cap
later (if ever) is a small UI change with **no data migration**.

## Current state we build on

- Scanning already writes wherever the `DocumentStorage` handed to
  `NameDocumentSheet` points. `LibraryView` passes root storage (→ root);
  `FolderContentsView` passes `DocumentStorage(documentsURL: folderURL)`
  (→ that folder). This scoping trick is reused, not replaced.
- `DocumentStorage` already has `createFolder(named:)`, `listFolders()`,
  `moveDocument(at:toFolder:)`, `renameFolder`, `deleteFolder` — but
  `createFolder`/`listFolders` are **root-only** (they use `documentsURL`).
- The iCloud container is **document-scope-public** with
  `NSUbiquitousContainerSupportedFolderLevels = "Any"` (Info.plist) — so a folder
  tree built manually in the Files app / Finder ("Pocket Scanner" in iCloud Drive)
  is also detected by the app. Manual setup is a valid alternative to in-app
  creation (not a code concern; documented for the user).

## Design

### 1. Storage (small, additive)

Parameterize the two root-only methods by a parent directory (keep the existing
signatures as thin wrappers passing `documentsURL`, to avoid touching call sites
that don't need the parent):

```swift
@discardableResult
func createFolder(named name: String, in parent: URL) throws -> URL
func listFolders(in parent: URL) throws -> [URL]

// existing wrappers:
func createFolder(named name: String) throws -> URL   // = createFolder(named:in: documentsURL)
func listFolders() throws -> [URL]                     // = listFolders(in: documentsURL)
```

Writing a scan to a destination reuses the existing scoping trick — no new write
path: `DocumentStorage(documentsURL: destinationURL).write(pdf, preferredName:)`.

### 2. Folder browsing gains one level (`FolderContentsView`)

- **Sub-folders section:** load this folder's sub-folders via
  `listFolders(in: folderURL)` and show them as tiles/rows above the documents,
  mirroring how `LibraryView` renders root folders. Reuse the shared grid/list +
  folder context-menu components. Tapping a sub-folder pushes a **child
  `FolderContentsView`** (it already navigates via the inherited
  `navigationDestination`; extend so a folder row inside a folder pushes another
  `FolderContentsView`).
- **Folder management inside a folder:** add **"New Sub-folder"** plus rename /
  delete for sub-folders, using the exact idioms already in `LibraryView`
  (New Folder alert, Rename Folder alert, Delete Folder? confirm).
- **Level-2 cap (UI):** compute depth from the root
  (`storage.documentsURL`) to `folderURL`. When depth ≥ 2 (i.e., this view *is* a
  sub-folder), **omit the sub-folders section and the "New Sub-folder" action** —
  a level-2 folder shows documents only. One conditional.

### 3. Scan destination picker (`NameDocumentSheet`)

- Change the sheet's inputs: instead of a single pre-scoped `storage`, it receives
  the **root `DocumentStorage`** and the **current-context directory URL**
  (`defaultDestination`). `LibraryView` passes `defaultDestination = root`;
  `FolderContentsView` passes `defaultDestination = folderURL`.
- Add a **"Save to"** row (a SwiftUI `Menu`, approach A):
  - `Main Library` (root)
  - each top-level folder; a folder that has sub-folders is a **submenu**
    containing the folder itself + its sub-folders.
  - Selected item defaults to `defaultDestination`; the row shows the current
    selection's name.
- On **Save**, write via `DocumentStorage(documentsURL: selectedURL).write(...)`.
- The sheet loads the folder tree in a `.task` (root folders via
  `listFolders()`, sub-folders via `listFolders(in:)` per folder). Small
  libraries → trivial cost.
- **No inline folder creation** in the sheet (library-only creation, per scope).

### 4. Destination-list model (pure, testable)

Add a pure builder (mirroring `MoveDestinations`) that turns
`(root, [topFolder: [subFolder]])` into the menu's structure, so the tree logic
is unit-tested without SwiftUI. Also **extend Move**: `MoveDestinations` should
include sub-folders as destinations; for a sub-folder, label it with parent
context (`Parent ▸ Sub`) to disambiguate same-named sub-folders.

### 5. Search scope — **shallow (unchanged)**

No search changes in this release. In-folder search stays "documents directly in
this folder"; **Main Library search still spans everything** (it's already
recursive), so any slip is always findable from the top. Diving a parent-folder
search into its sub-folders is a deliberate non-goal for v2.4 (easy to add later).

## Non-goals (v2.4)

- Nesting deeper than level 2 (UI cap; data layer already supports it).
- Inline folder creation in the Save sheet.
- Recursive/sub-tree folder search.
- Moving **folders** (only documents move; unchanged).

## Components (files touched)

- `Storage/DocumentStorage.swift` — `createFolder(named:in:)`, `listFolders(in:)` (+ wrappers).
- `Library/FolderContentsView.swift` — sub-folders section + navigation, New Sub-folder / rename / delete, level-2 cap.
- `Capture/NameDocumentSheet.swift` — root storage + `defaultDestination`, "Save to" menu, save-to-selected.
- `Library/LibraryView.swift` — pass `defaultDestination = root` to the sheet; push child `FolderContentsView` for folder rows (already does).
- New: `Library/ScanDestinations.swift` (pure menu-tree builder) + tests.
- `Library/MoveDestinations.swift` — include sub-folders + parent-context labels.

## Testing

Pure unit tests (matching the existing suite style, injected temp dir):

- `DocumentStorage.createFolder(named:in:)` creates a sub-folder inside a folder;
  collision → `(N)`; empty name throws.
- `DocumentStorage.listFolders(in:)` lists only that folder's sub-folders
  (non-recursive), ignores files.
- Depth calculation: root = 0, top folder = 1, sub-folder = 2; cap predicate true
  at ≥ 2.
- `ScanDestinations` builder: root + folders + sub-folders produce the expected
  menu structure; default selection resolves to the passed current-context URL.
- `MoveDestinations` includes sub-folders and excludes the doc's current parent;
  parent-context labels.

On-device smoke test (at implementation time): create parent folder → New
Sub-folder `T3` → confirm level-2 has no "New Sub-folder" → scan from root and
pick `Taxes ▸ T3` → confirm it lands in `T3` → scan from inside `T3` → confirm
default is `T3` → move a doc into a sub-folder.

## Rollout

- Ships as **v2.4 (23)** — build 23 is the natural next after 22 (marketing 2.4 vs
  build 23 no longer collide-confuse).
- Update `FutureEnhancements.md` (mark scan-to-folder shipped; note nesting is
  level-2, UI-capped).
- Bump `MARKETING_VERSION` 2.3 → 2.4 and `CURRENT_PROJECT_VERSION` 22 → 23 at
  archive.
