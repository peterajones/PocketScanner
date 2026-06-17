# Swipe-to-Delete Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a left-swipe Delete on document and folder rows (List), plus a Delete item in the document context menu (Grid/long-press parity), with a confirmation for documents.

**Architecture:** Pure SwiftUI wiring — no new logic. Each view gets a `docBeingDeleted` state + a "Delete this document?" `.confirmationDialog` that calls the existing `storage.delete(at:)` + `store.refresh()`. Swipe actions and a context-menu item set that state; folder swipe reuses the existing `folderBeingDeleted` confirm. `allowsFullSwipe: false`; corrupt-doc delete unchanged.

**Tech Stack:** Swift, SwiftUI (`.swipeActions`, `.confirmationDialog`), XCTest (regression only).

**Spec:** `docs/superpowers/specs/2026-06-17-swipe-to-delete-design.md`

---

## File Structure

- Modify: `DocumentScanner/DocumentScanner/Library/LibraryView.swift` — doc-delete state + confirm, swipe on doc & folder rows, Delete in doc context menu
- Modify: `DocumentScanner/DocumentScanner/Library/FolderContentsView.swift` — same for docs (no folder rows here)

No new pure logic ⇒ no new unit tests; the delete + refresh path is already covered by storage/store tests (incl. `LibraryRefreshAfterWriteTests`). Verified by build + the full suite (no regressions) + on-device.

Build / test commands:
```bash
cd DocumentScanner && xcodebuild build \
  -scheme DocumentScanner -destination 'platform=iOS Simulator,name=iPhone 17'
cd DocumentScanner && xcodebuild test \
  -scheme DocumentScanner -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:DocumentScannerTests
```

> SourceKit may show "cannot find … in scope" / "No such module" for these files — stale-index
> artifacts. `xcodebuild` is the source of truth.

---

## Task 1: LibraryView — swipe + menu delete for docs & folders

**Files:**
- Modify: `DocumentScanner/DocumentScanner/Library/LibraryView.swift`

- [ ] **Step 1: Add the delete state**

Add this `@State` next to the other delete state (e.g. after `@State private var folderBeingDeleted: URL?`):

```swift
    @State private var docBeingDeleted: DocumentSummary?
```

- [ ] **Step 2: Add the document-delete confirmation dialog**

Immediately after the existing `.alert("Couldn't update folder", …) { … }` block (the one bound
to `folderActionError`), add:

```swift
            .confirmationDialog(
                "Delete this document?",
                isPresented: Binding(
                    get: { docBeingDeleted != nil },
                    set: { if !$0 { docBeingDeleted = nil } }
                ),
                presenting: docBeingDeleted
            ) { summary in
                Button("Delete", role: .destructive) {
                    try? storage.delete(at: summary.url)
                    store.refresh()
                }
                Button("Cancel", role: .cancel) {}
            } message: { summary in
                Text("This will permanently remove \"\(summary.displayName).pdf\".")
            }
```

- [ ] **Step 3: Add Delete to the document context menu (non-corrupt branch)**

Replace the whole `docContextMenu(_:)` method:

```swift
    @ViewBuilder
    private func docContextMenu(_ summary: DocumentSummary) -> some View {
        if summary.isCorrupt {
            Button(role: .destructive) {
                try? storage.delete(at: summary.url)
                store.refresh()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        } else {
            if showFolders {
                MoveToMenu(
                    currentParent: summary.url.deletingLastPathComponent(),
                    root: storage.documentsURL,
                    folders: folders,
                    move: { moveDocument(summary, to: $0) }
                )
            }
            Button(role: .destructive) {
                docBeingDeleted = summary
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
```

- [ ] **Step 4: Add the swipe action to document rows**

Replace the whole `docRow(_:)` method:

```swift
    @ViewBuilder
    private func docRow(_ summary: DocumentSummary) -> some View {
        if summary.isCorrupt {
            DocumentRow(summary: summary)
                .contextMenu { docContextMenu(summary) }
        } else {
            NavigationLink(value: summary) {
                DocumentRow(summary: summary)
            }
            .contextMenu { docContextMenu(summary) }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                    docBeingDeleted = summary
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
```

- [ ] **Step 5: Add the swipe action to folder rows**

In `listBody`, the folder `ForEach` currently ends each row with `.contextMenu { folderContextMenu(folderURL) }`. Add a swipe action right after it:

```swift
                    ForEach(folders, id: \.self) { folderURL in
                        NavigationLink(value: folderURL) {
                            folderRow(folderURL)
                        }
                        .accessibilityIdentifier("Library.Folder.\(folderURL.lastPathComponent)")
                        .contextMenu { folderContextMenu(folderURL) }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                folderBeingDeleted = folderURL
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
```

- [ ] **Step 6: Build**

```bash
cd DocumentScanner && xcodebuild build \
  -scheme DocumentScanner -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 7: Commit**

```bash
git add DocumentScanner/DocumentScanner/Library/LibraryView.swift
git commit -m "feat: swipe-to-delete + menu delete for docs and folders (library root)"
```

---

## Task 2: FolderContentsView — swipe + menu delete for docs

**Files:**
- Modify: `DocumentScanner/DocumentScanner/Library/FolderContentsView.swift`

- [ ] **Step 1: Add the delete state**

Add next to the other `@State` properties (e.g. after `@State private var folderActionError: String?`):

```swift
    @State private var docBeingDeleted: DocumentSummary?
```

- [ ] **Step 2: Add the document-delete confirmation dialog**

Immediately after the existing `.alert("Couldn't move document", …) { … }` block, add:

```swift
        .confirmationDialog(
            "Delete this document?",
            isPresented: Binding(
                get: { docBeingDeleted != nil },
                set: { if !$0 { docBeingDeleted = nil } }
            ),
            presenting: docBeingDeleted
        ) { summary in
            Button("Delete", role: .destructive) {
                try? storage.delete(at: summary.url)
                store.refresh()
            }
            Button("Cancel", role: .cancel) {}
        } message: { summary in
            Text("This will permanently remove \"\(summary.displayName).pdf\".")
        }
```

- [ ] **Step 3: Add Delete to the document context menu (non-corrupt branch)**

Replace the whole `docContextMenu(_:)` method:

```swift
    @ViewBuilder
    private func docContextMenu(_ summary: DocumentSummary) -> some View {
        if summary.isCorrupt {
            Button(role: .destructive) {
                try? storage.delete(at: summary.url)
                store.refresh()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        } else {
            MoveToMenu(
                currentParent: folderURL,
                root: storage.documentsURL,
                folders: folders,
                move: { moveDocument(summary, to: $0) }
            )
            Button(role: .destructive) {
                docBeingDeleted = summary
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
```

- [ ] **Step 4: Add the swipe action to document rows**

Replace the whole `docRow(_:)` method:

```swift
    @ViewBuilder
    private func docRow(_ summary: DocumentSummary) -> some View {
        if summary.isCorrupt {
            DocumentRow(summary: summary)
                .contextMenu { docContextMenu(summary) }
        } else {
            NavigationLink(value: summary) {
                DocumentRow(summary: summary)
            }
            .contextMenu { docContextMenu(summary) }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                    docBeingDeleted = summary
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
```

- [ ] **Step 5: Build + full unit suite (no regressions)**

```bash
cd DocumentScanner && xcodebuild build \
  -scheme DocumentScanner -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -5
cd DocumentScanner && xcodebuild test \
  -scheme DocumentScanner -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:DocumentScannerTests 2>&1 | grep -E "\*\* TEST|failed" | tail -5
```
Expected: `** BUILD SUCCEEDED **` and `** TEST SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add DocumentScanner/DocumentScanner/Library/FolderContentsView.swift
git commit -m "feat: swipe-to-delete + menu delete for docs inside folders"
```

---

## Task 3: On-device verification

**Files:** none (manual).

- [ ] **Step 1: Document swipe (List)**

Library in **List** mode → **swipe a document left** → red **Delete** appears → tap it → the
**"Delete this document?"** confirm shows → **Delete** → the row disappears; **Cancel** keeps it.
Confirm a **full swipe does NOT delete** (it stops at the button).

- [ ] **Step 2: Folder swipe (List)**

Swipe a **folder** left → **Delete** → your existing **"Delete Folder?"** confirm appears (with
the non-empty warning if it has documents) → deletes on confirm.

- [ ] **Step 3: Context-menu Delete (Grid + long-press)**

Switch to **Grid** → long-press a document tile → **Delete** → same confirm → deletes. Repeat by
long-pressing a row in **List**.

- [ ] **Step 4: Inside a folder**

Open a folder → swipe a document → Delete → confirm → gone; and long-press a tile in the folder's
Grid → Delete works too.

- [ ] **Step 5: Corrupt doc unchanged**

If you have a 🚫 corrupt row, confirm its context-menu **Delete** still deletes **immediately**
(no confirm) — unchanged.

---

## Done

After Task 3: documents and folders can be deleted with a left-swipe (List) or the document
context menu (Grid + long-press), each with the appropriate confirmation; full-swipe is disabled;
corrupt-doc delete is unchanged. Reuses the existing `storage.delete` + `store.refresh` path.
Remove the "Swipe to delete" entry from `docs/FutureEnhancements.md` on merge. Ships in the next
release after v1.8.
