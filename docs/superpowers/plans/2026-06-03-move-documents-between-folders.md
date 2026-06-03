# Move Documents Between Folders Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a unified "Move to…" submenu to document context menus so a doc can move folder→folder, folder→main library, and main library→folder.

**Architecture:** No storage changes — `DocumentStorage.moveDocument(at:toFolder:)` already moves a file into any directory (including the root). The new work is a pure destination-list helper (`MoveDestinations.list`), a small reusable SwiftUI `MoveToMenu` view that renders it, and wiring that view into `LibraryView.docRow` (replacing the existing `Move to Folder` submenu) and `FolderContentsView` (which has no move action or error alert today).

**Tech Stack:** Swift, SwiftUI, XCTest, PDFKit, xcodebuild.

---

## Conventions for this plan

- **Run tests with** (from repo root):

  ```bash
  cd DocumentScanner && xcodebuild test \
    -scheme DocumentScanner \
    -destination 'platform=iOS Simulator,name=iPhone 16' \
    -only-testing:DocumentScannerTests/<ClassName>
  ```

  If `iPhone 16` is not an installed simulator, list options with
  `xcrun simctl list devices available` and substitute a name. The full suite is
  just the command above without `-only-testing`.

- **SourceKit/LSP false positives:** "No such module 'UIKit'/'XCTest'" and
  "Cannot find type" diagnostics appear constantly in this project and are
  spurious. `xcodebuild` is the source of truth — never treat an editor
  diagnostic as a real error here.

- New Swift files must be added to the Xcode project. After creating a file,
  confirm it compiles via `xcodebuild` (a missing target membership shows up as a
  link/compile failure). The two new files (`MoveDestinations.swift`,
  `MoveToMenu.swift`) go in the `DocumentScanner/DocumentScanner/Library/` group;
  the test file goes in the `DocumentScannerTests` group.

---

## File Structure

- **Create** `DocumentScanner/DocumentScanner/Library/MoveDestinations.swift` —
  pure value type `MoveDestination` + `enum MoveDestinations` with the static
  `list(currentParent:root:folders:)` function. Testable, no SwiftUI.
- **Create** `DocumentScanner/DocumentScanner/Library/MoveToMenu.swift` — the
  reusable `MoveToMenu` SwiftUI view that renders the destinations as a `Menu`.
- **Create** `DocumentScanner/DocumentScannerTests/MoveDestinationsTests.swift` —
  unit tests for the helper.
- **Modify** `DocumentScanner/DocumentScannerTests/DocumentStorageTests.swift` —
  add move-to-root and folder→folder coverage.
- **Modify** `DocumentScanner/DocumentScanner/Library/LibraryView.swift` —
  replace the inline `Move to Folder` submenu in `docRow` with `MoveToMenu`.
- **Modify** `DocumentScanner/DocumentScanner/Library/FolderContentsView.swift` —
  add `folders` state, a `folderActionError` alert, a `moveDocument` helper, and a
  `.contextMenu` with `MoveToMenu` on doc rows.

---

## Task 1: Confirm storage supports move-to-root and folder→folder

The production behavior already exists; these tests prove the root-destination and
folder→folder cases work and guard against regressions. They are expected to
**pass without any production change** (this is the spec's "confirm it works"
step).

**Files:**
- Test: `DocumentScanner/DocumentScannerTests/DocumentStorageTests.swift` (add three tests after `test_moveDocument_resolvesCollisionsBySuffix`, around line 133)

- [ ] **Step 1: Add the three tests**

Insert after the closing brace of `test_moveDocument_resolvesCollisionsBySuffix`:

```swift
    func test_moveDocument_relocatesFromFolderBackToRoot() throws {
        let storage = DocumentStorage(documentsURL: tempDir)
        let folder = try storage.createFolder(named: "Receipts")
        let docURL = try storage.write(makeSinglePagePDF(), preferredName: "Receipt")
        let inFolder = try storage.moveDocument(at: docURL, toFolder: folder)

        // Move it back out to the root documents directory.
        let backAtRoot = try storage.moveDocument(at: inFolder, toFolder: tempDir)

        XCTAssertEqual(backAtRoot.deletingLastPathComponent().standardizedFileURL.path,
                       tempDir.standardizedFileURL.path)
        XCTAssertEqual(backAtRoot.lastPathComponent, "Receipt.pdf")
        XCTAssertFalse(FileManager.default.fileExists(atPath: inFolder.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: backAtRoot.path))
    }

    func test_moveDocument_relocatesBetweenFolders() throws {
        let storage = DocumentStorage(documentsURL: tempDir)
        let folderA = try storage.createFolder(named: "A")
        let folderB = try storage.createFolder(named: "B")
        let docURL = try storage.write(makeSinglePagePDF(), preferredName: "Receipt")
        let inA = try storage.moveDocument(at: docURL, toFolder: folderA)

        let inB = try storage.moveDocument(at: inA, toFolder: folderB)

        XCTAssertEqual(inB.deletingLastPathComponent(), folderB)
        XCTAssertEqual(inB.lastPathComponent, "Receipt.pdf")
        XCTAssertFalse(FileManager.default.fileExists(atPath: inA.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: inB.path))
    }

    func test_moveDocument_toRootResolvesCollisionBySuffix() throws {
        let storage = DocumentStorage(documentsURL: tempDir)
        let folder = try storage.createFolder(named: "Receipts")
        // A doc already living at root with the name we'll collide with.
        _ = try storage.write(makeSinglePagePDF(), preferredName: "Receipt")
        // Another doc with the same name, moved into a folder then back to root.
        let second = try storage.write(makeSinglePagePDF(), preferredName: "Receipt")
        let inFolder = try storage.moveDocument(at: second, toFolder: folder)

        let backAtRoot = try storage.moveDocument(at: inFolder, toFolder: tempDir)

        XCTAssertEqual(backAtRoot.lastPathComponent, "Receipt (2).pdf")
        XCTAssertTrue(FileManager.default.fileExists(atPath: backAtRoot.path))
    }
```

- [ ] **Step 2: Run the storage tests**

Run:
```bash
cd DocumentScanner && xcodebuild test \
  -scheme DocumentScanner \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:DocumentScannerTests/DocumentStorageTests
```
Expected: PASS, including the three new tests. (No production change needed — if
any fail, stop and investigate; the move logic may not handle the root path as
assumed.)

- [ ] **Step 3: Commit**

```bash
git add DocumentScanner/DocumentScannerTests/DocumentStorageTests.swift
git commit -m "test: cover move-to-root and folder-to-folder document moves"
```

---

## Task 2: `MoveDestinations` helper (pure, testable)

**Files:**
- Create: `DocumentScanner/DocumentScanner/Library/MoveDestinations.swift`
- Test: `DocumentScanner/DocumentScannerTests/MoveDestinationsTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `DocumentScanner/DocumentScannerTests/MoveDestinationsTests.swift`:

```swift
import XCTest
@testable import DocumentScanner

final class MoveDestinationsTests: XCTestCase {

    private let root = URL(fileURLWithPath: "/docs", isDirectory: true)
    private func folder(_ name: String) -> URL {
        URL(fileURLWithPath: "/docs/\(name)", isDirectory: true)
    }

    func test_docInFolder_offersMainLibraryAndOtherFolders() {
        let folders = [folder("A"), folder("B"), folder("C")]
        let result = MoveDestinations.list(
            currentParent: folder("B"), root: root, folders: folders
        )
        XCTAssertEqual(result.map(\.name), ["Main Library", "A", "C"])
        XCTAssertEqual(result.first?.url.standardizedFileURL.path,
                       root.standardizedFileURL.path)
    }

    func test_docAtRoot_hidesMainLibraryAndListsAllFolders() {
        let folders = [folder("A"), folder("B")]
        let result = MoveDestinations.list(
            currentParent: root, root: root, folders: folders
        )
        XCTAssertEqual(result.map(\.name), ["A", "B"])
    }

    func test_docAtRoot_withNoFolders_isEmpty() {
        let result = MoveDestinations.list(
            currentParent: root, root: root, folders: []
        )
        XCTAssertTrue(result.isEmpty)
    }

    func test_pathComparisonIgnoresTrailingSlashDifferences() {
        // currentParent built without the isDirectory flag should still match.
        let bNoSlash = URL(fileURLWithPath: "/docs/B")
        let result = MoveDestinations.list(
            currentParent: bNoSlash, root: root, folders: [folder("A"), folder("B")]
        )
        XCTAssertEqual(result.map(\.name), ["Main Library", "A"])
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run:
```bash
cd DocumentScanner && xcodebuild test \
  -scheme DocumentScanner \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:DocumentScannerTests/MoveDestinationsTests
```
Expected: FAIL to compile — "Cannot find 'MoveDestinations' in scope".

- [ ] **Step 3: Write the implementation**

Create `DocumentScanner/DocumentScanner/Library/MoveDestinations.swift`:

```swift
import Foundation

/// A place a document can be moved to: either the root library or a folder.
struct MoveDestination: Identifiable, Hashable {
    /// The destination *directory* URL (root documents dir or a folder).
    let url: URL
    /// Display label ("Main Library" for root, folder name otherwise).
    let name: String
    var id: URL { url }
}

/// Pure logic for building the "Move to…" destination list. Kept free of
/// SwiftUI so it can be unit-tested directly.
enum MoveDestinations {
    /// Destinations for a document currently living in `currentParent`.
    ///
    /// - "Main Library" (the root) is included only when the doc isn't already
    ///   at root.
    /// - Every folder is included except the one the doc is already in.
    /// - Comparison uses `standardizedFileURL.path`, matching how folder paths
    ///   are compared elsewhere in the library views (and tolerant of trailing-
    ///   slash / `isDirectory` differences).
    static func list(currentParent: URL, root: URL, folders: [URL]) -> [MoveDestination] {
        let currentPath = currentParent.standardizedFileURL.path
        var result: [MoveDestination] = []
        if root.standardizedFileURL.path != currentPath {
            result.append(MoveDestination(url: root, name: "Main Library"))
        }
        for folder in folders where folder.standardizedFileURL.path != currentPath {
            result.append(MoveDestination(url: folder, name: folder.lastPathComponent))
        }
        return result
    }
}
```

- [ ] **Step 4: Run to verify it passes**

Run:
```bash
cd DocumentScanner && xcodebuild test \
  -scheme DocumentScanner \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:DocumentScannerTests/MoveDestinationsTests
```
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add DocumentScanner/DocumentScanner/Library/MoveDestinations.swift \
        DocumentScanner/DocumentScannerTests/MoveDestinationsTests.swift
git commit -m "feat: add MoveDestinations helper for move-to picker"
```

---

## Task 3: `MoveToMenu` SwiftUI view

**Files:**
- Create: `DocumentScanner/DocumentScanner/Library/MoveToMenu.swift`

No unit test — this is a thin SwiftUI wrapper over the already-tested
`MoveDestinations.list`. It is exercised by the manual smoke test in Task 6.

- [ ] **Step 1: Write the view**

Create `DocumentScanner/DocumentScanner/Library/MoveToMenu.swift`:

```swift
import SwiftUI

/// A "Move to…" submenu for a document's context menu. Lists the valid
/// destinations (root + folders, current location excluded) and calls `move`
/// with the chosen destination directory URL. Renders nothing when there are
/// no destinations, so callers can place it unconditionally.
struct MoveToMenu: View {
    /// The document's current containing directory.
    let currentParent: URL
    /// The root documents directory (`storage.documentsURL`).
    let root: URL
    /// Root-level folders.
    let folders: [URL]
    /// Invoked with the chosen destination directory URL.
    let move: (URL) -> Void

    var body: some View {
        let destinations = MoveDestinations.list(
            currentParent: currentParent, root: root, folders: folders
        )
        if !destinations.isEmpty {
            Menu {
                ForEach(destinations) { dest in
                    Button(dest.name) { move(dest.url) }
                }
            } label: {
                Label("Move to…", systemImage: "folder")
            }
        }
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run:
```bash
cd DocumentScanner && xcodebuild build \
  -scheme DocumentScanner \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```
Expected: BUILD SUCCEEDED. (If the file isn't a target member you'll get
"Cannot find 'MoveToMenu' in scope" only once it's referenced — it's referenced
in Tasks 4–5, so a clean build here just confirms the file compiles.)

- [ ] **Step 3: Commit**

```bash
git add DocumentScanner/DocumentScanner/Library/MoveToMenu.swift
git commit -m "feat: add reusable MoveToMenu context-menu view"
```

---

## Task 4: Wire `MoveToMenu` into `LibraryView.docRow`

Replaces the existing `Move to Folder` submenu. Behavior for root docs is
unchanged except the label becomes "Move to…" and the menu self-hides when no
folders exist.

**Files:**
- Modify: `DocumentScanner/DocumentScanner/Library/LibraryView.swift:243-253`

- [ ] **Step 1: Replace the context menu**

Find this block in `docRow(_:)`:

```swift
            .contextMenu {
                if showFolders && !folders.isEmpty {
                    Menu("Move to Folder") {
                        ForEach(folders, id: \.self) { folder in
                            Button(folder.lastPathComponent) {
                                moveDocument(summary, to: folder)
                            }
                        }
                    }
                }
            }
```

Replace it with:

```swift
            .contextMenu {
                if showFolders {
                    MoveToMenu(
                        currentParent: summary.url.deletingLastPathComponent(),
                        root: storage.documentsURL,
                        folders: folders,
                        move: { moveDocument(summary, to: $0) }
                    )
                }
            }
```

(`moveDocument(_:to:)` already exists at `LibraryView.swift:354` and already
surfaces failures via the `folderActionError` alert — no change needed there.)

- [ ] **Step 2: Build to verify it compiles**

Run:
```bash
cd DocumentScanner && xcodebuild build \
  -scheme DocumentScanner \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add DocumentScanner/DocumentScanner/Library/LibraryView.swift
git commit -m "feat: use MoveToMenu in library doc context menu"
```

---

## Task 5: Wire `MoveToMenu` into `FolderContentsView`

This view has no move action and no error alert today. Add `folders` state, an
error alert, a `moveDocument` helper, and the context menu on doc rows.

**Files:**
- Modify: `DocumentScanner/DocumentScanner/Library/FolderContentsView.swift`

- [ ] **Step 1: Add state for folders and errors**

Find (around line 18-21):

```swift
    @State private var searchText = ""
    @State private var showingCapture = false
    @State private var showingCameraDenied = false
    @State private var nameSheet: NameSheetContext?
```

Add two properties below them:

```swift
    @State private var searchText = ""
    @State private var showingCapture = false
    @State private var showingCameraDenied = false
    @State private var nameSheet: NameSheetContext?
    @State private var folders: [URL] = []
    @State private var folderActionError: String?
```

- [ ] **Step 2: Add the context menu to non-corrupt doc rows**

Find (around line 53-57):

```swift
                    } else {
                        NavigationLink(value: summary) {
                            DocumentRow(summary: summary)
                        }
                    }
```

Replace with:

```swift
                    } else {
                        NavigationLink(value: summary) {
                            DocumentRow(summary: summary)
                        }
                        .contextMenu {
                            MoveToMenu(
                                currentParent: folderURL,
                                root: storage.documentsURL,
                                folders: folders,
                                move: { moveDocument(summary, to: $0) }
                            )
                        }
                    }
```

- [ ] **Step 3: Load folders and add the error alert**

Find the `.navigationTitle(folderURL.lastPathComponent)` line (around line 63).
Immediately *after* it, add a `.task` to load folders and an `.alert` for
errors (modifier order doesn't matter — they all attach to the same `Group`):

```swift
        .navigationTitle(folderURL.lastPathComponent)
        .task { refreshFolders() }
        .alert("Couldn't move document",
               isPresented: Binding(
                get: { folderActionError != nil },
                set: { _ in folderActionError = nil }
               )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(folderActionError ?? "")
        }
```

Also refresh folders when the list is pulled to refresh. Find:

```swift
                .searchable(text: $searchText, prompt: "Search this folder")
                .refreshable { store.refresh() }
```

Replace the `.refreshable` with:

```swift
                .searchable(text: $searchText, prompt: "Search this folder")
                .refreshable {
                    store.refresh()
                    refreshFolders()
                }
```

- [ ] **Step 4: Add the `refreshFolders` and `moveDocument` helpers**

Find the `triggerScan()` function (around line 118) and add these two methods
right before it:

```swift
    private func refreshFolders() {
        folders = (try? storage.listFolders())?
            .sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) ?? []
    }

    private func moveDocument(_ summary: DocumentSummary, to destination: URL) {
        do {
            _ = try storage.moveDocument(at: summary.url, toFolder: destination)
            store.refresh()
        } catch {
            folderActionError = error.localizedDescription
        }
    }

```

- [ ] **Step 5: Build to verify it compiles**

Run:
```bash
cd DocumentScanner && xcodebuild build \
  -scheme DocumentScanner \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 6: Run the full test suite**

Run:
```bash
cd DocumentScanner && xcodebuild test \
  -scheme DocumentScanner \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```
Expected: PASS (all tests, including Tasks 1–2 additions).

- [ ] **Step 7: Commit**

```bash
git add DocumentScanner/DocumentScanner/Library/FolderContentsView.swift
git commit -m "feat: move documents out of and between folders"
```

---

## Task 6: Version bump + manual smoke test

**Files:**
- Modify: `DocumentScanner/DocumentScanner.xcodeproj/project.pbxproj` (via Xcode UI)

- [ ] **Step 1: Bump version (manual, in Xcode)**

In Xcode → target **DocumentScanner** → General: set **Version** to `1.3` and
**Build** to `8`. This updates `MARKETING_VERSION` (1.2 → 1.3) and
`CURRENT_PROJECT_VERSION` (7 → 8) for the main-app Debug + Release configs. Leave
the test targets at their current values.

Verify with:
```bash
grep -n "MARKETING_VERSION\|CURRENT_PROJECT_VERSION" \
  DocumentScanner/DocumentScanner.xcodeproj/project.pbxproj
```
Expected: main-app configs show `MARKETING_VERSION = 1.3;` and
`CURRENT_PROJECT_VERSION = 8;`.

- [ ] **Step 2: Manual smoke test (simulator or device)**

Deferred to the user per project convention (the user verifies UI on a real
device/simulator). Confirm:
  1. Long-press a doc **inside a folder** → "Move to…" → "Main Library" → doc
     leaves the folder and appears in the main list.
  2. Long-press a doc inside folder A → "Move to…" → folder B → doc moves to B,
     gone from A.
  3. Long-press a **root** doc → "Move to…" → a folder → doc moves in (the
     pre-existing behavior, now relabelled). "Main Library" is not offered.
  4. A root doc with no folders shows no "Move to…" entry.

- [ ] **Step 3: Commit the version bump**

```bash
git add DocumentScanner/DocumentScanner.xcodeproj/project.pbxproj
git commit -m "chore: bump to v1.3 (8)"
```

---

## Done

After Task 6, the feature is complete: documents can move folder→folder,
folder→main library, and main library→folder from both list context menus, the
full test suite passes, and the version is bumped to v1.3 (8). Next steps
(outside this plan): push, archive, upload, submit for review — following the same
flow as v1.2.
