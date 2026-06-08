# Rotate in Strip Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Rotate Left / Rotate Right to the edit-mode thumbnail context menu, rotating a page losslessly via `PDFPage.rotation`.

**Architecture:** A pure `DocumentMutations.rotatePage(in:at:clockwise:)` helper sets the page's `/Rotate` attribute (no re-render, so the OCR text layer and annotations rotate with the page). `EditModeView` adds two context-menu items that call it then `session.save()`; the strip and viewer already re-render from `session.revision`.

**Tech Stack:** Swift, SwiftUI, PDFKit, XCTest, xcodebuild.

---

## Conventions for this plan

- **Run tests / build** (from repo root):

  ```bash
  cd DocumentScanner && xcodebuild build \
    -scheme DocumentScanner -destination 'platform=iOS Simulator,name=iPhone 17'
  cd DocumentScanner && xcodebuild test \
    -scheme DocumentScanner -destination 'platform=iOS Simulator,name=iPhone 17' \
    -only-testing:DocumentScannerTests/<ClassName>
  ```

  Full unit suite: `-only-testing:DocumentScannerTests`. If `iPhone 17` isn't
  installed, run `xcrun simctl list devices available` and substitute.

- **SourceKit/LSP false positives:** "No such module" / "Cannot find type"
  diagnostics appear constantly in this project and are spurious. `xcodebuild` is
  the source of truth.

- **Commit trailer:** every commit ends with
  `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.

- **Two UI tests are known-broken in the simulator** (`GoldenPathTests`,
  `EditModeTests`) — they fail on a clean `main` too. Ignore them; rely on the
  `DocumentScannerTests` unit bundle.

---

## File Structure

- **Modify** `Pipeline/DocumentMutations.swift` — add `rotatePage(in:at:clockwise:)`.
- **Modify** `Viewer/EditModeView.swift` — add Rotate Left/Right to the thumbnail
  context menu + a `rotatePage(at:clockwise:)` helper.
- **Modify** `DocumentScannerTests/DocumentMutationsTests.swift` — cover rotation.

---

## Task 1: `DocumentMutations.rotatePage`

**Files:**
- Modify: `DocumentScanner/DocumentScanner/Pipeline/DocumentMutations.swift`
- Test: `DocumentScanner/DocumentScannerTests/DocumentMutationsTests.swift`

- [ ] **Step 1: Add the failing tests**

In `DocumentScanner/DocumentScannerTests/DocumentMutationsTests.swift`, add these
tests after `test_deletePages_emptySetIsNoOp` (they reuse the existing
`threePagePDF()`, `singlePagePDF(marker:)`, and `pageMarkers(_:)` helpers):

```swift
    func test_rotatePage_clockwise_from0is90() throws {
        let pdf = try threePagePDF()
        DocumentMutations.rotatePage(in: pdf, at: 0, clockwise: true)
        XCTAssertEqual(pdf.page(at: 0)?.rotation, 90)
    }

    func test_rotatePage_counterclockwise_from0is270() throws {
        let pdf = try threePagePDF()
        DocumentMutations.rotatePage(in: pdf, at: 0, clockwise: false)
        XCTAssertEqual(pdf.page(at: 0)?.rotation, 270)
    }

    func test_rotatePage_clockwise_wrapsFrom270to0() throws {
        let pdf = try threePagePDF()
        let page = try XCTUnwrap(pdf.page(at: 0))
        page.rotation = 270
        DocumentMutations.rotatePage(in: pdf, at: 0, clockwise: true)
        XCTAssertEqual(page.rotation, 0)
    }

    func test_rotatePage_outOfRangeIsNoOp() throws {
        let pdf = try threePagePDF()
        DocumentMutations.rotatePage(in: pdf, at: 99, clockwise: true)
        XCTAssertEqual(pageMarkers(pdf), ["A", "B", "C"])
    }

    func test_rotatePage_persistsRotationAndKeepsTextLayer_afterDiskRoundTrip() throws {
        let pdf = try singlePagePDF(marker: "Rotated")
        DocumentMutations.rotatePage(in: pdf, at: 0, clockwise: true)

        // Round-trip through disk and reload via URL (PDFDocument(url:), NOT
        // PDFDocument(data:), which is known to break findString in this project).
        let tmpURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("rotate-roundtrip-\(UUID().uuidString).pdf")
        defer { try? FileManager.default.removeItem(at: tmpURL) }
        try XCTUnwrap(pdf.dataRepresentation()).write(to: tmpURL)

        let reloaded = try XCTUnwrap(PDFDocument(url: tmpURL))
        XCTAssertEqual(reloaded.page(at: 0)?.rotation, 90,
                       "/Rotate must persist across a save + reload")
        XCTAssertFalse(reloaded.findString("Rotated", withOptions: .caseInsensitive).isEmpty,
                       "the OCR text layer must survive rotation + round-trip")
    }
```

- [ ] **Step 2: Run to verify it fails**

Run:
```bash
cd DocumentScanner && xcodebuild test \
  -scheme DocumentScanner -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:DocumentScannerTests/DocumentMutationsTests
```
Expected: FAIL to compile — `rotatePage` is not a member of `DocumentMutations`.

- [ ] **Step 3: Add the helper**

In `DocumentScanner/DocumentScanner/Pipeline/DocumentMutations.swift`, add this
method inside the `DocumentMutations` enum (e.g. after `replacePage`):

```swift
    /// Rotate the page at `index` 90° clockwise (or counter-clockwise) by setting
    /// its `/Rotate` attribute. Lossless: the page image, the invisible OCR text
    /// layer, and any annotations all rotate together. Normalized to
    /// {0, 90, 180, 270}. No-op if the index is out of range.
    static func rotatePage(in pdf: PDFDocument, at index: Int, clockwise: Bool) {
        guard index >= 0, index < pdf.pageCount, let page = pdf.page(at: index) else { return }
        let delta = clockwise ? 90 : -90
        page.rotation = ((page.rotation + delta) % 360 + 360) % 360
    }
```

- [ ] **Step 4: Run to verify it passes**

Run:
```bash
cd DocumentScanner && xcodebuild test \
  -scheme DocumentScanner -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:DocumentScannerTests/DocumentMutationsTests
```
Expected: PASS (existing tests + the 5 new ones).

- [ ] **Step 5: Commit**

```bash
git add DocumentScanner/DocumentScanner/Pipeline/DocumentMutations.swift \
        DocumentScanner/DocumentScannerTests/DocumentMutationsTests.swift
git commit -m "feat: add DocumentMutations.rotatePage (lossless /Rotate)"
```

---

## Task 2: Add Rotate Left/Right to the edit-mode strip

**Files:**
- Modify: `DocumentScanner/DocumentScanner/Viewer/EditModeView.swift`

- [ ] **Step 1: Add the rotate items to the thumbnail context menu**

In `EditModeView.thumbnailImage(for:index:)`, find the non-multiselect
`.contextMenu`:

```swift
                .contextMenu {
                    Button {
                        selectedIndices = [index]
                        isMultiSelectMode = true
                    } label: {
                        Label("Select Multiple", systemImage: "checkmark.circle")
                    }
                    Button(role: .destructive) {
                        deletePage(at: index)
                    } label: {
                        Label("Delete page", systemImage: "trash")
                    }
                }
```

Replace it with (adds Rotate Left / Rotate Right between Select Multiple and
Delete):

```swift
                .contextMenu {
                    Button {
                        selectedIndices = [index]
                        isMultiSelectMode = true
                    } label: {
                        Label("Select Multiple", systemImage: "checkmark.circle")
                    }
                    Button {
                        rotatePage(at: index, clockwise: false)
                    } label: {
                        Label("Rotate Left", systemImage: "rotate.left")
                    }
                    Button {
                        rotatePage(at: index, clockwise: true)
                    } label: {
                        Label("Rotate Right", systemImage: "rotate.right")
                    }
                    Button(role: .destructive) {
                        deletePage(at: index)
                    } label: {
                        Label("Delete page", systemImage: "trash")
                    }
                }
```

- [ ] **Step 2: Add the `rotatePage` helper**

Add this method next to `deletePage(at:)`:

```swift
    private func rotatePage(at index: Int, clockwise: Bool) {
        DocumentMutations.rotatePage(in: session.pdf, at: index, clockwise: clockwise)
        _ = try? session.save()
    }
```

- [ ] **Step 3: Build to verify**

Run:
```bash
cd DocumentScanner && xcodebuild build \
  -scheme DocumentScanner -destination 'platform=iOS Simulator,name=iPhone 17'
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Run the full unit suite (no regressions)**

Run:
```bash
cd DocumentScanner && xcodebuild test \
  -scheme DocumentScanner -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:DocumentScannerTests
```
Expected: PASS (including Task 1's rotation tests).

- [ ] **Step 5: Commit**

```bash
git add DocumentScanner/DocumentScanner/Viewer/EditModeView.swift
git commit -m "feat: rotate left/right from the edit-mode thumbnail menu"
```

## Context for Task 2
`EditModeView` shows the edit-mode thumbnail strip. `session` is a `DocumentSession`
with `pdf: PDFDocument` and a throwing `save()` that bumps `session.revision`
(which the strip's `body` reads, so it re-renders after a mutation). The existing
`deletePage(at:)`/reorder paths already use `_ = try? session.save()`. The thumbnail
context menu only appears in non-multiselect mode (the branch shown above).
`DocumentMutations.rotatePage` is from Task 1. `PageThumbnail` and the viewer's
`PDFView` both honor `page.rotation`, so no rendering code changes.

---

## Task 3: Version bump + manual smoke test

**Files:**
- Modify: `DocumentScanner/DocumentScanner.xcodeproj/project.pbxproj` (via Xcode UI)

- [ ] **Step 1: Bump version (manual, in Xcode)**

Xcode → target **DocumentScanner** → General: set **Version** to `1.7` and **Build**
to `12`. Updates `MARKETING_VERSION` (1.6 → 1.7) and `CURRENT_PROJECT_VERSION`
(11 → 12) for the main-app Debug + Release configs; leave the test targets.

Verify:
```bash
grep -n "MARKETING_VERSION\|CURRENT_PROJECT_VERSION" \
  DocumentScanner/DocumentScanner.xcodeproj/project.pbxproj
```
Expected: main-app configs show `MARKETING_VERSION = 1.7;` / `CURRENT_PROJECT_VERSION = 12;`.

- [ ] **Step 2: Manual smoke test (device/simulator — user-driven)**

  1. Open a document, tap **Edit**, long-press a page thumbnail → the menu shows
     **Select Multiple, Rotate Left, Rotate Right, Delete page**.
  2. Tap **Rotate Right** → the thumbnail (and the page in the viewer) rotate 90° CW
     immediately; **Rotate Left** goes CCW.
  3. Rotate a page that has a highlight/strikethrough → the annotation stays aligned
     (rotates with the page).
  4. Close & reopen the document → the rotation persisted; **search** still finds
     text on the rotated page.

- [ ] **Step 3: Commit the version bump**

```bash
git add DocumentScanner/DocumentScanner.xcodeproj/project.pbxproj
git commit -m "chore: bump to v1.7 (12)"
```

---

## Done

After Task 2, pages can be rotated 90° left/right straight from the edit-mode
thumbnail menu, losslessly (text layer + annotations preserved), and the unit suite
passes. Next steps (outside this plan): push, archive, upload, submit.
