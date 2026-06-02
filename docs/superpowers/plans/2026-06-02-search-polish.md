# Search polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Two-item v1.2 search polish: (1) horizontal highlight accuracy via text-matrix scaling in `PDFAssembler.drawInvisibleText`, (2) cross-doc match navigation via a new `SearchContext` value type passed from library into viewer.

**Architecture:** Item 1 is a self-contained edit to one function in `PDFAssembler` (write path; affects new scans only). Item 2 introduces a `SearchContext` value type, modifies `LibraryView` to compute and pass it on navigation, and modifies `DocumentViewerView` to drive cross-doc transitions via a `currentDocIndex` state and a per-doc `SearchHighlight`. The two items don't share code.

**Tech Stack:** Swift 5+, SwiftUI, PDFKit (`PDFDocument.findString`, `PDFSelection.bounds(for:)`), CoreText (`CTLineCreateWithAttributedString`, `CTLineGetTypographicBounds`), CoreGraphics (`CGContext.textMatrix`), XCTest.

**Spec:** `docs/superpowers/specs/2026-06-02-search-polish-design.md`

---

## Background for the engineer

Pocket Scanner is a SwiftUI iOS document scanner. Two pieces of background that aren't obvious from the file names:

1. **Search has two layers.** The *library* filters docs by substring-matching the `ocrSnippet` field in `DocumentSummary` (which is just `pdf.string`). The *viewer* runs `PDFDocument.findString` on the loaded PDF to get `[PDFSelection]` and renders highlights via `PDFAnnotation` (PDFView's `highlightedSelections` doesn't reliably draw on iOS — confirmed in `Viewer/DocumentViewerView.swift:209-210`).

2. **The invisible text trick.** `PDFAssembler` draws an image-as-page and then overlays each OCR observation as invisible CoreText glyphs at the observation's normalized bounding box. PDFKit's `findString` returns selections based on those glyph positions. The glyphs are drawn with system font at a font size equal to the box height — **but the glyph widths (system font) don't match the original scanned glyph widths**, which is why highlights drift horizontally. The fix in Item 1 scales the text matrix x-axis so glyphs span the OCR rect width exactly.

**Project structure:**
- App code: `DocumentScanner/DocumentScanner/`
- Tests: `DocumentScanner/DocumentScannerTests/`
- Xcode project: `DocumentScanner/DocumentScanner.xcodeproj`

**How to run tests** (from repo root):

```bash
xcodebuild test \
  -project DocumentScanner/DocumentScanner.xcodeproj \
  -scheme DocumentScanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:DocumentScannerTests
```

If `iPhone 17 Pro` isn't available, run `xcrun simctl list devices available` and pick another iPhone running iOS 17+.

**`OCRObservation` type:**

```swift
struct OCRObservation {
    let string: String
    let boundingBox: CGRect  // Vision-normalized: 0…1, origin bottom-left
}
```

Defined in `DocumentScanner/Pipeline/OCREngine.swift`. Already used throughout the pipeline.

---

## File Structure

**Item 1 (Task 1):**
- Modify: `DocumentScanner/DocumentScanner/Pipeline/PDFAssembler.swift` — function `drawInvisibleText` (currently lines 106-140)
- Create: `DocumentScanner/DocumentScannerTests/PDFAssemblerHighlightTests.swift` — new test file

**Item 2 (Tasks 2-4):**
- Create: `DocumentScanner/DocumentScanner/Viewer/SearchContext.swift` — value type holding cross-doc search state
- Create: `DocumentScanner/DocumentScannerTests/SearchContextTests.swift` — value-type tests
- Modify: `DocumentScanner/DocumentScanner/Library/LibraryView.swift` — add `searchContext` computed property, pass into viewer
- Modify: `DocumentScanner/DocumentScanner/Viewer/DocumentViewerView.swift` — replace `searchTerm: String?` with `searchContext: SearchContext?`, add `currentDocIndex` state, cross-doc next/prev handlers, updated counter

No file deletions. No changes to `SearchHighlight.swift` (still per-doc).

---

### Task 1: Horizontal highlight accuracy in `PDFAssembler`

**Files:**
- Modify: `DocumentScanner/DocumentScanner/Pipeline/PDFAssembler.swift` (the `drawInvisibleText` function body)
- Create: `DocumentScanner/DocumentScannerTests/PDFAssemblerHighlightTests.swift`

- [ ] **Step 1: Confirm existing tests pass on the current code**

Run:

```bash
xcodebuild test \
  -project DocumentScanner/DocumentScanner.xcodeproj \
  -scheme DocumentScanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:DocumentScannerTests
```

Expected: all currently-existing tests pass. Baseline before changes.

- [ ] **Step 2: Write the failing test for highlight accuracy**

Create `DocumentScanner/DocumentScannerTests/PDFAssemblerHighlightTests.swift`:

```swift
import XCTest
import PDFKit
import UIKit
@testable import DocumentScanner

final class PDFAssemblerHighlightTests: XCTestCase {

    /// Assembles a 1-page PDF with a single OCR observation, runs findString
    /// for that observation's string, and asserts the resulting PDFSelection's
    /// bounds match the OCR rect within ~5pt horizontal tolerance.
    ///
    /// The previous implementation (no text-matrix scaling) drifts much further
    /// than 5pt because system-font glyph widths don't match the original.
    func test_findStringHighlight_matchesOCRRectWidth() throws {
        // 612x792pt page (US Letter).
        let pageSize = CGSize(width: 612, height: 792)

        // OCR observation: a 30pt-tall band, 400pt wide, positioned 100pt in.
        let ocrRect = CGRect(x: 100, y: 200, width: 400, height: 30)
        let normalized = CGRect(
            x: ocrRect.origin.x / pageSize.width,
            y: ocrRect.origin.y / pageSize.height,
            width: ocrRect.width / pageSize.width,
            height: ocrRect.height / pageSize.height
        )
        let observation = OCRObservation(
            string: "Quick brown fox jumps over the lazy dog",
            boundingBox: normalized
        )

        let image = blankImage(size: pageSize)
        let scanned = ScannedPage(image: image, observations: [observation])
        let pdf = try PDFAssembler().assemble(pages: [scanned], createdAt: Date())

        let selections = pdf.findString(observation.string, withOptions: .caseInsensitive)
        let selection = try XCTUnwrap(selections.first,
                                      "Expected findString to return a match for the observation")

        let page = try XCTUnwrap(pdf.page(at: 0))
        let bounds = selection.bounds(for: page)

        // The OCR rect is in PDF page coordinates (origin bottom-left, y-up).
        // After text-matrix scaling, the selection's x-extent should align
        // with the OCR rect within ~5pt slack.
        XCTAssertEqual(bounds.minX, ocrRect.minX, accuracy: 5,
                       "Selection minX should align with OCR rect minX")
        XCTAssertEqual(bounds.width, ocrRect.width, accuracy: 5,
                       "Selection width should align with OCR rect width")
    }

    // MARK: - Helpers

    private func blankImage(size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }
}
```

- [ ] **Step 3: Run the new test to verify it fails**

```bash
xcodebuild test \
  -project DocumentScanner/DocumentScanner.xcodeproj \
  -scheme DocumentScanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:DocumentScannerTests/PDFAssemblerHighlightTests
```

Expected: `test_findStringHighlight_matchesOCRRectWidth` FAILS because the current `drawInvisibleText` uses system-font widths. The selection width will be off by more than 5pt (typically 30-100pt difference depending on the string).

If the test passes unexpectedly, something's odd — re-read the test carefully before moving on.

- [ ] **Step 4: Modify `drawInvisibleText` to scale the text matrix**

Open `DocumentScanner/DocumentScanner/Pipeline/PDFAssembler.swift`. Find the `drawInvisibleText` function (around line 106). Replace the inner loop body (the part starting at `let font = UIFont.systemFont(...)`  through `CTLineDraw(ctLine, context)`) with this:

```swift
            // Size the font so the rendered glyphs roughly match the observed
            // line height. Then scale the text matrix horizontally so the
            // rendered glyphs span exactly the OCR rect's width — PDFKit's
            // findString reads glyph positions from the post-scale text state,
            // so highlights snap to the OCR width rather than drifting with
            // system-font widths.
            let font = UIFont.systemFont(ofSize: rect.height)
            let attributed = NSAttributedString(
                string: observation.string,
                attributes: [
                    .font: font,
                    .foregroundColor: UIColor.clear,
                ]
            )
            let ctLine = CTLineCreateWithAttributedString(attributed)

            let naturalWidth = CGFloat(CTLineGetTypographicBounds(ctLine, nil, nil, nil))
            let scaleX: CGFloat = naturalWidth > 0 ? rect.width / naturalWidth : 1

            context.textPosition = CGPoint(x: rect.origin.x, y: rect.origin.y)
            context.textMatrix = CGAffineTransform(scaleX: scaleX, y: 1)
            CTLineDraw(ctLine, context)
```

The function should end up looking like (whole function for clarity):

```swift
    private func drawInvisibleText(_ observations: [OCRObservation], in pageRect: CGRect, into context: CGContext) {
        context.saveGState()
        context.setTextDrawingMode(.invisible)

        for observation in observations {
            // Vision returns normalized coords (0…1, origin bottom-left, y-up).
            // CGContext PDF coords are also origin bottom-left, y-up — no flip needed.
            let bbox = observation.boundingBox
            let rect = CGRect(
                x: bbox.origin.x * pageRect.width,
                y: bbox.origin.y * pageRect.height,
                width: bbox.width * pageRect.width,
                height: bbox.height * pageRect.height
            )
            guard rect.height > 0, rect.width > 0 else { continue }

            // Size the font so the rendered glyphs roughly match the observed
            // line height. Then scale the text matrix horizontally so the
            // rendered glyphs span exactly the OCR rect's width — PDFKit's
            // findString reads glyph positions from the post-scale text state,
            // so highlights snap to the OCR width rather than drifting with
            // system-font widths.
            let font = UIFont.systemFont(ofSize: rect.height)
            let attributed = NSAttributedString(
                string: observation.string,
                attributes: [
                    .font: font,
                    .foregroundColor: UIColor.clear,
                ]
            )
            let ctLine = CTLineCreateWithAttributedString(attributed)

            let naturalWidth = CGFloat(CTLineGetTypographicBounds(ctLine, nil, nil, nil))
            let scaleX: CGFloat = naturalWidth > 0 ? rect.width / naturalWidth : 1

            context.textPosition = CGPoint(x: rect.origin.x, y: rect.origin.y)
            context.textMatrix = CGAffineTransform(scaleX: scaleX, y: 1)
            CTLineDraw(ctLine, context)
        }

        context.restoreGState()
    }
```

- [ ] **Step 5: Run the new test to verify it passes**

```bash
xcodebuild test \
  -project DocumentScanner/DocumentScanner.xcodeproj \
  -scheme DocumentScanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:DocumentScannerTests/PDFAssemblerHighlightTests
```

Expected: `test_findStringHighlight_matchesOCRRectWidth` PASSES.

- [ ] **Step 6: Run the full test target to confirm no regressions**

```bash
xcodebuild test \
  -project DocumentScanner/DocumentScanner.xcodeproj \
  -scheme DocumentScanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:DocumentScannerTests
```

Expected: all tests pass (existing tests + the new one).

- [ ] **Step 7: Commit**

```bash
git add DocumentScanner/DocumentScanner/Pipeline/PDFAssembler.swift \
        DocumentScanner/DocumentScannerTests/PDFAssemblerHighlightTests.swift
git commit -m "$(cat <<'EOF'
PDFAssembler: scale text matrix x-axis to align highlights with OCR

Per-observation invisible-text glyphs are now scaled horizontally so
they span the OCR boundingBox width exactly. PDFKit's findString reads
glyph positions from the post-scale text state, so highlights snap to
the same width as the visible scanned text instead of drifting with
system-font glyph widths.

New scans only — existing PDFs keep their pre-scale highlight geometry.

Spec: docs/superpowers/specs/2026-06-02-search-polish-design.md (Item 1)
EOF
)"
```

---

### Task 2: `SearchContext` value type

**Files:**
- Create: `DocumentScanner/DocumentScanner/Viewer/SearchContext.swift`
- Create: `DocumentScanner/DocumentScannerTests/SearchContextTests.swift`

- [ ] **Step 1: Write the failing tests for `SearchContext`**

Create `DocumentScanner/DocumentScannerTests/SearchContextTests.swift`:

```swift
import XCTest
import Foundation
@testable import DocumentScanner

final class SearchContextTests: XCTestCase {

    func test_totalMatches_sumsAcrossDocs() {
        let ctx = SearchContext(
            term: "fox",
            docs: [
                .init(summary: makeSummary(name: "a"), matchCount: 3),
                .init(summary: makeSummary(name: "b"), matchCount: 5),
                .init(summary: makeSummary(name: "c"), matchCount: 1),
            ],
            startDocIndex: 0
        )
        XCTAssertEqual(ctx.totalMatches, 9)
    }

    func test_totalMatches_zeroWhenDocsEmpty() {
        let ctx = SearchContext(term: "fox", docs: [], startDocIndex: 0)
        XCTAssertEqual(ctx.totalMatches, 0)
    }

    func test_hashable_equalContextsAreEqual() {
        let docs: [SearchContext.DocEntry] = [
            .init(summary: makeSummary(name: "a"), matchCount: 2),
        ]
        let a = SearchContext(term: "fox", docs: docs, startDocIndex: 0)
        let b = SearchContext(term: "fox", docs: docs, startDocIndex: 0)
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.hashValue, b.hashValue)
    }

    func test_hashable_differentStartIndexNotEqual() {
        let docs: [SearchContext.DocEntry] = [
            .init(summary: makeSummary(name: "a"), matchCount: 2),
            .init(summary: makeSummary(name: "b"), matchCount: 1),
        ]
        let a = SearchContext(term: "fox", docs: docs, startDocIndex: 0)
        let b = SearchContext(term: "fox", docs: docs, startDocIndex: 1)
        XCTAssertNotEqual(a, b)
    }

    // MARK: - Helpers

    private func makeSummary(name: String) -> DocumentSummary {
        DocumentSummary(
            url: URL(fileURLWithPath: "/tmp/\(name).pdf"),
            displayName: name,
            createdAt: Date(timeIntervalSince1970: 0),
            pageCount: 1,
            ocrSnippet: "the quick brown \(name)",
            isCorrupt: false
        )
    }
}
```

If `DocumentSummary`'s initializer differs from this helper, adapt the helper to match (read `DocumentScanner/Library/DocumentSummary.swift` to confirm signature; it currently has fields `url`, `displayName`, `createdAt`, `pageCount`, `ocrSnippet`, `isCorrupt`).

- [ ] **Step 2: Run the test to verify it fails**

```bash
xcodebuild test \
  -project DocumentScanner/DocumentScanner.xcodeproj \
  -scheme DocumentScanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:DocumentScannerTests/SearchContextTests
```

Expected: build FAILS because `SearchContext` doesn't exist.

- [ ] **Step 3: Create `SearchContext.swift`**

Create `DocumentScanner/DocumentScanner/Viewer/SearchContext.swift`:

```swift
import Foundation

/// Cross-document search state passed from `LibraryView` into
/// `DocumentViewerView`. Holds the search term and an ordered list of
/// docs that have matches; `startDocIndex` selects which doc the viewer
/// opens first.
///
/// Per-doc `[PDFSelection]` arrays are *not* stored here — they hold
/// strong references to their `PDFDocument`, and we don't want every
/// matching doc parsed in memory just to know the cross-doc counts.
/// The viewer recomputes selections lazily when it loads each doc.
struct SearchContext: Hashable {
    let term: String
    let docs: [DocEntry]
    let startDocIndex: Int

    struct DocEntry: Hashable {
        let summary: DocumentSummary
        let matchCount: Int
    }

    /// Total matches across every doc in `docs`.
    var totalMatches: Int {
        docs.reduce(0) { $0 + $1.matchCount }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodebuild test \
  -project DocumentScanner/DocumentScanner.xcodeproj \
  -scheme DocumentScanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:DocumentScannerTests/SearchContextTests
```

Expected: all 4 tests pass.

- [ ] **Step 5: Commit**

```bash
git add DocumentScanner/DocumentScanner/Viewer/SearchContext.swift \
        DocumentScanner/DocumentScannerTests/SearchContextTests.swift
git commit -m "$(cat <<'EOF'
SearchContext: value type for cross-doc search state

Holds the search term, an ordered list of matching docs (DocumentSummary
+ matchCount), and a start doc index. totalMatches sums across docs.
Per-doc PDFSelection arrays are deliberately not stored — the viewer
recomputes them lazily when it loads each doc.

Spec: docs/superpowers/specs/2026-06-02-search-polish-design.md (Item 2a)
EOF
)"
```

---

### Task 3: `LibraryView` builds the `SearchContext`

**Files:**
- Modify: `DocumentScanner/DocumentScanner/Library/LibraryView.swift`

This task wires the library to compute the cross-doc search state and pass it into the viewer. The viewer will still accept the old `searchTerm: String?` parameter for now (we change the viewer in Task 4) — but to keep the build green at the end of this task, we instead update the viewer's parameter list in this same commit. We do not yet add cross-doc navigation logic in the viewer.

**Note: this task changes the viewer's parameter signature only.** Functional cross-doc navigation comes in Task 4.

- [ ] **Step 1: Read the current `LibraryView` filtered docs + nav destination**

Read `DocumentScanner/DocumentScanner/Library/LibraryView.swift`. The key sections:

- `filteredDocs` computed property (around line 270)
- `.navigationDestination(for: DocumentSummary.self)` block (around line 82) where it passes `searchTerm:` into `DocumentViewerView`

You will add a new `searchContext` computed property near `filteredDocs`, and rewrite the destination block.

- [ ] **Step 2: Add the `searchContext` computed property**

After the existing `filteredDocs` property in `LibraryView.swift`, add (this needs to be inside the same struct, between `filteredDocs` and `triggerScan`):

```swift
    /// Cross-doc search state: enumerates `filteredDocs` and runs
    /// PDFKit `findString` against each, recording per-doc match counts.
    /// Returns nil when the search field is empty or no doc has matches.
    ///
    /// `startDocIndex` is set to 0 here; the navigation destination
    /// overrides it with the tapped doc's index.
    private var searchContext: SearchContext? {
        guard !searchText.isEmpty else { return nil }
        let entries: [SearchContext.DocEntry] = filteredDocs.compactMap { summary in
            guard let pdf = PDFDocument(url: summary.url) else { return nil }
            let count = pdf.findString(searchText, withOptions: .caseInsensitive).count
            return count > 0 ? .init(summary: summary, matchCount: count) : nil
        }
        return entries.isEmpty ? nil
            : SearchContext(term: searchText, docs: entries, startDocIndex: 0)
    }
```

You'll also need to import `PDFKit` at the top of the file if it isn't already. Check the existing imports — if `PDFKit` isn't there, add `import PDFKit` after the existing imports.

- [ ] **Step 3: Rewrite the navigation destination to pass `searchContext`**

In `LibraryView.swift`, find the `.navigationDestination(for: DocumentSummary.self)` block (around line 82). It currently looks like:

```swift
            .navigationDestination(for: DocumentSummary.self) { summary in
                DocumentViewerView(
                    summary: summary,
                    storage: storage,
                    scannerPresenter: scannerPresenter,
                    pipeline: pipeline,
                    searchTerm: searchText.isEmpty ? nil : searchText,
                    onDeleted: {
                        store.refresh()
                        path.removeLast()
                    }
                )
            }
```

Replace with:

```swift
            .navigationDestination(for: DocumentSummary.self) { summary in
                DocumentViewerView(
                    summary: summary,
                    storage: storage,
                    scannerPresenter: scannerPresenter,
                    pipeline: pipeline,
                    searchContext: searchContextStarting(at: summary),
                    onDeleted: {
                        store.refresh()
                        path.removeLast()
                    }
                )
            }
```

Then add a helper method inside `LibraryView` (near the bottom of the struct, alongside `triggerScan`):

```swift
    /// Returns the current cross-doc search context with `startDocIndex`
    /// pointing at the tapped summary's position. Returns nil when there's
    /// no active search.
    private func searchContextStarting(at summary: DocumentSummary) -> SearchContext? {
        guard let ctx = searchContext else { return nil }
        let idx = ctx.docs.firstIndex(where: { $0.summary.id == summary.id }) ?? 0
        return SearchContext(term: ctx.term, docs: ctx.docs, startDocIndex: idx)
    }
```

- [ ] **Step 4: Also update `FolderContentsView`**

`FolderContentsView` likely passes `searchTerm:` the same way `LibraryView` does. Find any `DocumentViewerView(` call in `DocumentScanner/DocumentScanner/Library/FolderContentsView.swift` and update it to use `searchContext:` similarly. Since folder contents are scoped to a folder, build a `SearchContext` from the folder's filtered docs (not the whole library). If `FolderContentsView` doesn't currently pass a `searchTerm`, pass `searchContext: nil` instead — but verify.

Quick check command:

```bash
grep -n "searchTerm\|DocumentViewerView(" DocumentScanner/DocumentScanner/Library/FolderContentsView.swift
```

If `FolderContentsView` passes `searchTerm:`, replicate the same pattern as `LibraryView` (search field → filtered docs → searchContext builder → starting-at helper). If it doesn't, replace `searchTerm:` with `searchContext: nil` and move on.

- [ ] **Step 5: Update `DocumentViewerView` parameter signature (signature only)**

This step ONLY changes the viewer's parameter list and the `rebuildHighlight` reference to `searchTerm` so the build compiles. Cross-doc navigation logic comes in Task 4.

In `DocumentScanner/DocumentScanner/Viewer/DocumentViewerView.swift`, change:

```swift
    let searchTerm: String?
```

to:

```swift
    let searchContext: SearchContext?
```

Then change `rebuildHighlight` (currently around line 169) from:

```swift
    private func rebuildHighlight(session: DocumentSession) {
        guard let term = searchTerm, !term.isEmpty else {
            searchHighlight = nil
            return
        }
        let matches = session.pdf.findString(term, withOptions: .caseInsensitive)
        searchHighlight = SearchHighlight(matches: matches)
    }
```

to:

```swift
    private func rebuildHighlight(session: DocumentSession) {
        guard let term = searchContext?.term, !term.isEmpty else {
            searchHighlight = nil
            return
        }
        let matches = session.pdf.findString(term, withOptions: .caseInsensitive)
        searchHighlight = SearchHighlight(matches: matches)
    }
```

This keeps the existing single-doc behavior intact; Task 4 adds the cross-doc navigation on top.

- [ ] **Step 6: Build to confirm everything compiles**

```bash
xcodebuild build \
  -project DocumentScanner/DocumentScanner.xcodeproj \
  -scheme DocumentScanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: build succeeds.

- [ ] **Step 7: Run the full test suite**

```bash
xcodebuild test \
  -project DocumentScanner/DocumentScanner.xcodeproj \
  -scheme DocumentScanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:DocumentScannerTests
```

Expected: all tests pass. The behavior change at runtime: the viewer now opens the tapped doc as usual, with single-doc next/prev (unchanged), but `searchContext.docs` carries other matching docs for Task 4 to consume.

- [ ] **Step 8: Commit**

```bash
git add DocumentScanner/DocumentScanner/Library/LibraryView.swift \
        DocumentScanner/DocumentScanner/Library/FolderContentsView.swift \
        DocumentScanner/DocumentScanner/Viewer/DocumentViewerView.swift
git commit -m "$(cat <<'EOF'
LibraryView+FolderContentsView: build and pass SearchContext to viewer

LibraryView now computes a SearchContext when searchText is non-empty,
running PDFKit findString against each filtered doc to get accurate
per-doc match counts. The navigation destination overrides
startDocIndex with the tapped summary's position. DocumentViewerView's
searchTerm parameter is replaced with searchContext (signature change
only — cross-doc navigation logic lands in the next commit).
FolderContentsView mirrors the LibraryView pattern.

Spec: docs/superpowers/specs/2026-06-02-search-polish-design.md (Item 2b)
EOF
)"
```

---

### Task 4: Cross-doc next/prev in `DocumentViewerView`

**Files:**
- Modify: `DocumentScanner/DocumentScanner/Viewer/DocumentViewerView.swift`

- [ ] **Step 1: Add cross-doc state and helpers**

In `DocumentScanner/DocumentScanner/Viewer/DocumentViewerView.swift`, add `@State` properties alongside the existing ones (near `@State private var searchHighlight: SearchHighlight?`):

```swift
    @State private var currentDocIndex: Int = 0
    @State private var pendingJumpToLastMatch: Bool = false
```

Add the doc-availability computed properties (anywhere in the struct, near `rebuildHighlight`):

```swift
    private var hasNextDoc: Bool {
        guard let ctx = searchContext else { return false }
        return currentDocIndex < ctx.docs.count - 1
    }

    private var hasPreviousDoc: Bool { currentDocIndex > 0 }
```

Add the next/prev handlers (also near `rebuildHighlight`):

```swift
    private func handleNext(_ h: SearchHighlight) {
        if h.currentIndex == h.matchCount - 1, hasNextDoc {
            currentDocIndex += 1
            // Mutating currentDocIndex changes the session-loading task's id,
            // which triggers a reload and a fresh SearchHighlight pointing at
            // match 0 of the next doc.
        } else {
            h.next()
        }
    }

    private func handlePrevious(_ h: SearchHighlight) {
        if h.currentIndex == 0, hasPreviousDoc {
            pendingJumpToLastMatch = true
            currentDocIndex -= 1
            // rebuildHighlight will see pendingJumpToLastMatch and jump to
            // matchCount-1 after the new highlight is built.
        } else {
            h.previous()
        }
    }
```

- [ ] **Step 2: Wire `currentDocIndex` into session loading**

The viewer currently loads its session with a one-shot `.task` (around line 41):

```swift
        .task {
            do { session = try DocumentSession(summary: summary, storage: storage) }
            catch { loadError = String(describing: error) }
        }
```

But `summary` is now a function of `searchContext?.docs[currentDocIndex]` when search is active. Add a computed property near the top of the struct (above `body`):

```swift
    /// The summary the viewer is currently displaying. Falls back to the
    /// `summary` parameter when there's no search context (single-doc nav).
    private var activeSummary: DocumentSummary {
        searchContext?.docs[safe: currentDocIndex]?.summary ?? summary
    }
```

Add this `Collection` extension at the bottom of the file (outside the struct):

```swift
private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
```

Replace the `.task` block at line 41 with a version keyed on `currentDocIndex`:

```swift
        .task(id: currentDocIndex) {
            session = nil
            loadError = nil
            do { session = try DocumentSession(summary: activeSummary, storage: storage) }
            catch { loadError = String(describing: error) }
        }
```

And initialize `currentDocIndex` from `searchContext?.startDocIndex` via `.onAppear`:

```swift
        .onAppear {
            if let start = searchContext?.startDocIndex, currentDocIndex != start {
                currentDocIndex = start
            }
        }
```

Place the `.onAppear` immediately after the `.task(id:)`.

- [ ] **Step 3: Update `rebuildHighlight` to honor `pendingJumpToLastMatch`**

Replace the current `rebuildHighlight` (which after Task 3 reads `searchContext?.term`) with:

```swift
    private func rebuildHighlight(session: DocumentSession) {
        guard let term = searchContext?.term, !term.isEmpty else {
            searchHighlight = nil
            return
        }
        let matches = session.pdf.findString(term, withOptions: .caseInsensitive)
        let h = SearchHighlight(matches: matches)
        if pendingJumpToLastMatch, h.matchCount > 0 {
            // Jump to the last match — for prev-into-previous-doc transitions.
            for _ in 0..<(h.matchCount - 1) { h.next() }
            pendingJumpToLastMatch = false
        }
        searchHighlight = h
    }
```

(We use the existing `next()` API rather than reaching into `currentIndex` because it's `private(set)`.)

- [ ] **Step 4: Update the toolbar to use handlers + global counter**

Find the toolbar block (around lines 97-103) that currently reads:

```swift
                if let h = searchHighlight, h.matchCount > 0 {
                    Button { h.previous() } label: { Image(systemName: "chevron.up") }
                    Text("\((h.currentIndex ?? 0) + 1) of \(h.matchCount)")
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Button { h.next() } label: { Image(systemName: "chevron.down") }
                    Spacer()
                }
```

Replace with:

```swift
                if let h = searchHighlight, h.matchCount > 0 {
                    Button { handlePrevious(h) } label: { Image(systemName: "chevron.up") }
                    Text(counterLabel(highlight: h))
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Button { handleNext(h) } label: { Image(systemName: "chevron.down") }
                    Spacer()
                }
```

Add the `counterLabel` helper near the other private helpers in the struct:

```swift
    private func counterLabel(highlight h: SearchHighlight) -> String {
        guard let ctx = searchContext else {
            return "\((h.currentIndex ?? 0) + 1) of \(h.matchCount)"
        }
        let priorMatches = ctx.docs[..<currentDocIndex]
            .reduce(0) { $0 + $1.matchCount }
        let global = priorMatches + (h.currentIndex ?? 0) + 1
        return "\(global) of \(ctx.totalMatches) · \(ctx.docs.count) docs"
    }
```

- [ ] **Step 5: Build to confirm compilation**

```bash
xcodebuild build \
  -project DocumentScanner/DocumentScanner.xcodeproj \
  -scheme DocumentScanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: build succeeds.

- [ ] **Step 6: Run the full test suite**

```bash
xcodebuild test \
  -project DocumentScanner/DocumentScanner.xcodeproj \
  -scheme DocumentScanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:DocumentScannerTests
```

Expected: all tests pass. The cross-doc nav itself isn't unit-tested (per the spec); existing tests should continue to pass.

- [ ] **Step 7: Manual verification on device (controller, not subagent, runs this)**

The cross-doc nav can only be meaningfully tested with real PDFs and PDFKit rendering. The subagent should SKIP this step and report DONE. The controller will:

1. Install on device (Xcode → Run with iPhone as destination).
2. Scan or import at least 2 documents that share a common word (e.g., scan two receipts and search "TOTAL").
3. In the library, search for the shared word — confirm both docs appear in the results.
4. Tap into one doc. Confirm the counter reads `"Match 1 of N · 2 docs"`.
5. Tap the down chevron repeatedly. When the current doc's matches are exhausted, the viewer should auto-flow to the next matching doc, opening at its first match.
6. Tap the up chevron repeatedly from the start of the second doc. The viewer should return to the previous doc, opening at its last match.
7. Confirm highlights snap precisely under the visible text on newly-scanned PDFs (Item 1 verification).

If any value-tuning or behavior tweak is needed, adjust in a follow-up commit.

- [ ] **Step 8: Commit**

```bash
git add DocumentScanner/DocumentScanner/Viewer/DocumentViewerView.swift
git commit -m "$(cat <<'EOF'
DocumentViewerView: cross-doc match navigation auto-flow

Adds currentDocIndex + pendingJumpToLastMatch state and rewires the
session-loading task to key on currentDocIndex, so changing it triggers
a reload of the next/previous matching doc. handleNext/handlePrevious
wrap within the current doc until the user crosses an edge, then
advance to the adjacent doc. The toolbar counter now reads
"<global> of <total> · <doc count> docs" when a SearchContext is
active, falling back to the previous per-doc form otherwise.

Spec: docs/superpowers/specs/2026-06-02-search-polish-design.md (Item 2c)
EOF
)"
```

---

## Self-review

- **Spec coverage:** Spec sections — Goals (2 items), Item 1, Item 2 (a/b/c, behaviour at extremes), Testing, Risks, Rollout. Mapping: Task 1 = Item 1; Task 2 = Item 2a (SearchContext); Task 3 = Item 2b (LibraryView wiring); Task 4 = Item 2c (viewer + counter). Behaviour at extremes is handled implicitly by the `hasNextDoc`/`hasPreviousDoc` guards (Task 4 Step 1). Risks 1–4 (no text layer, narrow Vision boxes, in-viewer search edit out of scope, doc-delete invalidation) are inherent to the design — no extra task needed. Testing section's PDFAssemblerHighlightTests → Task 1; SearchContext tests → Task 2; library searchContext-builder unit test → covered implicitly by the manual flow test in Task 4 (no dedicated unit; tradeoff because LibraryView depends on `DocumentSummary` + filesystem URLs). If the engineer wants, they could add a unit test that constructs URLs to temp-file PDFs and asserts `searchContext` drops zero-match docs — flagged as a follow-up.
- **Placeholder scan:** No TBDs, no "add error handling," no "similar to Task N." Every code block is complete. Step 4 of Task 3 says "if `FolderContentsView` passes `searchTerm:`, replicate" — this is a conditional instruction with concrete actions for each branch, not a placeholder.
- **Type consistency:** `SearchContext` shape — `term: String`, `docs: [DocEntry]`, `startDocIndex: Int`, with nested `DocEntry { summary: DocumentSummary; matchCount: Int }` — consistent across Tasks 2, 3, 4. `searchContext: SearchContext?` parameter consistent across Tasks 3 and 4. `currentDocIndex: Int` consistent throughout Task 4. `pendingJumpToLastMatch: Bool` consistent. `handleNext`/`handlePrevious` signatures consistent.
