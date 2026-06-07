# Sort Options Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users sort the document library by Date, Name, or Page Count (ascending/descending) via a Files-style toolbar menu, with the choice persisted globally.

**Architecture:** A pure, testable `DocumentSort` value type sorts an array of `DocumentSummary`. A reusable `SortMenu` SwiftUI view renders the picker. `LibraryView` and `FolderContentsView` each hold the sort preference in two `@AppStorage` values, apply `DocumentSort.sorted(...)` to their already-filtered document arrays, and show the `SortMenu` in their toolbar. Folders stay alphabetical; the library stores are untouched.

**Tech Stack:** Swift, SwiftUI (`@AppStorage`, `Menu`, `ToolbarItem`), XCTest, xcodebuild.

---

## Conventions for this plan

- **Run tests** (from repo root):

  ```bash
  cd DocumentScanner && xcodebuild test \
    -scheme DocumentScanner \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -only-testing:DocumentScannerTests/<ClassName>
  ```

  Full unit suite: `-only-testing:DocumentScannerTests`. If `iPhone 17` isn't
  installed, run `xcrun simctl list devices available` and substitute.

- **SourceKit/LSP false positives:** "No such module 'SwiftUI'/'UIKit'/'XCTest'"
  and "Cannot find type" diagnostics appear constantly in this project and are
  spurious. `xcodebuild` is the source of truth.

- **Synchronized file groups:** the project uses `PBXFileSystemSynchronizedRootGroup`,
  so a `.swift` file placed in the correct directory is auto-included. **Do NOT
  edit the `.pbxproj`** to add files. New source files go in
  `DocumentScanner/DocumentScanner/Library/`; tests go in
  `DocumentScanner/DocumentScannerTests/`.

- **Commit trailer:** every commit ends with
  `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.

- **Two UI tests are known-broken in the simulator** (`GoldenPathTests`,
  `EditModeTests`) — they fail on a clean `main` too (stubbed-scanner flow doesn't
  complete in the simulator). Ignore them; rely on the `DocumentScannerTests`
  (unit) bundle.

---

## File Structure

- **Create** `DocumentScanner/DocumentScanner/Library/DocumentSort.swift` —
  `SortKey` enum + `DocumentSort` struct (pure sorting + per-key default direction).
- **Create** `DocumentScanner/DocumentScanner/Library/SortMenu.swift` — reusable
  toolbar menu view.
- **Create** `DocumentScanner/DocumentScannerTests/DocumentSortTests.swift`.
- **Modify** `DocumentScanner/DocumentScanner/Library/LibraryView.swift` — sort
  preference state, `SortMenu` toolbar item, apply sort in `filteredDocs`.
- **Modify** `DocumentScanner/DocumentScanner/Library/FolderContentsView.swift` —
  same wiring, apply sort in `filtered`.

---

## Task 1: `DocumentSort` model

**Files:**
- Create: `DocumentScanner/DocumentScanner/Library/DocumentSort.swift`
- Test: `DocumentScanner/DocumentScannerTests/DocumentSortTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `DocumentScanner/DocumentScannerTests/DocumentSortTests.swift`:

```swift
import XCTest
@testable import DocumentScanner

final class DocumentSortTests: XCTestCase {

    private func doc(_ name: String, _ daysAgo: Int, _ pages: Int) -> DocumentSummary {
        DocumentSummary(
            url: URL(fileURLWithPath: "/docs/\(name).pdf"),
            displayName: name,
            createdAt: Date(timeIntervalSince1970: 1_000_000 - Double(daysAgo) * 86_400),
            pageCount: pages,
            ocrSnippet: "",
            isCorrupt: false
        )
    }

    func test_date_descending_isNewestFirst() {
        let a = doc("A", 0, 1)   // newest
        let b = doc("B", 5, 1)
        let c = doc("C", 10, 1)  // oldest
        let sort = DocumentSort(key: .date, ascending: false)
        XCTAssertEqual(sort.sorted([c, a, b]).map(\.displayName), ["A", "B", "C"])
    }

    func test_date_ascending_isOldestFirst() {
        let a = doc("A", 0, 1)
        let b = doc("B", 5, 1)
        let c = doc("C", 10, 1)
        let sort = DocumentSort(key: .date, ascending: true)
        XCTAssertEqual(sort.sorted([a, b, c]).map(\.displayName), ["C", "B", "A"])
    }

    func test_name_ascending_isCaseInsensitive() {
        let apple = doc("apple", 1, 1)
        let banana = doc("Banana", 2, 1)
        let cherry = doc("Cherry", 3, 1)
        let sort = DocumentSort(key: .name, ascending: true)
        XCTAssertEqual(sort.sorted([cherry, banana, apple]).map(\.displayName),
                       ["apple", "Banana", "Cherry"])
    }

    func test_name_descending() {
        let apple = doc("apple", 1, 1)
        let banana = doc("Banana", 2, 1)
        let sort = DocumentSort(key: .name, ascending: false)
        XCTAssertEqual(sort.sorted([apple, banana]).map(\.displayName),
                       ["Banana", "apple"])
    }

    func test_pageCount_descending_isMostFirst() {
        let a = doc("A", 1, 2)
        let b = doc("B", 2, 9)
        let c = doc("C", 3, 5)
        let sort = DocumentSort(key: .pageCount, ascending: false)
        XCTAssertEqual(sort.sorted([a, b, c]).map(\.displayName), ["B", "C", "A"])
    }

    func test_tieBreak_isStableByNameThenURL() {
        // Same date and page count → tie-break by case-insensitive name.
        let x = doc("Xerox", 5, 3)
        let a = doc("apple", 5, 3)
        let m = doc("Mango", 5, 3)
        let sort = DocumentSort(key: .date, ascending: false)
        // Primary (date) is equal for all, so order falls to name asc.
        XCTAssertEqual(sort.sorted([x, a, m]).map(\.displayName),
                       ["apple", "Mango", "Xerox"])
    }

    func test_defaultAscending_isTrueOnlyForName() {
        XCTAssertTrue(DocumentSort.defaultAscending(for: .name))
        XCTAssertFalse(DocumentSort.defaultAscending(for: .date))
        XCTAssertFalse(DocumentSort.defaultAscending(for: .pageCount))
    }

    func test_emptyAndSingle() {
        let sort = DocumentSort(key: .name, ascending: true)
        XCTAssertEqual(sort.sorted([]).count, 0)
        let only = doc("Solo", 1, 1)
        XCTAssertEqual(sort.sorted([only]).map(\.displayName), ["Solo"])
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run:
```bash
cd DocumentScanner && xcodebuild test \
  -scheme DocumentScanner \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:DocumentScannerTests/DocumentSortTests
```
Expected: FAIL to compile — "Cannot find 'DocumentSort' in scope".

- [ ] **Step 3: Write the implementation**

Create `DocumentScanner/DocumentScanner/Library/DocumentSort.swift`:

```swift
import Foundation

/// The field documents are sorted by.
enum SortKey: String, CaseIterable {
    case date
    case name
    case pageCount

    /// Menu label.
    var title: String {
        switch self {
        case .date:      return "Date"
        case .name:      return "Name"
        case .pageCount: return "Page Count"
        }
    }
}

/// A document sort order: a key plus a direction. Pure value type — no SwiftUI,
/// no view state — so it can be unit-tested directly.
struct DocumentSort: Equatable {
    var key: SortKey
    var ascending: Bool

    /// The natural default direction when first switching to a key: Name reads
    /// A–Z (ascending); Date and Page Count read newest/most first (descending).
    static func defaultAscending(for key: SortKey) -> Bool {
        key == .name
    }

    /// Returns `docs` ordered by the current key and direction. Stable: when the
    /// primary key is equal, ties break by case-insensitive name, then url path,
    /// so the order never jitters between runs.
    func sorted(_ docs: [DocumentSummary]) -> [DocumentSummary] {
        docs.sorted { a, b in
            let order = Self.primaryOrder(a, b, key: key)
            if order != .orderedSame {
                return ascending
                    ? order == .orderedAscending
                    : order == .orderedDescending
            }
            // Stable tie-break, always ascending regardless of `ascending`.
            let byName = a.displayName.localizedCaseInsensitiveCompare(b.displayName)
            if byName != .orderedSame { return byName == .orderedAscending }
            return a.url.path < b.url.path
        }
    }

    private static func primaryOrder(
        _ a: DocumentSummary, _ b: DocumentSummary, key: SortKey
    ) -> ComparisonResult {
        switch key {
        case .date:
            if a.createdAt == b.createdAt { return .orderedSame }
            return a.createdAt < b.createdAt ? .orderedAscending : .orderedDescending
        case .name:
            return a.displayName.localizedCaseInsensitiveCompare(b.displayName)
        case .pageCount:
            if a.pageCount == b.pageCount { return .orderedSame }
            return a.pageCount < b.pageCount ? .orderedAscending : .orderedDescending
        }
    }
}
```

- [ ] **Step 4: Run to verify it passes**

Run:
```bash
cd DocumentScanner && xcodebuild test \
  -scheme DocumentScanner \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:DocumentScannerTests/DocumentSortTests
```
Expected: PASS (8 tests).

- [ ] **Step 5: Commit**

```bash
git add DocumentScanner/DocumentScanner/Library/DocumentSort.swift \
        DocumentScanner/DocumentScannerTests/DocumentSortTests.swift
git commit -m "feat: add DocumentSort model (date/name/pageCount, asc/desc)"
```

---

## Task 2: `SortMenu` reusable view

**Files:**
- Create: `DocumentScanner/DocumentScanner/Library/SortMenu.swift`

No unit test — thin SwiftUI wrapper, validated by the manual smoke test.

- [ ] **Step 1: Write the view**

Create `DocumentScanner/DocumentScanner/Library/SortMenu.swift`:

```swift
import SwiftUI

/// Toolbar menu for choosing the document sort. The active key shows a
/// direction chevron; tapping a different key switches to it, tapping the
/// active key flips its direction. The caller owns the `DocumentSort` state
/// (persisted in @AppStorage) and applies the change via `onSelect`.
struct SortMenu: View {
    let sort: DocumentSort
    let onSelect: (SortKey) -> Void

    var body: some View {
        Menu {
            ForEach(SortKey.allCases, id: \.self) { key in
                Button {
                    onSelect(key)
                } label: {
                    if key == sort.key {
                        Label(key.title,
                              systemImage: sort.ascending ? "chevron.up" : "chevron.down")
                    } else {
                        Text(key.title)
                    }
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down.circle")
        }
        .accessibilityIdentifier("Library.SortMenu")
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run:
```bash
cd DocumentScanner && xcodebuild build \
  -scheme DocumentScanner \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add DocumentScanner/DocumentScanner/Library/SortMenu.swift
git commit -m "feat: add reusable SortMenu toolbar view"
```

---

## Task 3: Wire sort into `LibraryView`

**Files:**
- Modify: `DocumentScanner/DocumentScanner/Library/LibraryView.swift`

- [ ] **Step 1: Add the sort preference state**

Find the `@AppStorage` line in `LibraryView`:

```swift
    @AppStorage("showFolders") private var showFolders = true
```

Add two more directly below it:

```swift
    @AppStorage("showFolders") private var showFolders = true
    @AppStorage("sortKey") private var sortKeyRaw = SortKey.date.rawValue
    @AppStorage("sortAscending") private var sortAscending = false
```

- [ ] **Step 2: Add the `sort` computed property and `selectSort` helper**

Add these next to the other private helpers (e.g. just above `triggerScan()`):

```swift
    private var sort: DocumentSort {
        DocumentSort(key: SortKey(rawValue: sortKeyRaw) ?? .date, ascending: sortAscending)
    }

    private func selectSort(_ key: SortKey) {
        if key == sort.key {
            sortAscending.toggle()
        } else {
            sortKeyRaw = key.rawValue
            sortAscending = DocumentSort.defaultAscending(for: key)
        }
    }
```

- [ ] **Step 3: Apply the sort in `filteredDocs`**

Replace the existing `filteredDocs` computed property:

```swift
    private var filteredDocs: [DocumentSummary] {
        guard !searchText.isEmpty else { return visibleDocs }
        let needle = searchText.lowercased()
        return visibleDocs.filter {
            $0.displayName.lowercased().contains(needle)
            || $0.ocrSnippet.lowercased().contains(needle)
        }
    }
```

with:

```swift
    private var filteredDocs: [DocumentSummary] {
        let matched: [DocumentSummary]
        if searchText.isEmpty {
            matched = visibleDocs
        } else {
            let needle = searchText.lowercased()
            matched = visibleDocs.filter {
                $0.displayName.lowercased().contains(needle)
                || $0.ocrSnippet.lowercased().contains(needle)
            }
        }
        return sort.sorted(matched)
    }
```

- [ ] **Step 4: Add the `SortMenu` to the toolbar**

Find the settings toolbar item:

```swift
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        SettingsView(lockSettings: lockSettings)
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityIdentifier("Library.SettingsButton")
                }
```

Add a new toolbar item immediately after it (before the `.topBarTrailing` + item):

```swift
                ToolbarItem(placement: .topBarTrailing) {
                    SortMenu(sort: sort, onSelect: selectSort)
                }
```

- [ ] **Step 5: Build to verify it compiles**

Run:
```bash
cd DocumentScanner && xcodebuild build \
  -scheme DocumentScanner \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 6: Commit**

```bash
git add DocumentScanner/DocumentScanner/Library/LibraryView.swift
git commit -m "feat: sort menu + sorted documents in library view"
```

---

## Task 4: Wire sort into `FolderContentsView`

**Files:**
- Modify: `DocumentScanner/DocumentScanner/Library/FolderContentsView.swift`

- [ ] **Step 1: Add the sort preference state**

Find the `@State` block (currently ending with `@State private var folderActionError: String?`)
and add two `@AppStorage` entries after it:

```swift
    @State private var folders: [URL] = []
    @State private var folderActionError: String?
    @AppStorage("sortKey") private var sortKeyRaw = SortKey.date.rawValue
    @AppStorage("sortAscending") private var sortAscending = false
```

- [ ] **Step 2: Add the `sort` computed property and `selectSort` helper**

Add these next to the other private helpers (e.g. just above `triggerScan()`):

```swift
    private var sort: DocumentSort {
        DocumentSort(key: SortKey(rawValue: sortKeyRaw) ?? .date, ascending: sortAscending)
    }

    private func selectSort(_ key: SortKey) {
        if key == sort.key {
            sortAscending.toggle()
        } else {
            sortKeyRaw = key.rawValue
            sortAscending = DocumentSort.defaultAscending(for: key)
        }
    }
```

- [ ] **Step 3: Apply the sort in `filtered`**

Replace the existing `filtered` computed property:

```swift
    private var filtered: [DocumentSummary] {
        guard !searchText.isEmpty else { return docsInFolder }
        let needle = searchText.lowercased()
        return docsInFolder.filter {
            $0.displayName.lowercased().contains(needle)
            || $0.ocrSnippet.lowercased().contains(needle)
        }
    }
```

with:

```swift
    private var filtered: [DocumentSummary] {
        let matched: [DocumentSummary]
        if searchText.isEmpty {
            matched = docsInFolder
        } else {
            let needle = searchText.lowercased()
            matched = docsInFolder.filter {
                $0.displayName.lowercased().contains(needle)
                || $0.ocrSnippet.lowercased().contains(needle)
            }
        }
        return sort.sorted(matched)
    }
```

- [ ] **Step 4: Add the `SortMenu` to the toolbar**

Find the existing toolbar in `FolderContentsView`:

```swift
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    triggerScan()
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityIdentifier("Folder.AddButton")
            }
        }
```

Replace it with (adds a sort menu item before the add button):

```swift
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                SortMenu(sort: sort, onSelect: selectSort)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    triggerScan()
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityIdentifier("Folder.AddButton")
            }
        }
```

- [ ] **Step 5: Build to verify it compiles**

Run:
```bash
cd DocumentScanner && xcodebuild build \
  -scheme DocumentScanner \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 6: Run the full unit suite (no regressions)**

Run:
```bash
cd DocumentScanner && xcodebuild test \
  -scheme DocumentScanner \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:DocumentScannerTests
```
Expected: PASS (all unit tests, including Task 1's `DocumentSortTests`).

- [ ] **Step 7: Commit**

```bash
git add DocumentScanner/DocumentScanner/Library/FolderContentsView.swift
git commit -m "feat: sort menu + sorted documents in folder view"
```

---

## Task 5: Version bump + manual smoke test

**Files:**
- Modify: `DocumentScanner/DocumentScanner.xcodeproj/project.pbxproj` (via Xcode UI)

- [ ] **Step 1: Bump version (manual, in Xcode)**

Xcode → target **DocumentScanner** → General: set **Version** to `1.5` and
**Build** to `10`. This updates `MARKETING_VERSION` (1.4 → 1.5) and
`CURRENT_PROJECT_VERSION` (9 → 10) for the main-app Debug + Release configs; leave
the test targets unchanged.

Verify:
```bash
grep -n "MARKETING_VERSION\|CURRENT_PROJECT_VERSION" \
  DocumentScanner/DocumentScanner.xcodeproj/project.pbxproj
```
Expected: the two main-app configs show `MARKETING_VERSION = 1.5;` and
`CURRENT_PROJECT_VERSION = 10;`; the four test-target configs stay at 1.0 / 1.

- [ ] **Step 2: Manual smoke test (device/simulator — user-driven)**

With a library that has several documents (varied names, dates, page counts):
  1. Tap the sort menu (arrows icon) → it lists **Date**, **Name**, **Page Count**;
     the active key shows a chevron.
  2. Pick **Name** → documents reorder A–Z; the chevron points up.
  3. Tap **Name** again → order flips to Z–A; chevron points down.
  4. Pick **Page Count** → documents reorder most-pages-first.
  5. Open a folder → it uses the same sort (global). Folders in the main list stay
     alphabetical regardless of the chosen sort.
  6. Force-quit and relaunch → the chosen sort is remembered.

- [ ] **Step 3: Commit the version bump**

```bash
git add DocumentScanner/DocumentScanner.xcodeproj/project.pbxproj
git commit -m "chore: bump to v1.5 (10)"
```

---

## Done

After Task 5, the library and folder views can be sorted by Date / Name / Page
Count in either direction via a toolbar menu, the choice is global and persisted,
folders stay alphabetical, and the full unit suite passes. Next steps (outside this
plan): push, archive, upload, submit for review — same flow as v1.4.
