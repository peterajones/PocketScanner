# Merge Two Documents Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a context-menu "Merge into…" action that appends one document's pages onto another, then deletes the source — combining two scans into one.

**Architecture:** A pure `MergeCandidates` builds the eligible-target list; a `DocumentMerge` helper does the file-level orchestration (load both PDFs → `DocumentMutations.append` → overwrite the target in place → delete the source, in that safe order); a `MergeIntoMenu` view mirrors `MoveToMenu`; `LibraryView` and `FolderContentsView` wire it into the document context menu with a confirmation alert. Reuses existing `DocumentMutations.append`, `DocumentStorage.write(_:replacing:withName:)`, and `DocumentStorage.delete(at:)`.

**Tech Stack:** Swift, SwiftUI, PDFKit, XCTest. Test target `DocumentScannerTests`.

**Conventions:**
- All `xcodebuild` commands run from `/Users/pjones/Desktop/PocketScanner/DocumentScanner`.
- Test run command (substitute the class): `xcodebuild test -scheme DocumentScanner -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:DocumentScannerTests/<Class>`
- `git` commands run from repo root `/Users/pjones/Desktop/PocketScanner`. New Swift files in the file-system-synchronized group compile without editing the `.xcodeproj`.
- Work happens on the existing `merge-documents` branch.

---

### Task 1: `MergeCandidates` (pure target list)

**Files:**
- Create: `DocumentScanner/DocumentScanner/Library/MergeCandidates.swift`
- Test: `DocumentScanner/DocumentScannerTests/MergeCandidatesTests.swift`

- [ ] **Step 1: Write the failing test**

Create `DocumentScanner/DocumentScannerTests/MergeCandidatesTests.swift`:

```swift
import XCTest
@testable import DocumentScanner

final class MergeCandidatesTests: XCTestCase {

    private func summary(_ name: String, corrupt: Bool = false) -> DocumentSummary {
        DocumentSummary(
            url: URL(fileURLWithPath: "/docs/\(name).pdf"),
            displayName: name, createdAt: Date(), pageCount: 1,
            ocrSnippet: "", isCorrupt: corrupt
        )
    }

    func test_excludesSourceItself() {
        let a = summary("A"), b = summary("B"), c = summary("C")
        let result = MergeCandidates.list(source: a, all: [a, b, c])
        XCTAssertEqual(result.map(\.displayName), ["B", "C"])
    }

    func test_excludesCorruptDocuments() {
        let a = summary("A"), b = summary("B"), bad = summary("Damaged", corrupt: true)
        let result = MergeCandidates.list(source: a, all: [a, b, bad])
        XCTAssertEqual(result.map(\.displayName), ["B"])
    }

    func test_emptyWhenSourceIsOnlyValidDoc() {
        let a = summary("A"), bad = summary("Damaged", corrupt: true)
        XCTAssertTrue(MergeCandidates.list(source: a, all: [a, bad]).isEmpty)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme DocumentScanner -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:DocumentScannerTests/MergeCandidatesTests`
Expected: FAIL — `cannot find 'MergeCandidates' in scope`.

- [ ] **Step 3: Write minimal implementation**

Create `DocumentScanner/DocumentScanner/Library/MergeCandidates.swift`:

```swift
import Foundation

/// Pure logic for the "Merge into…" target list: every document a given source
/// may be merged into. Kept free of SwiftUI so it can be unit-tested directly
/// (like `MoveDestinations`).
enum MergeCandidates {
    /// Targets for `source` drawn from `all` (the full library list): every
    /// document except the source itself and any corrupt document. Order is
    /// preserved from `all` so the menu matches the library's current order.
    static func list(source: DocumentSummary, all: [DocumentSummary]) -> [DocumentSummary] {
        all.filter { $0.url != source.url && !$0.isCorrupt }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme DocumentScanner -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:DocumentScannerTests/MergeCandidatesTests`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add DocumentScanner/DocumentScanner/Library/MergeCandidates.swift DocumentScanner/DocumentScannerTests/MergeCandidatesTests.swift
git commit -m "feat: add MergeCandidates target list"
```

---

### Task 2: `DocumentMerge` (file-level orchestration)

**Files:**
- Create: `DocumentScanner/DocumentScanner/Pipeline/DocumentMerge.swift`
- Test: `DocumentScanner/DocumentScannerTests/DocumentMergeTests.swift`

- [ ] **Step 1: Write the failing test**

Create `DocumentScanner/DocumentScannerTests/DocumentMergeTests.swift`:

```swift
import XCTest
import PDFKit
@testable import DocumentScanner

final class DocumentMergeTests: XCTestCase {

    var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    /// Writes a PDF with `pageCount` US-Letter pages to `tempDir` and returns its URL.
    private func writePDF(_ name: String, pages pageCount: Int) throws -> URL {
        let pdf = PDFDocument()
        for _ in 0..<pageCount {
            pdf.insert(PDFPage(), at: pdf.pageCount)
        }
        let url = tempDir.appendingPathComponent("\(name).pdf")
        let data = try XCTUnwrap(pdf.dataRepresentation())
        try data.write(to: url)
        return url
    }

    func test_merge_appendsSourcePagesToTargetAndDeletesSource() throws {
        let storage = DocumentStorage(documentsURL: tempDir)
        let target = try writePDF("Target", pages: 2)
        let source = try writePDF("Source", pages: 3)

        try DocumentMerge.merge(source: source, into: target,
                                targetName: "Target", using: storage)

        let merged = try XCTUnwrap(PDFDocument(url: target))
        XCTAssertEqual(merged.pageCount, 5, "target should hold both docs' pages")
        XCTAssertFalse(FileManager.default.fileExists(atPath: source.path),
                       "source file should be deleted after a successful merge")
    }

    func test_merge_unreadableSource_throwsAndDeletesNothing() throws {
        let storage = DocumentStorage(documentsURL: tempDir)
        let target = try writePDF("Target", pages: 2)
        // A non-PDF file standing in for a corrupt/unreadable source.
        let source = tempDir.appendingPathComponent("Source.pdf")
        try Data("not a pdf".utf8).write(to: source)

        XCTAssertThrowsError(
            try DocumentMerge.merge(source: source, into: target,
                                    targetName: "Target", using: storage))

        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path),
                      "source must NOT be deleted when the merge fails")
        let untouched = try XCTUnwrap(PDFDocument(url: target))
        XCTAssertEqual(untouched.pageCount, 2, "target must be unchanged on failure")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme DocumentScanner -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:DocumentScannerTests/DocumentMergeTests`
Expected: FAIL — `cannot find 'DocumentMerge' in scope`.

- [ ] **Step 3: Write minimal implementation**

Create `DocumentScanner/DocumentScanner/Pipeline/DocumentMerge.swift`:

```swift
import PDFKit

enum DocumentMergeError: Error {
    /// The source or target PDF could not be read.
    case unreadable
}

/// File-level orchestration for merging one document into another: append the
/// source's pages to the end of the target, save the target in place, then
/// delete the source. The source is deleted ONLY after the target saves, so a
/// load or save failure never loses data (both originals survive).
enum DocumentMerge {
    static func merge(source: URL, into target: URL,
                      targetName: String, using storage: DocumentStorage) throws {
        guard let targetPDF = PDFDocument(url: target),
              let sourcePDF = PDFDocument(url: source) else {
            throw DocumentMergeError.unreadable
        }
        DocumentMutations.append(sourcePDF, to: targetPDF)
        _ = try storage.write(targetPDF, replacing: target, withName: targetName)
        try storage.delete(at: source)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme DocumentScanner -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:DocumentScannerTests/DocumentMergeTests`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add DocumentScanner/DocumentScanner/Pipeline/DocumentMerge.swift DocumentScanner/DocumentScannerTests/DocumentMergeTests.swift
git commit -m "feat: add DocumentMerge file orchestration"
```

---

### Task 3: `MergeIntoMenu` view

**Files:**
- Create: `DocumentScanner/DocumentScanner/Library/MergeIntoMenu.swift`

No unit test — this is a thin SwiftUI view (the sibling `MoveToMenu` has none either). It is exercised through the wiring in Tasks 4–5 and the on-device smoke test.

- [ ] **Step 1: Create the view**

Create `DocumentScanner/DocumentScanner/Library/MergeIntoMenu.swift`:

```swift
import SwiftUI

/// A "Merge into…" submenu for a document's context menu. Lists the documents
/// the source may be merged into and calls `merge` with the chosen target.
/// Renders nothing when there are no candidates, so callers can place it
/// unconditionally. Mirrors `MoveToMenu`.
struct MergeIntoMenu: View {
    /// The document being merged (the one that will be absorbed and deleted).
    let source: DocumentSummary
    /// Eligible targets (from `MergeCandidates.list`).
    let candidates: [DocumentSummary]
    /// Invoked with the chosen target document.
    let merge: (DocumentSummary) -> Void

    var body: some View {
        if !candidates.isEmpty {
            Menu {
                ForEach(candidates) { target in
                    Button(target.displayName) { merge(target) }
                }
            } label: {
                Label("Merge into…", systemImage: "arrow.triangle.merge")
            }
        }
    }
}
```

- [ ] **Step 2: Verify it builds**

Run: `xcodebuild build -scheme DocumentScanner -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add DocumentScanner/DocumentScanner/Library/MergeIntoMenu.swift
git commit -m "feat: add MergeIntoMenu view"
```

---

### Task 4: Wire merge into `LibraryView`

**Files:**
- Modify: `DocumentScanner/DocumentScanner/Library/LibraryView.swift`

This adds the menu item, a `MergePlan` value, a confirmation alert, an error alert, and the `mergeDocument` method. There is no unit test for this view wiring (SwiftUI view, consistent with how move/delete are wired); verification is a successful build plus the full suite, then the on-device smoke test in Task 6.

- [ ] **Step 1: Add the `MergePlan` type and state**

In `LibraryView.swift`, find the existing delete state declaration (around line 24):

```swift
    @State private var docBeingDeleted: DocumentSummary?
```

Add immediately after it:

```swift
    @State private var mergePlan: MergePlan?
    @State private var mergeError: String?
```

Then add this nested type. Place it just below the `@State` block, before the `body` (match the file's existing style for small helper types; if none is nearby, put it at the end of the struct):

```swift
    /// A pending merge awaiting confirmation: `source` will be absorbed into
    /// `target`, then deleted.
    struct MergePlan {
        let source: DocumentSummary
        let target: DocumentSummary
    }
```

- [ ] **Step 2: Add `MergeIntoMenu` to the document context menu**

In `docContextMenu(_:)` (around line 260), the non-corrupt branch currently reads:

```swift
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
```

Insert the `MergeIntoMenu` between the `MoveToMenu` block and the Delete button:

```swift
            if showFolders {
                MoveToMenu(
                    currentParent: summary.url.deletingLastPathComponent(),
                    root: storage.documentsURL,
                    folders: folders,
                    move: { moveDocument(summary, to: $0) }
                )
            }
            MergeIntoMenu(
                source: summary,
                candidates: MergeCandidates.list(source: summary, all: store.summaries),
                merge: { target in mergePlan = MergePlan(source: summary, target: target) }
            )
            Button(role: .destructive) {
                docBeingDeleted = summary
            } label: {
                Label("Delete", systemImage: "trash")
            }
```

- [ ] **Step 3: Add the confirmation and error alerts**

Find the end of the delete alert (around line 208), which closes with:

```swift
            } message: { summary in
                Text("This will permanently remove \"\(summary.displayName).pdf\".")
            }
```

Add these two alerts immediately after it (before `.task { refreshFolders() }`):

```swift
            .alert(
                "Merge \"\(mergePlan?.source.displayName ?? "")\" into \"\(mergePlan?.target.displayName ?? "")\"?",
                isPresented: Binding(
                    get: { mergePlan != nil },
                    set: { if !$0 { mergePlan = nil } }
                ),
                presenting: mergePlan
            ) { plan in
                Button("Merge") { mergeDocument(plan.source, into: plan.target) }
                Button("Cancel", role: .cancel) {}
            } message: { plan in
                Text("\"\(plan.source.displayName)\"'s pages will be added to the end of \"\(plan.target.displayName)\", and \"\(plan.source.displayName)\" will be deleted.")
            }
            .alert(
                "Couldn't merge",
                isPresented: Binding(
                    get: { mergeError != nil },
                    set: { if !$0 { mergeError = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(mergeError ?? "")
            }
```

- [ ] **Step 4: Add the `mergeDocument` method**

Find `moveDocument(_:to:)` (around line 483) and add this method immediately after it:

```swift
    private func mergeDocument(_ source: DocumentSummary, into target: DocumentSummary) {
        do {
            try DocumentMerge.merge(source: source.url, into: target.url,
                                    targetName: target.displayName, using: storage)
            store.refresh()
        } catch {
            mergeError = "Couldn't merge \"\(source.displayName)\" into \"\(target.displayName)\". Please try again."
        }
    }
```

- [ ] **Step 5: Build and run the full suite**

Run: `xcodebuild test -scheme DocumentScanner -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:DocumentScannerTests`
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add DocumentScanner/DocumentScanner/Library/LibraryView.swift
git commit -m "feat: wire Merge into… into the library context menu"
```

---

### Task 5: Wire merge into `FolderContentsView`

**Files:**
- Modify: `DocumentScanner/DocumentScanner/Library/FolderContentsView.swift`

Same wiring as Task 4, adapted to this view. `FolderContentsView` already holds `store` (full `store.summaries`) and `storage`. The merge writes to the target's own URL and deletes the source by absolute URL, so it works regardless of which folder either document lives in.

- [ ] **Step 1: Add the `MergePlan` type and state**

In `FolderContentsView.swift`, find the existing delete state (around line 24):

```swift
    @State private var docBeingDeleted: DocumentSummary?
```

Add immediately after it:

```swift
    @State private var mergePlan: MergePlan?
    @State private var mergeError: String?
```

Add the nested type below the `@State` block, before `body`:

```swift
    /// A pending merge awaiting confirmation: `source` will be absorbed into
    /// `target`, then deleted.
    struct MergePlan {
        let source: DocumentSummary
        let target: DocumentSummary
    }
```

- [ ] **Step 2: Add `MergeIntoMenu` to the document context menu**

In `docContextMenu(_:)` (around line 170), find the `MoveToMenu(` block and the Delete button that follow it. Insert the `MergeIntoMenu` between them, matching this shape (use the existing `MoveToMenu` block in the file verbatim for its arguments; only the inserted `MergeIntoMenu` is shown here):

```swift
            MergeIntoMenu(
                source: summary,
                candidates: MergeCandidates.list(source: summary, all: store.summaries),
                merge: { target in mergePlan = MergePlan(source: summary, target: target) }
            )
```

It must sit after the `MoveToMenu { … }` call and before the `Button(role: .destructive) { docBeingDeleted = summary } …` Delete button in the non-corrupt branch.

- [ ] **Step 3: Add the confirmation and error alerts**

Find the delete confirmation alert in this view (it presents `docBeingDeleted`, mirroring `LibraryView`). Immediately after that alert's closing `}`, add the same two alerts as in Task 4 Step 3:

```swift
            .alert(
                "Merge \"\(mergePlan?.source.displayName ?? "")\" into \"\(mergePlan?.target.displayName ?? "")\"?",
                isPresented: Binding(
                    get: { mergePlan != nil },
                    set: { if !$0 { mergePlan = nil } }
                ),
                presenting: mergePlan
            ) { plan in
                Button("Merge") { mergeDocument(plan.source, into: plan.target) }
                Button("Cancel", role: .cancel) {}
            } message: { plan in
                Text("\"\(plan.source.displayName)\"'s pages will be added to the end of \"\(plan.target.displayName)\", and \"\(plan.source.displayName)\" will be deleted.")
            }
            .alert(
                "Couldn't merge",
                isPresented: Binding(
                    get: { mergeError != nil },
                    set: { if !$0 { mergeError = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(mergeError ?? "")
            }
```

- [ ] **Step 4: Add the `mergeDocument` method**

Add this method near the view's other document actions (e.g. after its delete/move handling):

```swift
    private func mergeDocument(_ source: DocumentSummary, into target: DocumentSummary) {
        do {
            try DocumentMerge.merge(source: source.url, into: target.url,
                                    targetName: target.displayName, using: storage)
            store.refresh()
        } catch {
            mergeError = "Couldn't merge \"\(source.displayName)\" into \"\(target.displayName)\". Please try again."
        }
    }
```

- [ ] **Step 5: Build and run the full suite**

Run: `xcodebuild test -scheme DocumentScanner -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:DocumentScannerTests`
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add DocumentScanner/DocumentScanner/Library/FolderContentsView.swift
git commit -m "feat: wire Merge into… into folder contents context menu"
```

---

### Task 6: Final verification + roadmap

**Files:**
- Modify: `docs/FutureEnhancements.md`

- [ ] **Step 1: Full build + test**

Run from `DocumentScanner/`:
`xcodebuild test -scheme DocumentScanner -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:DocumentScannerTests`
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 2: On-device smoke test (manual)**

Verify on device:
1. Long-press a document → **Merge into…** appears (only when ≥2 valid docs exist).
2. The submenu lists every *other* valid document (across folders), not the long-pressed one, and not any corrupt "🚫" doc.
3. Pick a target → confirm alert names both documents → **Merge**.
4. The source disappears; the target now ends with the source's pages (open it: original pages first, then the merged-in pages; any OCR text is still searchable and any signature/highlight marks survive).
5. **Cancel** leaves both documents untouched.
6. Repeat from inside a folder (FolderContentsView) — same behavior; a folder doc can be merged into a root doc and vice-versa.

- [ ] **Step 3: Mark the roadmap item shipped**

In `docs/FutureEnhancements.md`, under `### Documents`, replace the "Merge two documents" bullet (currently):

```markdown
- **Merge two documents** — combine two existing scans into one PDF. The engine already supports it (`DocumentMutations.append`); this just needs a "Merge into…" / "Combine" UI (e.g. a library multi-select, or a context-menu action that picks a target document). Useful when something was scanned across two sessions.
```

with:

```markdown
- ~~**Merge two documents (v2.2)**~~ — **Shipped 2026-06-25.** Long-press a document → **Merge into…** → pick a target; the source's pages append to the end of the target (lossless — OCR text + annotations preserved), the target keeps its name/location, and the source is deleted (confirmed first). Pure `MergeCandidates` (targets = all other non-corrupt docs) + `DocumentMerge` orchestration (append → save target in place → delete source, in that safe order) + `MergeIntoMenu`; wired into both `LibraryView` and `FolderContentsView`. Spec: `docs/superpowers/specs/2026-06-25-merge-documents-design.md`.
```

- [ ] **Step 4: Commit**

```bash
git add docs/FutureEnhancements.md
git commit -m "docs: mark merge two documents shipped (v2.2)"
```

---

## Notes for the implementer

- **Lossless append is inherent:** `DocumentMutations.append` inserts the actual `PDFPage` objects, so the OCR text layer and annotations (signatures/highlights) ride along — no flatten needed. `DocumentMutationsTests.test_append_addsNewPagesToEnd` already covers the page-count behavior; Task 2 covers the file orchestration.
- **Safe delete ordering is the whole point:** in `DocumentMerge`, the source is deleted only after `storage.write(replacing:)` returns. `write(_:replacing:withName:)` is atomic + file-coordinated, so the target is never half-written. Do not reorder these.
- **Why `targetName` is passed:** `write(_:replacing:withName:)` keeps the file at the target's URL when the name is unchanged (the same-name fast path), so passing `target.displayName` overwrites the target in place rather than creating a `(2)` copy.
- **No version bump here** — that happens at archive time for v2.2 (see the `project-archive-checklist` / `project-v1-status` notes).
