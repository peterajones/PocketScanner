# Confirm Before Discarding Page Marks — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the silent loss of a page's highlights/marks when it's edited with an informed confirmation — warn before `PageEditorView` rebuilds an annotated page (single Apply) or annotated pages (Apply-to-all). Do not preserve/remap the marks (decided against).

**Architecture:** All changes are confined to `PageEditorView.swift`. Detection reuses the existing `AnnotationFactory.isUserDeletable`. The single-page Apply gains a destructive `.alert` (shown only when the current page has marks); the existing Apply-to-all dialog gains a conditional mark-loss sentence.

**Tech Stack:** Swift, SwiftUI (`.alert`, toolbar `Button`), PDFKit (`PDFPage.annotations`), XCTest (existing coverage).

**Spec:** `docs/superpowers/specs/2026-06-19-confirm-discard-page-marks-design.md`

---

## File Structure

- Modify: `DocumentScanner/DocumentScanner/PageEditor/PageEditorView.swift` — state, two detection helpers, Apply-button routing, the new confirm, the augmented apply-to-all message.
- Modify: `docs/FutureEnhancements.md` — update the "Preserve annotations across page edits" item to the resolved decision (warn, not preserve).

No new pure logic ⇒ no new unit tests; the user-mark predicate (`AnnotationFactory.isUserDeletable`) is already covered by `AnnotationFactoryTests`. Verified by build + full suite (no regressions) + on-device.

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

## Task 1: PageEditorView — confirm before discarding marks

**Files:**
- Modify: `DocumentScanner/DocumentScanner/PageEditor/PageEditorView.swift`

- [ ] **Step 1: Add the confirm state**

After the existing `@State private var showingApplyAllConfirm = false` line, add:

```swift
    @State private var showingDiscardMarksConfirm = false
```

- [ ] **Step 2: Add the two detection helpers**

Add these computed properties (place them just before the `private func applyEdit()` method):

```swift
    /// True when the page being edited has user highlights/strikethroughs that
    /// the rebuild-on-apply would discard. Uses the same predicate the viewer
    /// uses to identify user marks (excludes in-session search highlights).
    private var currentPageHasUserMarks: Bool {
        guard let page = session.pdf.page(at: pageIndex) else { return false }
        return page.annotations.contains(where: AnnotationFactory.isUserDeletable)
    }

    /// True when ANY page has user marks — used to warn before Apply-to-all,
    /// which rebuilds every page.
    private var anyPageHasUserMarks: Bool {
        (0..<session.pdf.pageCount).contains { index in
            session.pdf.page(at: index)?.annotations.contains(where: AnnotationFactory.isUserDeletable) ?? false
        }
    }

    /// Apply-to-all confirmation message — adds a mark-loss sentence only when
    /// some page actually has marks to lose.
    private var applyAllMessage: String {
        var text = "This will re-process all \(session.pdf.pageCount) pages and may take a moment."
        if anyPageHasUserMarks {
            text += " Highlights and marks on pages that have them will be removed."
        }
        return text
    }
```

- [ ] **Step 3: Route the Apply button through the marks check**

In the `.confirmationAction` toolbar item, replace the existing Apply button:

```swift
                        Button("Apply") { Task { await applyEdit() } }
                            .disabled(quad == nil)
```

with:

```swift
                        Button("Apply") {
                            if currentPageHasUserMarks {
                                showingDiscardMarksConfirm = true
                            } else {
                                Task { await applyEdit() }
                            }
                        }
                        .disabled(quad == nil)
```

- [ ] **Step 4: Add the discard-marks confirmation alert**

Immediately after the existing `.alert("Apply \(filter.displayName) to all pages?", …) { … } message: { … }` block, add a second alert:

```swift
            .alert("Discard this page's highlights?",
                   isPresented: $showingDiscardMarksConfirm) {
                Button("Edit Anyway", role: .destructive) {
                    Task { await applyEdit() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Editing Page \(pageIndex + 1) removes the highlights and marks you added to it. The rest of your document is unaffected.")
            }
```

(`.alert` — not `.confirmationDialog` — so Cancel is always visible and it can't be tap-dismissed, matching the app's other destructive confirms.)

- [ ] **Step 5: Use the conditional message for the Apply-to-all dialog**

In the existing apply-to-all alert, replace its message body:

```swift
            } message: {
                Text("This will re-process all \(session.pdf.pageCount) pages and may take a moment.")
            }
```

with:

```swift
            } message: {
                Text(applyAllMessage)
            }
```

- [ ] **Step 6: Build**

```bash
cd DocumentScanner && xcodebuild build -scheme DocumentScanner \
  -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 7: Commit**

```bash
git add DocumentScanner/DocumentScanner/PageEditor/PageEditorView.swift
git commit -m "feat: confirm before an edit discards a page's highlights/marks"
```

---

## Task 2: Full suite + roadmap update

**Files:**
- Modify: `docs/FutureEnhancements.md`

- [ ] **Step 1: Run the full unit suite (no regressions)**

```bash
cd DocumentScanner && xcodebuild test -scheme DocumentScanner \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:DocumentScannerTests 2>&1 | grep -E "\*\* TEST|failed" | tail -5
```
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 2: Update the roadmap item to the resolved decision**

In `docs/FutureEnhancements.md`, replace the existing **"Preserve annotations across page edits"** bullet (under `### Editing`) — currently:

```markdown
- **Preserve annotations across page edits** — annotations shipped in v1.4, but editing a page in the per-page editor (crop / rotate / filter) rebuilds the page from scratch via `DocumentMutations.replacePage`, dropping any highlights/strikethroughs on that page. A correct fix is non-trivial because a cropped / perspective-corrected page has different geometry, so marks would need re-mapping rather than re-attaching. Uncommon sequence; deferred from v1.4.
```

with:

```markdown
- ~~**Preserve annotations across page edits**~~ — **Decided 2026-06-19: warn, don't preserve.** Editing a page (crop / rotate / filter) still rebuilds it via `DocumentMutations.replacePage`, dropping that page's highlights/strikethroughs — geometry-remapping was rejected (rare flow; hard/non-affine for crop & perspective; semantically dubious when the marked region is cropped away). Instead the editor now **confirms before discarding marks** (single Apply, and the Apply-to-all dialog notes it) so the loss is never silent. Shipped in v1.12. (The lossless strip quick-rotate already preserves marks.)
```

- [ ] **Step 3: Commit**

```bash
git add docs/FutureEnhancements.md
git commit -m "docs: resolve 'preserve annotations' item (warn-on-discard shipped)"
```

---

## Done

After Task 2: editing a page that has user highlights/strikethroughs prompts a destructive
confirmation before the rebuild discards them (single **Apply**), and **Apply-to-all** notes the
loss in its existing dialog — both only when marks actually exist. No marks are preserved/remapped
(by design). Pages without marks are unaffected; the lossless strip quick-rotate is unchanged.

**On-device smoke test (manual):**
1. Open a doc, highlight some text on page 1. Edit page 1 (Edit ▸ tap the page) → change crop/filter → **Apply** → the **"Discard this page's highlights?"** alert appears → **Cancel** keeps you in the editor (marks intact); **Edit Anyway** applies and the marks are gone (expected).
2. Edit a page that has **no** marks → **Apply** → no prompt (applies as before).
3. With a marked page present, multi-page doc, pick a filter → **Apply [filter] to all pages** → the confirm dialog mentions highlights/marks will be removed.
4. Quick-rotate a marked page from the strip context menu → marks are **kept** (unchanged lossless path).

Ships in v1.12 (next release after v1.11).
