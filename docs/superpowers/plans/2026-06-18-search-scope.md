# Search Scope Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Main Library search find documents inside folders, and make in-folder search highlight its matches in the viewer — one model: "search is scoped to where you are."

**Architecture:** A pure, tested `SearchMatcher.matches(term:in:scope:)` becomes the single source of truth for which docs match (used by both the results list and the viewer's context). Document taps push a `DocumentRoute { summary, term, scope }` instead of a bare `DocumentSummary`; one root `navigationDestination(for: DocumentRoute.self)` lazily builds a scope-correct `SearchContext`, removing the bug where the viewer read `LibraryView.searchText` (empty inside a folder).

**Tech Stack:** Swift, SwiftUI (`NavigationPath`, `.navigationDestination`, `.searchable`, `ContentUnavailableView`), PDFKit (`findString`), XCTest.

**Spec:** `docs/superpowers/specs/2026-06-18-search-scope-design.md`

---

## File Structure

- Create: `DocumentScanner/DocumentScanner/Library/SearchMatcher.swift` — `SearchScope` enum + pure `SearchMatcher.matches(...)`.
- Create: `DocumentScanner/DocumentScanner/Library/DocumentRoute.swift` — `DocumentRoute` navigation value.
- Create: `DocumentScanner/DocumentScannerTests/SearchMatcherTests.swift` — unit tests for the match logic.
- Modify: `DocumentScanner/DocumentScanner/Library/LibraryView.swift` — unified destination, route push sites, all-scope `filteredDocs`, hide folders during search, folder label, no-results state.
- Modify: `DocumentScanner/DocumentScanner/Library/FolderContentsView.swift` — folder-scoped route push sites, `filtered` via `SearchMatcher`.
- Modify: `DocumentScanner/DocumentScanner/Library/DocumentRow.swift` — optional "in &lt;Folder&gt;" label.
- Modify: `DocumentScanner/DocumentScanner/Library/DocumentTile.swift` — optional "in &lt;Folder&gt;" label.
- Modify: `docs/FutureEnhancements.md` — remove the two now-fixed Search items (on merge).

Build / test commands:
```bash
cd DocumentScanner && xcodebuild build \
  -scheme DocumentScanner -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -5
cd DocumentScanner && xcodebuild test \
  -scheme DocumentScanner -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:DocumentScannerTests 2>&1 | grep -E "\*\* TEST|failed" | tail -5
```

> SourceKit may show "cannot find … in scope" / "No such module" for these files — stale-index
> artifacts. `xcodebuild` is the source of truth.

---

## Task 1: `SearchScope` + `SearchMatcher` (pure, tested)

**Files:**
- Create: `DocumentScanner/DocumentScanner/Library/SearchMatcher.swift`
- Test: `DocumentScanner/DocumentScannerTests/SearchMatcherTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `DocumentScanner/DocumentScannerTests/SearchMatcherTests.swift`:

```swift
import XCTest
@testable import DocumentScanner

final class SearchMatcherTests: XCTestCase {

    // Root is /tmp/docs; one folder /tmp/docs/Receipts.
    private let root = URL(fileURLWithPath: "/tmp/docs/Lease.pdf")          // root doc
    private let rootB = URL(fileURLWithPath: "/tmp/docs/Insurance.pdf")     // root doc
    private let inFolder = URL(fileURLWithPath: "/tmp/docs/Receipts/Costco.pdf")
    private let folderURL = URL(fileURLWithPath: "/tmp/docs/Receipts")

    private func summary(_ url: URL, name: String, ocr: String = "") -> DocumentSummary {
        DocumentSummary(url: url, displayName: name,
                        createdAt: Date(timeIntervalSince1970: 0),
                        pageCount: 1, ocrSnippet: ocr, isCorrupt: false)
    }

    private var all: [DocumentSummary] {
        [summary(root, name: "Lease", ocr: "rent montreal"),
         summary(rootB, name: "Insurance", ocr: "policy montreal"),
         summary(inFolder, name: "Costco", ocr: "groceries montreal")]
    }

    func test_libraryScope_includesDocsInsideFolders() {
        let result = SearchMatcher.matches(term: "montreal", in: all, scope: .library)
        XCTAssertEqual(Set(result.map(\.displayName)), ["Lease", "Insurance", "Costco"])
    }

    func test_folderScope_returnsOnlyThatFoldersDocs() {
        let result = SearchMatcher.matches(term: "montreal", in: all, scope: .folder(folderURL))
        XCTAssertEqual(result.map(\.displayName), ["Costco"])
    }

    func test_matchesDisplayName_caseInsensitive() {
        let result = SearchMatcher.matches(term: "LEASE", in: all, scope: .library)
        XCTAssertEqual(result.map(\.displayName), ["Lease"])
    }

    func test_matchesOcrSnippet() {
        let result = SearchMatcher.matches(term: "groceries", in: all, scope: .library)
        XCTAssertEqual(result.map(\.displayName), ["Costco"])
    }

    func test_emptyTerm_returnsEverythingInScope_unfiltered() {
        XCTAssertEqual(SearchMatcher.matches(term: "", in: all, scope: .library).count, 3)
        XCTAssertEqual(SearchMatcher.matches(term: "", in: all, scope: .folder(folderURL)).map(\.displayName), ["Costco"])
    }

    func test_noMatch_returnsEmpty() {
        XCTAssertTrue(SearchMatcher.matches(term: "xyzzy", in: all, scope: .library).isEmpty)
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run:
```bash
cd DocumentScanner && xcodebuild test -scheme DocumentScanner \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:DocumentScannerTests/SearchMatcherTests 2>&1 | grep -E "Cannot find|error:|\*\* TEST" | tail -5
```
Expected: FAIL — "Cannot find 'SearchMatcher' in scope".

- [ ] **Step 3: Implement `SearchScope` + `SearchMatcher`**

Create `DocumentScanner/DocumentScanner/Library/SearchMatcher.swift`:

```swift
import Foundation

/// Where a search ran — drives which documents are candidates.
/// `.library` spans every document; `.folder` is limited to the docs whose
/// parent directory is that folder.
enum SearchScope: Hashable {
    case library
    case folder(URL)
}

/// Single source of truth for "which documents match this term in this scope".
/// Pure (operates on already-loaded `DocumentSummary` metadata — `displayName`
/// and `ocrSnippet`, the latter being the doc's full extracted text), so both
/// the results list and the viewer's `SearchContext` candidate set agree.
enum SearchMatcher {
    static func matches(
        term: String,
        in summaries: [DocumentSummary],
        scope: SearchScope
    ) -> [DocumentSummary] {
        let scoped: [DocumentSummary]
        switch scope {
        case .library:
            scoped = summaries
        case .folder(let folderURL):
            let folderPath = folderURL.standardizedFileURL.path
            scoped = summaries.filter {
                $0.url.deletingLastPathComponent().standardizedFileURL.path == folderPath
            }
        }

        let needle = term.lowercased()
        guard !needle.isEmpty else { return scoped }
        return scoped.filter {
            $0.displayName.lowercased().contains(needle)
            || $0.ocrSnippet.lowercased().contains(needle)
        }
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run:
```bash
cd DocumentScanner && xcodebuild test -scheme DocumentScanner \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:DocumentScannerTests/SearchMatcherTests 2>&1 | grep -E "\*\* TEST|failed" | tail -5
```
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add DocumentScanner/DocumentScanner/Library/SearchMatcher.swift \
        DocumentScanner/DocumentScannerTests/SearchMatcherTests.swift
git commit -m "feat: SearchMatcher — scope-aware document match logic (pure, tested)"
```

---

## Task 2: `DocumentRoute` + unified navigation destination

Replaces the `DocumentSummary` destination (which read `LibraryView.searchText`) with a route
that carries the term + scope. This task wires the route type, the new destination, and
`LibraryView`'s own (root) tap sites. `FolderContentsView`'s tap sites come in Task 3.

**Files:**
- Create: `DocumentScanner/DocumentScanner/Library/DocumentRoute.swift`
- Modify: `DocumentScanner/DocumentScanner/Library/LibraryView.swift`

- [ ] **Step 1: Create the route value**

Create `DocumentScanner/DocumentScanner/Library/DocumentRoute.swift`:

```swift
import Foundation

/// Navigation value pushed when a document is tapped. Carries the originating
/// screen's active search term and scope so the viewer's `SearchContext` is
/// built correctly regardless of which screen pushed it. Lives in the in-memory
/// `NavigationPath`, so `Hashable` is sufficient (no Codable/state restoration).
struct DocumentRoute: Hashable {
    let summary: DocumentSummary
    let term: String
    let scope: SearchScope
}
```

- [ ] **Step 2: Replace the destination + context builder in LibraryView**

In `DocumentScanner/DocumentScanner/Library/LibraryView.swift`, replace the existing
`.navigationDestination(for: DocumentSummary.self) { summary in … }` block (currently lines
54-67) with:

```swift
            .navigationDestination(for: DocumentRoute.self) { route in
                DocumentViewerView(
                    summary: route.summary,
                    storage: storage,
                    scannerPresenter: scannerPresenter,
                    pipeline: pipeline,
                    searchContext: searchContext(for: route),
                    onDeleted: {
                        store.refresh()
                        path.removeLast()
                    },
                    onDocumentCreated: { store.refresh() }
                )
            }
```

- [ ] **Step 3: Replace the old context helpers with a route-based one**

Delete the existing `searchContext` computed property (currently lines 418-437) **and** the
`searchContextStarting(at:)` method (currently lines 453-459, plus the doc comment above it
starting at line 439). Add this single method in their place:

```swift
    /// Builds the cross-doc search context for a tapped route: matches the term
    /// within the route's scope (the same `SearchMatcher` the list uses), runs
    /// `findString` for per-doc counts, and points `startDocIndex` at the tapped
    /// doc. Nil when the term is empty, no doc has `findString` matches, or the
    /// tapped doc isn't among them (so the viewer opens plainly rather than on
    /// the wrong document).
    private func searchContext(for route: DocumentRoute) -> SearchContext? {
        guard !route.term.isEmpty else { return nil }
        let candidates = SearchMatcher.matches(
            term: route.term, in: store.summaries, scope: route.scope
        )
        let entries: [SearchContext.DocEntry] = candidates.compactMap { summary in
            guard let pdf = PDFDocument(url: summary.url) else { return nil }
            let count = pdf.findString(route.term, withOptions: .caseInsensitive).count
            return count > 0 ? .init(summary: summary, matchCount: count) : nil
        }
        guard let idx = entries.firstIndex(where: { $0.summary.id == route.summary.id })
        else { return nil }
        return SearchContext(term: route.term, docs: entries, startDocIndex: idx)
    }
```

(`import PDFKit` is already present in this file — the old `searchContext` used `PDFDocument`.)

- [ ] **Step 4: Update LibraryView's two document tap sites**

In `docRow(_:)` (the non-corrupt branch, currently line 290) change:

```swift
            NavigationLink(value: summary) {
```
to:
```swift
            NavigationLink(value: DocumentRoute(summary: summary, term: searchText, scope: .library)) {
```

In `docTile(_:)` (the non-corrupt branch, currently line 376) make the identical change:

```swift
            NavigationLink(value: DocumentRoute(summary: summary, term: searchText, scope: .library)) {
```

- [ ] **Step 5: Build**

```bash
cd DocumentScanner && xcodebuild build -scheme DocumentScanner \
  -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`. (Root-library search + highlight is unchanged in behavior;
this is a structural swap. Folder taps still compile — they push `DocumentSummary` until Task 3,
which now has no destination, so verify folder doc taps in Task 3, not here.)

> NOTE: After this task, `FolderContentsView`'s document rows still push `DocumentSummary`, which
> no longer has a destination — tapping a doc inside a folder will do nothing until Task 3. That's
> expected mid-plan; Task 3 fixes it immediately.

- [ ] **Step 6: Commit**

```bash
git add DocumentScanner/DocumentScanner/Library/DocumentRoute.swift \
        DocumentScanner/DocumentScanner/Library/LibraryView.swift
git commit -m "feat: DocumentRoute + unified navigationDestination (carry term + scope)"
```

---

## Task 3: FolderContentsView pushes folder-scoped routes (fixes Bug 2)

**Files:**
- Modify: `DocumentScanner/DocumentScanner/Library/FolderContentsView.swift`

- [ ] **Step 1: Push folder-scoped routes from both tap sites**

In `docRow(_:)` (non-corrupt branch, currently line 216) change:

```swift
            NavigationLink(value: summary) {
```
to:
```swift
            NavigationLink(value: DocumentRoute(summary: summary, term: searchText, scope: .folder(folderURL))) {
```

In `docTile(_:)` (non-corrupt branch, currently line 236) make the identical change:

```swift
            NavigationLink(value: DocumentRoute(summary: summary, term: searchText, scope: .folder(folderURL))) {
```

These resolve to the root's `navigationDestination(for: DocumentRoute.self)` (Task 2), which
builds a folder-scoped `SearchContext` from `route.term` — so in-folder matches now highlight.

- [ ] **Step 2: Route the folder's list filter through `SearchMatcher` (DRY)**

Replace the `filtered` computed property (currently lines 135-147) with:

```swift
    private var filtered: [DocumentSummary] {
        let matched = searchText.isEmpty
            ? docsInFolder
            : SearchMatcher.matches(term: searchText, in: store.summaries, scope: .folder(folderURL))
        return sort.sorted(matched)
    }
```

(`docsInFolder` stays — it's still used for the empty-folder check in `body`.)

- [ ] **Step 3: Build**

```bash
cd DocumentScanner && xcodebuild build -scheme DocumentScanner \
  -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add DocumentScanner/DocumentScanner/Library/FolderContentsView.swift
git commit -m "fix: in-folder search highlights — push folder-scoped DocumentRoute"
```

---

## Task 4: Main Library search spans all docs + hides folders (fixes Bug 1)

**Files:**
- Modify: `DocumentScanner/DocumentScanner/Library/LibraryView.swift`

- [ ] **Step 1: Search across every document**

Replace the `filteredDocs` computed property (currently lines 398-410) with:

```swift
    private var filteredDocs: [DocumentSummary] {
        let matched = searchText.isEmpty
            ? visibleDocs
            : SearchMatcher.matches(term: searchText, in: store.summaries, scope: .library)
        return sort.sorted(matched)
    }
```

When the field is empty, behavior is unchanged (`visibleDocs` = root docs, or all docs when
"Show Folders" is off). When searching, results span every document including those in folders.

- [ ] **Step 2: Hide folder rows while searching (List)**

In `listBody` (currently line 307), change the folders-section condition:

```swift
            if showFolders && !folders.isEmpty && searchText.isEmpty {
```

- [ ] **Step 3: Hide folder tiles while searching (Grid)**

In `gridBody` (currently line 348), change the folders condition the same way:

```swift
                if showFolders && !folders.isEmpty && searchText.isEmpty {
```

- [ ] **Step 4: Build**

```bash
cd DocumentScanner && xcodebuild build -scheme DocumentScanner \
  -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add DocumentScanner/DocumentScanner/Library/LibraryView.swift
git commit -m "fix: Main Library search spans docs inside folders; hide folders while searching"
```

---

## Task 5: "in &lt;Folder&gt;" label on results

**Files:**
- Modify: `DocumentScanner/DocumentScanner/Library/DocumentRow.swift`
- Modify: `DocumentScanner/DocumentScanner/Library/DocumentTile.swift`
- Modify: `DocumentScanner/DocumentScanner/Library/LibraryView.swift`

- [ ] **Step 1: Add an optional label to `DocumentRow`**

In `DocumentRow.swift`, add the property and the label. Change the struct's stored properties
(currently just `let summary: DocumentSummary`) to:

```swift
struct DocumentRow: View {
    let summary: DocumentSummary
    var folderName: String? = nil
```

Inside the inner `VStack(alignment: .leading, spacing: 2)`, immediately after the
`Text(summary.formattedSubtitle)…` line (currently lines 26-28), add:

```swift
                if let folderName {
                    Text("in \(folderName)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
```

- [ ] **Step 2: Add an optional label to `DocumentTile`**

In `DocumentTile.swift`, change the stored properties to:

```swift
struct DocumentTile: View {
    let summary: DocumentSummary
    var folderName: String? = nil
```

Immediately after the `Text(summary.formattedSubtitle)…` line (currently lines 29-32), add:

```swift
            if let folderName {
                Text("in \(folderName)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
```

- [ ] **Step 3: Compute and pass the label in LibraryView**

In `LibraryView.swift`, add this helper (place it next to `docsAtRoot`, around line 384):

```swift
    /// The containing folder's name for a search result that lives in a folder,
    /// or nil when the doc is at the library root. Used to label flattened
    /// Main Library search results ("in Receipts").
    private func folderLabel(for summary: DocumentSummary) -> String? {
        let parent = summary.url.deletingLastPathComponent().standardizedFileURL
        guard parent.path != storage.documentsURL.standardizedFileURL.path else { return nil }
        return parent.lastPathComponent
    }
```

In `docRow(_:)`, pass the label to **both** `DocumentRow(...)` calls (the corrupt branch and the
non-corrupt branch). Each currently reads `DocumentRow(summary: summary)`; change both to:

```swift
            DocumentRow(summary: summary, folderName: folderLabel(for: summary))
```

In `docTile(_:)`, pass the label to **both** `DocumentTile(...)` calls likewise. Each currently
reads `DocumentTile(summary: summary)`; change both to:

```swift
            DocumentTile(summary: summary, folderName: folderLabel(for: summary))
```

(During an empty search only root docs are shown, where `folderLabel` returns nil, so the label
only appears on flattened search results.)

- [ ] **Step 4: Build**

```bash
cd DocumentScanner && xcodebuild build -scheme DocumentScanner \
  -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add DocumentScanner/DocumentScanner/Library/DocumentRow.swift \
        DocumentScanner/DocumentScanner/Library/DocumentTile.swift \
        DocumentScanner/DocumentScanner/Library/LibraryView.swift
git commit -m "feat: label search results that live in a folder (in <Folder>)"
```

---

## Task 6: No-results empty state

**Files:**
- Modify: `DocumentScanner/DocumentScanner/Library/LibraryView.swift`

- [ ] **Step 1: Overlay a search empty-state on the List**

In `listBody`, after the `.searchable(text: $searchText, prompt: "Search documents")` line
(currently line 333), add:

```swift
        .overlay {
            if !searchText.isEmpty && filteredDocs.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
```

- [ ] **Step 2: Overlay the same on the Grid**

In `gridBody`, after its `.searchable(text: $searchText, prompt: "Search documents")` line
(currently line 363), add the identical overlay:

```swift
        .overlay {
            if !searchText.isEmpty && filteredDocs.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
```

(Folders are hidden while searching, so an empty `filteredDocs` means a genuinely empty result
set — the overlay won't fight with visible folder rows. The search bar stays attached to the
List/ScrollView, so the user can still edit their query.)

- [ ] **Step 3: Build**

```bash
cd DocumentScanner && xcodebuild build -scheme DocumentScanner \
  -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add DocumentScanner/DocumentScanner/Library/LibraryView.swift
git commit -m "feat: show 'No results' state for an empty search"
```

---

## Task 7: Full suite + roadmap cleanup

**Files:**
- Modify: `docs/FutureEnhancements.md`

- [ ] **Step 1: Run the full unit suite (no regressions)**

```bash
cd DocumentScanner && xcodebuild test -scheme DocumentScanner \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:DocumentScannerTests 2>&1 | grep -E "\*\* TEST|failed" | tail -5
```
Expected: `** TEST SUCCEEDED **`. (Watch `SearchContextTests` and any search-related tests
still pass — the `SearchContext` shape is unchanged.)

- [ ] **Step 2: Remove the two now-fixed roadmap items**

In `docs/FutureEnhancements.md`, delete from the `### Search` section **both** the
"Search scope is broken / incomplete" bullet **and** the "In-folder cross-doc search" bullet
(both are now fixed by this work). Leave the `### Search` heading in place if other search items
remain; otherwise remove the empty heading too.

- [ ] **Step 3: Commit**

```bash
git add docs/FutureEnhancements.md
git commit -m "docs: drop fixed search-scope roadmap items"
```

---

## Done

After Task 7: Main Library search finds documents anywhere (root + every folder), flattening to a
labeled results list while the field is active; searching inside a folder is scoped to that folder
and its matches highlight in the viewer; cross-document next/prev respects the searched scope; and
an empty search shows a "No results" state. The scope logic lives in one tested place
(`SearchMatcher`) shared by the list and the viewer's context.

**On-device smoke test (manual):**
1. From Main Library, search a term that only matches a doc **inside a folder** → it appears in
   the results (with an "in &lt;Folder&gt;" label); folders are hidden while searching; tap it →
   the viewer **highlights** the matches.
2. Open a folder, search a term matching a doc in it → tap → the viewer **highlights** (the Bug 2
   case).
3. Cross-doc next/prev: from a Main Library search, nav flows across folders; from an in-folder
   search, nav stays within the folder.
4. A search with no matches shows the "No results" state; clearing the field restores folders +
   root docs.
5. Regression: empty-field library and folder views look exactly as before.

Update `docs/FutureEnhancements.md` is handled in Task 7. Ships in the release after v1.9.
