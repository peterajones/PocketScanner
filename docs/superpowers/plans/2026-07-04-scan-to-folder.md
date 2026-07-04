# Scan to a Chosen Folder + One Level of Nesting — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add sub-folders (one level of nesting, level-2 cap enforced in the UI) and a "Save to" destination picker in the scan Save sheet defaulting to the current context.

**Architecture:** The data layer is already recursive (both stores enumerate every PDF at any depth; views filter by immediate parent), so this is a UI + storage-parameterization change, not a data-model change. Pure helpers (`FolderPaths`, `ScanDestinations`, extended `MoveDestinations`) are unit-tested; SwiftUI wiring in `FolderContentsView` mirrors `LibraryView`'s existing folder rendering.

**Tech Stack:** Swift, SwiftUI, PDFKit, XCTest. iOS app `DocumentScanner`.

**Spec:** `docs/superpowers/specs/2026-07-04-scan-to-folder-design.md`

---

## File Structure

- `DocumentScanner/DocumentScanner/Storage/DocumentStorage.swift` — parameterize `createFolder` / `listFolders` by parent.
- `DocumentScanner/DocumentScanner/Library/FolderPaths.swift` — **new** pure helpers: `level(of:root:)`, `label(for:root:)`.
- `DocumentScanner/DocumentScanner/Library/ScanDestinations.swift` — **new** pure builder for the "Save to" menu tree.
- `DocumentScanner/DocumentScanner/Library/MoveDestinations.swift` — include sub-folders + parent-context labels.
- `DocumentScanner/DocumentScanner/Capture/NameDocumentSheet.swift` — root storage + `defaultDestination` + "Save to" menu.
- `DocumentScanner/DocumentScanner/Library/FolderContentsView.swift` — sub-folders section, navigation, New Sub-folder / rename / delete, level-2 cap.
- `DocumentScanner/DocumentScanner/Library/LibraryView.swift` — pass `defaultDestination` to the sheet; pass sub-folders to Move.
- Tests in `DocumentScanner/DocumentScannerTests/`.

Reference patterns to mirror (read these before the SwiftUI tasks):
- `LibraryView.swift:70-78` — `navigationDestination(for: URL.self)` (inherited by child views; sub-folder navigation reuses it).
- `LibraryView.swift:94-120` — the `+` menu ("Scan Document" / "New Folder").
- `LibraryView.swift:151-185` — New Folder / Rename Folder / Delete Folder? alerts.
- `LibraryView.swift:242-254` — `folderContextMenu(_:)`.
- `LibraryView.swift:481-535` — `createFolder()` / `renameFolder()` / `deleteFolder()`.

Full suite: `./scripts/test.sh`. Per-test runs use the `xcodebuild` invocation in each task.

---

## Task 1: Storage — create/list folders inside a parent

**Files:**
- Modify: `DocumentScanner/DocumentScanner/Storage/DocumentStorage.swift`
- Test: `DocumentScanner/DocumentScannerTests/DocumentStorageTests.swift`

- [ ] **Step 1: Write failing tests**

Add to `DocumentStorageTests` (uses `tempDir`, `makeSinglePagePDF()` already present):

```swift
func test_createFolder_inParent_createsNestedSubfolder() throws {
    let storage = DocumentStorage(documentsURL: tempDir)
    let parent = try storage.createFolder(named: "Taxes2026")
    let sub = try storage.createFolder(named: "T3", in: parent)
    var isDir: ObjCBool = false
    XCTAssertTrue(FileManager.default.fileExists(atPath: sub.path, isDirectory: &isDir))
    XCTAssertTrue(isDir.boolValue)
    XCTAssertEqual(sub.deletingLastPathComponent().standardizedFileURL.path,
                   parent.standardizedFileURL.path)
    XCTAssertEqual(sub.lastPathComponent, "T3")
}

func test_listFolders_inParent_listsOnlyThatParentsSubfolders() throws {
    let storage = DocumentStorage(documentsURL: tempDir)
    let a = try storage.createFolder(named: "A")
    let b = try storage.createFolder(named: "B")
    _ = try storage.createFolder(named: "A1", in: a)
    _ = try storage.createFolder(named: "A2", in: a)
    _ = try storage.createFolder(named: "B1", in: b)
    let subsOfA = try storage.listFolders(in: a).map(\.lastPathComponent)
    XCTAssertEqual(Set(subsOfA), ["A1", "A2"])
}

func test_listFolders_rootWrapper_unchanged() throws {
    let storage = DocumentStorage(documentsURL: tempDir)
    _ = try storage.createFolder(named: "Receipts")
    XCTAssertEqual(try storage.listFolders().map(\.lastPathComponent), ["Receipts"])
}
```

- [ ] **Step 2: Run to verify failure**

Run: `xcodebuild test -project DocumentScanner/DocumentScanner.xcodeproj -scheme DocumentScanner -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:DocumentScannerTests/DocumentStorageTests/test_createFolder_inParent_createsNestedSubfolder`
Expected: FAIL — no `createFolder(named:in:)`.

- [ ] **Step 3: Parameterize the two methods**

In `DocumentStorage.swift`, replace `createFolder(named:)` with a parent-aware version + a root wrapper:

```swift
@discardableResult
func createFolder(named name: String, in parent: URL) throws -> URL {
    let sanitized = Self.sanitize(name)
    guard !sanitized.isEmpty else { throw DocumentStorageError.emptyName }
    let folderURL = parent.appendingPathComponent(sanitized, isDirectory: true)

    var coordinatorError: NSError?
    var createError: Error?
    let coordinator = NSFileCoordinator()
    coordinator.coordinate(writingItemAt: folderURL, options: .forReplacing, error: &coordinatorError) { url in
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false, attributes: nil)
        } catch {
            createError = error
        }
    }
    if let error = coordinatorError ?? (createError as NSError?) { throw error }
    return folderURL
}

@discardableResult
func createFolder(named name: String) throws -> URL {
    try createFolder(named: name, in: documentsURL)
}
```

And replace `listFolders()` with a parent-aware version + wrapper:

```swift
func listFolders(in parent: URL) throws -> [URL] {
    let contents = try FileManager.default.contentsOfDirectory(
        at: parent,
        includingPropertiesForKeys: [.isDirectoryKey],
        options: [.skipsHiddenFiles]
    )
    return contents.filter { url in
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }
}

func listFolders() throws -> [URL] {
    try listFolders(in: documentsURL)
}
```

- [ ] **Step 4: Run to verify pass**

Run: `xcodebuild test -project DocumentScanner/DocumentScanner.xcodeproj -scheme DocumentScanner -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:DocumentScannerTests/DocumentStorageTests`
Expected: PASS (existing + 3 new).

- [ ] **Step 5: Commit**

```bash
git add DocumentScanner/DocumentScanner/Storage/DocumentStorage.swift DocumentScanner/DocumentScannerTests/DocumentStorageTests.swift
git commit -m "feat: create/list folders inside a parent directory

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 2: `FolderPaths` — depth + display label (pure)

**Files:**
- Create: `DocumentScanner/DocumentScanner/Library/FolderPaths.swift`
- Test: `DocumentScanner/DocumentScannerTests/FolderPathsTests.swift`

- [ ] **Step 1: Write failing tests**

Create `FolderPathsTests.swift`:

```swift
import XCTest
@testable import DocumentScanner

final class FolderPathsTests: XCTestCase {
    private let root = URL(fileURLWithPath: "/docs", isDirectory: true)

    func test_level_root_isZero() {
        XCTAssertEqual(FolderPaths.level(of: root, root: root), 0)
    }
    func test_level_topFolder_isOne() {
        let f = root.appendingPathComponent("Taxes", isDirectory: true)
        XCTAssertEqual(FolderPaths.level(of: f, root: root), 1)
    }
    func test_level_subfolder_isTwo() {
        let sub = root.appendingPathComponent("Taxes", isDirectory: true)
            .appendingPathComponent("T3", isDirectory: true)
        XCTAssertEqual(FolderPaths.level(of: sub, root: root), 2)
    }
    func test_label_root_isMainLibrary() {
        XCTAssertEqual(FolderPaths.label(for: root, root: root), "Main Library")
    }
    func test_label_topFolder_isName() {
        let f = root.appendingPathComponent("Taxes", isDirectory: true)
        XCTAssertEqual(FolderPaths.label(for: f, root: root), "Taxes")
    }
    func test_label_subfolder_isParentThenName() {
        let sub = root.appendingPathComponent("Taxes", isDirectory: true)
            .appendingPathComponent("T3", isDirectory: true)
        XCTAssertEqual(FolderPaths.label(for: sub, root: root), "Taxes ▸ T3")
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `xcodebuild test -project DocumentScanner/DocumentScanner.xcodeproj -scheme DocumentScanner -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:DocumentScannerTests/FolderPathsTests/test_level_root_isZero`
Expected: FAIL — no type `FolderPaths`.

- [ ] **Step 3: Implement**

Create `FolderPaths.swift`:

```swift
import Foundation

/// Pure helpers for reasoning about a folder's position under the documents root.
/// Levels are array indices from the root: root = 0, top-level folder = 1,
/// sub-folder = 2. The app caps folder creation at level 2 in the UI.
enum FolderPaths {
    /// Number of path components between `root` and `url` (0 when they're equal).
    static func level(of url: URL, root: URL) -> Int {
        let rootComponents = root.standardizedFileURL.pathComponents
        let urlComponents = url.standardizedFileURL.pathComponents
        return max(0, urlComponents.count - rootComponents.count)
    }

    /// Display label: "Main Library" for root, the folder name for a top-level
    /// folder, and "Parent ▸ Name" for a sub-folder.
    static func label(for url: URL, root: URL) -> String {
        switch level(of: url, root: root) {
        case 0:
            return "Main Library"
        case 1:
            return url.lastPathComponent
        default:
            let parent = url.deletingLastPathComponent().lastPathComponent
            return "\(parent) ▸ \(url.lastPathComponent)"
        }
    }
}
```

- [ ] **Step 4: Run to verify pass**

Run: `xcodebuild test -project DocumentScanner/DocumentScanner.xcodeproj -scheme DocumentScanner -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:DocumentScannerTests/FolderPathsTests`
Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add DocumentScanner/DocumentScanner/Library/FolderPaths.swift DocumentScanner/DocumentScannerTests/FolderPathsTests.swift
git commit -m "feat: FolderPaths — folder depth + display label helpers

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 3: `ScanDestinations` — the "Save to" menu tree (pure)

**Files:**
- Create: `DocumentScanner/DocumentScanner/Library/ScanDestinations.swift`
- Test: `DocumentScanner/DocumentScannerTests/ScanDestinationsTests.swift`

- [ ] **Step 1: Write failing tests**

Create `ScanDestinationsTests.swift`:

```swift
import XCTest
@testable import DocumentScanner

final class ScanDestinationsTests: XCTestCase {
    private let root = URL(fileURLWithPath: "/docs", isDirectory: true)

    func test_build_mainIsRoot() {
        let tree = ScanDestinations.build(root: root, folders: [], subfoldersByFolder: [:])
        XCTAssertEqual(tree.main.url, root)
        XCTAssertEqual(tree.main.name, "Main Library")
        XCTAssertTrue(tree.groups.isEmpty)
    }

    func test_build_groupsFoldersWithTheirSubfolders() {
        let taxes = root.appendingPathComponent("Taxes", isDirectory: true)
        let t3 = taxes.appendingPathComponent("T3", isDirectory: true)
        let receipts = root.appendingPathComponent("Receipts", isDirectory: true)
        let tree = ScanDestinations.build(
            root: root,
            folders: [taxes, receipts],
            subfoldersByFolder: [taxes: [t3], receipts: []]
        )
        XCTAssertEqual(tree.groups.map { $0.folder.name }, ["Taxes", "Receipts"])
        XCTAssertEqual(tree.groups[0].subfolders.map { $0.name }, ["T3"])
        XCTAssertTrue(tree.groups[1].subfolders.isEmpty)
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `xcodebuild test -project DocumentScanner/DocumentScanner.xcodeproj -scheme DocumentScanner -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:DocumentScannerTests/ScanDestinationsTests/test_build_mainIsRoot`
Expected: FAIL — no type `ScanDestinations`.

- [ ] **Step 3: Implement**

Create `ScanDestinations.swift`:

```swift
import Foundation

/// One selectable place a scan can be saved (root, a folder, or a sub-folder).
struct ScanDestination: Identifiable, Hashable {
    let url: URL
    let name: String
    var id: URL { url }
}

/// A top-level folder plus its sub-folders, for the nested "Save to" menu.
struct ScanDestinationGroup: Identifiable {
    let folder: ScanDestination
    let subfolders: [ScanDestination]
    var id: URL { folder.url }
}

/// Pure builder for the Save-sheet destination menu. SwiftUI-free so it's unit-tested.
enum ScanDestinations {
    static func build(
        root: URL,
        folders: [URL],
        subfoldersByFolder: [URL: [URL]]
    ) -> (main: ScanDestination, groups: [ScanDestinationGroup]) {
        let main = ScanDestination(url: root, name: FolderPaths.label(for: root, root: root))
        let groups = folders.map { folder -> ScanDestinationGroup in
            let subs = (subfoldersByFolder[folder] ?? []).map {
                ScanDestination(url: $0, name: $0.lastPathComponent)
            }
            return ScanDestinationGroup(
                folder: ScanDestination(url: folder, name: folder.lastPathComponent),
                subfolders: subs
            )
        }
        return (main, groups)
    }
}
```

- [ ] **Step 4: Run to verify pass**

Run: `xcodebuild test -project DocumentScanner/DocumentScanner.xcodeproj -scheme DocumentScanner -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:DocumentScannerTests/ScanDestinationsTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add DocumentScanner/DocumentScanner/Library/ScanDestinations.swift DocumentScanner/DocumentScannerTests/ScanDestinationsTests.swift
git commit -m "feat: ScanDestinations — pure builder for the Save-to menu tree

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 4: Extend `MoveDestinations` to include sub-folders

**Files:**
- Modify: `DocumentScanner/DocumentScanner/Library/MoveDestinations.swift`
- Test: `DocumentScanner/DocumentScannerTests/MoveDestinationsTests.swift`

Note: `MoveDestinations.list(currentParent:root:folders:)` already exists; `folders` will now include sub-folders, and labels use `FolderPaths.label` so a sub-folder reads "Parent ▸ Sub".

- [ ] **Step 1: Write failing test**

Add to `MoveDestinationsTests`:

```swift
func test_list_labelsSubfoldersWithParentContext() {
    let root = URL(fileURLWithPath: "/docs", isDirectory: true)
    let taxes = root.appendingPathComponent("Taxes", isDirectory: true)
    let t3 = taxes.appendingPathComponent("T3", isDirectory: true)
    // Doc currently at root; destinations should include the sub-folder, labeled with parent.
    let dests = MoveDestinations.list(currentParent: root, root: root, folders: [taxes, t3])
    let t3Dest = dests.first { $0.url == t3 }
    XCTAssertEqual(t3Dest?.name, "Taxes ▸ T3")
    XCTAssertEqual(dests.first { $0.url == taxes }?.name, "Taxes")
}
```

- [ ] **Step 2: Run to verify failure**

Run: `xcodebuild test -project DocumentScanner/DocumentScanner.xcodeproj -scheme DocumentScanner -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:DocumentScannerTests/MoveDestinationsTests/test_list_labelsSubfoldersWithParentContext`
Expected: FAIL — sub-folder label is "T3", not "Taxes ▸ T3".

- [ ] **Step 3: Update the label**

In `MoveDestinations.list`, change the folder-name line to use `FolderPaths.label`:

```swift
for folder in folders where folder.standardizedFileURL.path != currentPath {
    result.append(MoveDestination(url: folder, name: FolderPaths.label(for: folder, root: root)))
}
```

(Leave the "Main Library" root entry as-is.)

- [ ] **Step 4: Run to verify pass**

Run: `xcodebuild test -project DocumentScanner/DocumentScanner.xcodeproj -scheme DocumentScanner -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:DocumentScannerTests/MoveDestinationsTests`
Expected: PASS (existing top-folder tests still pass — `label` returns the bare name at level 1).

- [ ] **Step 5: Commit**

```bash
git add DocumentScanner/DocumentScanner/Library/MoveDestinations.swift DocumentScanner/DocumentScannerTests/MoveDestinationsTests.swift
git commit -m "feat: label sub-folder move destinations with parent context

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 5: `NameDocumentSheet` — "Save to" destination picker

**Files:**
- Modify: `DocumentScanner/DocumentScanner/Capture/NameDocumentSheet.swift`
- Modify: `DocumentScanner/DocumentScanner/Library/LibraryView.swift` (caller)
- Modify: `DocumentScanner/DocumentScanner/Library/FolderContentsView.swift` (caller)

No unit test (SwiftUI wiring; verified by build + smoke). Must build and keep the suite green.

- [ ] **Step 1: Change the sheet's inputs**

In `NameDocumentSheet`, replace the `let storage: DocumentStorage` stored property with a root storage + default destination, and add selection state:

```swift
let rootStorage: DocumentStorage
let defaultDestination: URL
// ...existing lets: images, recognizeTask, pipeline, onSaved, onCancel...

@State private var selectedDestination: URL = .init(fileURLWithPath: "/")   // set in .onAppear
@State private var destinationTree: (main: ScanDestination, groups: [ScanDestinationGroup])?
```

Initialize selection + load the tree in a `.task` (add alongside the existing `.task` modifiers on the `Form`):

```swift
.task { loadDestinations() }
```

Add the helper methods:

```swift
private func loadDestinations() {
    selectedDestination = defaultDestination
    let root = rootStorage.documentsURL
    let folders = (try? rootStorage.listFolders()) ?? []
    var subs: [URL: [URL]] = [:]
    for folder in folders {
        subs[folder] = (try? rootStorage.listFolders(in: folder)) ?? []
    }
    destinationTree = ScanDestinations.build(root: root, folders: folders, subfoldersByFolder: subs)
}
```

- [ ] **Step 2: Add the "Save to" menu section**

Add a new `Section` to the `Form` (place it above the "Name" section):

```swift
Section("Save to") {
    Menu {
        if let tree = destinationTree {
            Button { selectedDestination = tree.main.url } label: { Text(tree.main.name) }
            ForEach(tree.groups) { group in
                if group.subfolders.isEmpty {
                    Button { selectedDestination = group.folder.url } label: { Text(group.folder.name) }
                } else {
                    Menu(group.folder.name) {
                        Button { selectedDestination = group.folder.url } label: { Text(group.folder.name) }
                        ForEach(group.subfolders) { sub in
                            Button { selectedDestination = sub.url } label: { Text(sub.name) }
                        }
                    }
                }
            }
        }
    } label: {
        HStack {
            Text("Folder")
            Spacer()
            Text(FolderPaths.label(for: selectedDestination, root: rootStorage.documentsURL))
                .foregroundStyle(.secondary)
        }
    }
    .disabled(isWorking)
    .accessibilityIdentifier("NameSheet.DestinationMenu")
}
```

- [ ] **Step 3: Write to the selected destination**

In `save()`, change the write line to scope storage to the selection:

```swift
let destinationStorage = DocumentStorage(documentsURL: selectedDestination)
_ = try destinationStorage.write(result.pdf, preferredName: name)
```

- [ ] **Step 4: Update both callers**

In `LibraryView.swift` (the `NameDocumentSheet(...)` at ~line 139), replace `storage: storage,` with:

```swift
rootStorage: storage,
defaultDestination: storage.documentsURL,
```

In `FolderContentsView.swift` (the `NameDocumentSheet(...)` at ~line 118), replace `storage: folderStorage,` with:

```swift
rootStorage: storage,          // root storage (documentsURL == root)
defaultDestination: folderURL, // current context = this folder
```

(`FolderContentsView.storage` is the root storage; `folderStorage` is no longer needed by the sheet.)

- [ ] **Step 5: Build to verify**

Run: `xcodebuild build -project DocumentScanner/DocumentScanner.xcodeproj -scheme DocumentScanner -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add DocumentScanner/DocumentScanner/Capture/NameDocumentSheet.swift DocumentScanner/DocumentScanner/Library/LibraryView.swift DocumentScanner/DocumentScanner/Library/FolderContentsView.swift
git commit -m "feat: Save-to destination picker in the scan Save sheet

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 6: `FolderContentsView` — show + navigate sub-folders

**Files:**
- Modify: `DocumentScanner/DocumentScanner/Library/FolderContentsView.swift`

**Read first:** `LibraryView.swift:310-370` (how root folders render as rows/tiles with `FolderTile` + `folderContextMenu` + navigation) — mirror it here. `FolderContentsView` already has a `folders: [URL]` state + `refreshFolders()`; today it loads root folders for the Move menu. Add a **separate** `subfolders: [URL]` state for *this folder's* children so the two concerns stay distinct.

- [ ] **Step 1: Add sub-folder state + loading**

Add near the other `@State` in `FolderContentsView`:

```swift
@State private var subfolders: [URL] = []
```

In `refreshFolders()` (the existing method), also load this folder's sub-folders:

```swift
subfolders = (try? storage.listFolders(in: folderURL))?
    .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
    ?? []
```

- [ ] **Step 2: Render sub-folders and navigate into them**

In both the list body and grid body, add a sub-folders section **above** the documents, mirroring `LibraryView`'s folder rendering (`FolderTile` in grid, a row with a folder image in list), each wrapped so tapping navigates by URL value (which the inherited `navigationDestination(for: URL.self)` turns into a child `FolderContentsView`):

- List: `ForEach(subfolders, id: \.self) { NavigationLink(value: $0) { <folder row> } .contextMenu { subfolderContextMenu($0) } }`
- Grid: `ForEach(subfolders, id: \.self) { NavigationLink(value: $0) { FolderTile(url: $0) } .contextMenu { subfolderContextMenu($0) } }`

Match the exact row/tile markup used in `LibraryView.swift:310-370`.

- [ ] **Step 3: Build to verify sub-folders appear + navigate**

Run: `xcodebuild build -project DocumentScanner/DocumentScanner.xcodeproj -scheme DocumentScanner -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: `** BUILD SUCCEEDED **`. (`subfolderContextMenu` is added in Task 7; for this build step, temporarily use `.contextMenu { }` empty, or fold Steps into Task 7 — but keep this task's commit building.)

To keep this task self-contained and building, add a minimal stub now and flesh it out in Task 7:

```swift
@ViewBuilder private func subfolderContextMenu(_ url: URL) -> some View { EmptyView() }
```

- [ ] **Step 4: Commit**

```bash
git add DocumentScanner/DocumentScanner/Library/FolderContentsView.swift
git commit -m "feat: show and navigate sub-folders inside a folder

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 7: `FolderContentsView` — New Sub-folder, rename/delete, level-2 cap

**Files:**
- Modify: `DocumentScanner/DocumentScanner/Library/FolderContentsView.swift`

**Read first:** `LibraryView.swift:151-185` (folder alerts), `242-254` (`folderContextMenu`), `481-535` (`createFolder`/`renameFolder`/`deleteFolder`). Mirror them, but scope creation to `folderURL` and gate on depth.

- [ ] **Step 1: Add folder-management state**

```swift
@State private var showingNewSubfolderAlert = false
@State private var newSubfolderName = ""
@State private var subfolderBeingRenamed: URL?
@State private var renameSubfolderName = ""
@State private var subfolderBeingDeleted: URL?

/// True only for a level-1 folder (can hold sub-folders). A level-2 folder cannot.
private var canCreateSubfolder: Bool {
    FolderPaths.level(of: folderURL, root: storage.documentsURL) < 2
}
```

- [ ] **Step 2: Replace the `subfolderContextMenu` stub with the real menu** (mirrors `folderContextMenu`)

```swift
@ViewBuilder private func subfolderContextMenu(_ url: URL) -> some View {
    Button {
        renameSubfolderName = url.lastPathComponent
        subfolderBeingRenamed = url
    } label: { Label("Rename", systemImage: "pencil") }
    Button(role: .destructive) {
        subfolderBeingDeleted = url
    } label: { Label("Delete", systemImage: "trash") }
}
```

- [ ] **Step 3: Add the "+" menu option for New Sub-folder (only when allowed)**

Change the toolbar `+` (currently a plain scan `Button` at `FolderContentsView.swift:92-99`) to mirror `LibraryView`'s `+`: when `canCreateSubfolder`, a `Menu` with "Scan Document" (calls `triggerScan()`) and "New Sub-folder" (`newSubfolderName = ""; showingNewSubfolderAlert = true`); otherwise the plain scan button. Copy the structure from `LibraryView.swift:94-120`, relabeling "New Folder" → "New Sub-folder".

- [ ] **Step 4: Add the three alerts** (mirror `LibraryView.swift:151-185`), attached to the view body:

```swift
.alert("New Sub-folder", isPresented: $showingNewSubfolderAlert) {
    TextField("Folder name", text: $newSubfolderName).autocorrectionDisabled()
    Button("Create") { createSubfolder() }
    Button("Cancel", role: .cancel) {}
} message: { Text("Enter a name for the new sub-folder.") }
.alert("Rename Folder", isPresented: Binding(
    get: { subfolderBeingRenamed != nil },
    set: { if !$0 { subfolderBeingRenamed = nil } })) {
    TextField("Folder name", text: $renameSubfolderName).autocorrectionDisabled()
    Button("Rename") { renameSubfolder() }
    Button("Cancel", role: .cancel) {}
} message: { Text("Choose a new name for this folder.") }
.alert("Delete Folder?", isPresented: Binding(
    get: { subfolderBeingDeleted != nil },
    set: { if !$0 { subfolderBeingDeleted = nil } })) {
    Button("Delete", role: .destructive) { deleteSubfolder() }
    Button("Cancel", role: .cancel) {}
} message: { Text("This folder and all documents inside it will be deleted.") }
```

- [ ] **Step 5: Add the three handlers** (mirror `LibraryView.swift:481-535`, scoped to `folderURL`)

```swift
private func createSubfolder() {
    let trimmed = newSubfolderName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    do { _ = try storage.createFolder(named: trimmed, in: folderURL); refreshFolders() }
    catch { folderActionError = error.localizedDescription }
}
private func renameSubfolder() {
    guard let folder = subfolderBeingRenamed else { return }
    let trimmed = renameSubfolderName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    do { _ = try storage.renameFolder(at: folder, to: trimmed); refreshFolders() }
    catch { folderActionError = error.localizedDescription }
    subfolderBeingRenamed = nil
}
private func deleteSubfolder() {
    guard let folder = subfolderBeingDeleted else { return }
    do { try storage.deleteFolder(at: folder); store.refresh(); refreshFolders() }
    catch { folderActionError = error.localizedDescription }
    subfolderBeingDeleted = nil
}
```

- [ ] **Step 6: Build to verify**

Run: `xcodebuild build -project DocumentScanner/DocumentScanner.xcodeproj -scheme DocumentScanner -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 7: Commit**

```bash
git add DocumentScanner/DocumentScanner/Library/FolderContentsView.swift
git commit -m "feat: New Sub-folder + rename/delete with level-2 cap

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 8: Feed sub-folders to the Move menu

**Files:**
- Modify: `DocumentScanner/DocumentScanner/Library/LibraryView.swift`
- Modify: `DocumentScanner/DocumentScanner/Library/FolderContentsView.swift`

Today the `MoveToMenu` `folders:` argument is fed only top-level folders. Include sub-folders so a document can be moved into one.

- [ ] **Step 1: Build a folders-with-subfolders list where Move is wired**

Wherever `folders` is loaded for the Move menu (LibraryView `refreshFolders`; FolderContentsView `refreshFolders`), extend the list to also include each folder's sub-folders. Example for a `refreshFolders()`:

```swift
let top = (try? storage.listFolders()) ?? []
var all = top
for folder in top { all += (try? storage.listFolders(in: folder)) ?? [] }
folders = all.sorted { $0.path < $1.path }
```

The `MoveToMenu`/`MoveDestinations` already label sub-folders "Parent ▸ Sub" (Task 4), so no view change beyond feeding the fuller list.

- [ ] **Step 2: Build to verify**

Run: `xcodebuild build -project DocumentScanner/DocumentScanner.xcodeproj -scheme DocumentScanner -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add DocumentScanner/DocumentScanner/Library/LibraryView.swift DocumentScanner/DocumentScanner/Library/FolderContentsView.swift
git commit -m "feat: allow moving documents into sub-folders

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 9: Roadmap doc + full-suite verification

**Files:**
- Modify: `docs/FutureEnhancements.md`

- [ ] **Step 1: Mark the roadmap item shipped**

In `docs/FutureEnhancements.md`, replace the "Scan to a chosen folder" bullet with a shipped/struck version noting: destination picker in the Save sheet (default current context), one level of sub-folders (level-2 cap, UI-enforced; data layer already recursive), library-only folder creation, shallow folder search. Reference the spec + plan dates (2026-07-04).

- [ ] **Step 2: Run the full suite**

Run: `./scripts/test.sh`
Expected: `Passed: <n>  Failed: 0` (185 + the new FolderPaths/ScanDestinations/DocumentStorage/MoveDestinations tests).

- [ ] **Step 3: Commit**

```bash
git add docs/FutureEnhancements.md
git commit -m "docs: mark scan-to-folder + one-level nesting shipped (v2.4)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

- [ ] **Step 4: On-device smoke test (manual, at release time)**

Before archiving v2.4 (23): create a top-level folder → open it → **New Sub-folder** `T3` → confirm a level-2 folder shows **no** "New Sub-folder" option → from root, scan and pick `Taxes ▸ T3` in "Save to" → confirm it lands in `T3` → scan from inside `T3` → confirm default is `T3` → move a document into a sub-folder (label reads "Taxes ▸ T3"). Version bump to 2.4 (23) happens at archive (main currently reads 2.3 / 22).

---

## Notes for the implementer

- **Data layer is already recursive** — do NOT try to make the stores "folder-aware"; they enumerate every PDF and views filter by immediate parent (`FolderContentsView.docsInFolder`). Sub-folder documents are already excluded from a parent's list.
- **Navigation is inherited** — `LibraryView`'s `navigationDestination(for: URL.self)` builds a `FolderContentsView` for any folder URL, so a sub-folder `NavigationLink(value:)` recurses for free. Don't add a second destination handler.
- **Depth cap is UI-only** — one `canCreateSubfolder` check (`FolderPaths.level < 2`). Do not add storage-side depth limits.
- **`▸` character** is U+25B8 (BLACK RIGHT-POINTING SMALL TRIANGLE); keep it consistent across `FolderPaths` and any labels.
