# Spec: Confirm before discarding a page's marks on edit

**Date:** 2026-06-19
**Status:** Approved (design) — ready for implementation plan
**Roadmap origin:** `docs/FutureEnhancements.md` → *Editing → "Preserve annotations across page edits"*
**Target release:** next release after v1.11.

## Goal

Stop the **silent** loss of a page's highlights/strikethroughs when it's edited. Editing a page
in `PageEditorView` (crop / rotate / filter) rebuilds it via `DocumentMutations.replacePage`,
which drops that page's annotations. Today this happens with no warning. This feature replaces
the silent loss with an informed confirmation — it does **not** try to preserve the marks
(geometry-remapping was deliberately rejected: rare flow, hard for crop/perspective, semantically
dubious when the marked region is cropped/warped away).

## Background (from discussion)

- `PageEditorView` commits via two paths, both of which call `replacePage` and lose marks:
  - **"Apply"** (`applyEdit()`) — rebuilds the **current** page. No confirmation today.
  - **"Apply [filter] to all pages"** (`applyToAll()`) — rebuilds **every** page. Already has a
    confirmation, but it only warns about re-processing time, not mark loss.
- The strip context-menu **quick rotate** is a different, lossless path (`DocumentMutations.rotatePage`
  sets `/Rotate`, preserving annotations) — unchanged by this spec.
- User marks are identified by the existing `AnnotationFactory.isUserDeletable(_:)` (subtype-keyed:
  `Highlight`/`StrikeOut`, excluding the in-session search-highlight tag).

## Scope decisions

- **Two trigger points, both conditional on marks actually existing** (no prompt when there's
  nothing to lose):
  1. **Apply (single page):** if the *current* page has user marks, show a destructive
     confirmation before applying; otherwise apply with no added friction (unchanged).
  2. **Apply-to-all:** keep the existing confirmation dialog; when *any* page has user marks,
     append a sentence about mark loss to its message.
- **Detection:** reuse `AnnotationFactory.isUserDeletable`. Current-page check for #1; any-page
  check for #2.
- A no-op Apply (open page, change nothing, tap Apply) still rebuilds the page and so still loses
  marks — therefore the prompt correctly fires whenever Apply is tapped on a marked page,
  regardless of whether edits were made. No change-detection needed.

## Architecture / components

All changes are in `DocumentScanner/DocumentScanner/PageEditor/PageEditorView.swift`.

### State
- New `@State private var showingDiscardMarksConfirm = false`.

### Detection helpers
```
private var currentPageHasUserMarks: Bool {
    guard let page = session.pdf.page(at: pageIndex) else { return false }
    return page.annotations.contains(where: AnnotationFactory.isUserDeletable)
}

private var anyPageHasUserMarks: Bool {
    (0..<session.pdf.pageCount).contains { idx in
        session.pdf.page(at: idx)?.annotations.contains(where: AnnotationFactory.isUserDeletable) ?? false
    }
}
```

### Apply button (single page)
The Apply toolbar button no longer calls `applyEdit()` directly. It routes:
```
if currentPageHasUserMarks { showingDiscardMarksConfirm = true }
else { Task { await applyEdit() } }
```
A new confirmation:
- title: **"Discard this page's highlights?"**
- destructive **"Edit Anyway"** → `Task { await applyEdit() }`
- **"Cancel"** (role .cancel) → dismiss, stay in the editor
- message: *"Editing Page \(pageIndex + 1) removes the highlights and marks you added to it. The rest of your document is unaffected."*

`applyEdit()` itself is unchanged (it still does the replace + save + dismiss).

### Apply-to-all dialog
The existing `showingApplyAllConfirm` dialog's message gains a conditional second sentence when
`anyPageHasUserMarks`:
> "This will re-process all N pages and may take a moment. Highlights and marks on pages that have them will be removed."
When no page has marks, the message is unchanged.

## Data flow

```
Apply tapped
  → currentPageHasUserMarks ? show "Discard this page's highlights?" : applyEdit()
  → "Edit Anyway" → applyEdit() (replacePage + save + dismiss)
  → "Cancel" → stay

Apply-to-all tapped → existing confirm (message includes mark-loss line iff anyPageHasUserMarks)
  → "Apply" → applyToAll()
```

## Error handling

- No new failure modes. The detection helpers are read-only and return `false` on a missing page.
- Existing `applyEdit()` / `applyToAll()` error handling (the `errorMessage` path) is untouched.

## Testing

- `AnnotationFactory.isUserDeletable` is already covered by `AnnotationFactoryTests` — detection
  reuses it, so no new pure logic is introduced.
- The new surface is SwiftUI confirmation-dialog wiring on `PageEditorView` — verified by build +
  on-device (matches how the app's other UI features ship). On device: edit a page **with** marks
  → confirm appears → Cancel keeps it / Edit Anyway proceeds; edit a page **without** marks → no
  prompt (unchanged); Apply-to-all with a marked page → the dialog mentions mark loss.

## Deliverables

- `PageEditor/PageEditorView.swift`: `showingDiscardMarksConfirm` state, the two detection
  helpers, the Apply-button routing + new confirm, and the augmented apply-to-all message.
- Spec + plan under `docs/superpowers/`. On merge, update the FutureEnhancements
  "Preserve annotations across page edits" item to reflect the shipped behavior (warn, not
  preserve) — or remove it, since the decided scope is now delivered.

## Non-goals

- Preserving/remapping annotations across crop / rotate / filter (explicitly rejected).
- A "don't ask again" preference.
- Any change to the lossless strip quick-rotate path.
- Localizing the copy (English-only app today).
