# Annotations (Highlight + Strikethrough) — Design

**Date:** 2026-06-04
**Release:** v1.4 (build 9)
**Status:** Approved

## Problem

Pocket Scanner can search a scan but can't mark it up. Users want to emphasise
parts of a document (highlight) or cross out parts that no longer need attention
(strikethrough) — e.g. flagging the important line on a receipt, or striking a
completed item on a checklist.

## Goal

Let the user, from the document viewer, **select text and apply a mark**:

- **Highlight** in one of four colours: yellow, green, pink, blue (translucent so
  the scanned page shows through).
- **Strikethrough** as a solid red line.

And **tap an existing mark to delete it**. Marks persist into the PDF and travel
with the file via Share / iCloud.

## Interaction Model: Select-First

No mode to enter. The user long-presses to select text — the OS snaps the
selection to the OCR words/lines (the same invisible text layer that powers
search). The native selection edit menu is **customized** to offer the marks
(Approach A, below). Tapping an existing mark offers **Delete**.

## Non-Goals (YAGNI)

- No notes/comments, shapes, or freehand drawing.
- No re-colouring or editing an existing mark (delete + redo instead).
- No undo/redo stack.
- No markup in edit mode — viewer only.
- No drag-a-rectangle fallback when OCR selection is imprecise (accepted
  limitation; see Risks).

## Approach A: Customize the native edit menu

`MarkupPDFView` subclasses `PDFView` and customizes the text-selection edit menu
to add:

- **Highlight ▸** submenu with the four colours.
- **Strikethrough**.

This anchors to the selection automatically (no manual coordinate math) and feels
native. (Rejected: a custom floating SwiftUI toolbar — more moving parts for the
same result; a bottom palette bar — that's the "markup mode" we didn't choose.)

## Components

1. **`AnnotationColor`** (enum, pure/testable) — the four highlight colours. Each
   case maps to a `UIColor` at ~40% alpha and a stable `String` raw value (for any
   future persistence/serialisation needs). No SwiftUI/PDFKit dependency beyond
   `UIColor`.

2. **`AnnotationFactory`** (pure helper, testable) — given a `PDFSelection` and a
   tool (`.highlight(AnnotationColor)` or `.strikethrough`), returns the per-line
   `PDFAnnotation`s to add. It mirrors the existing search-highlight pattern:
   `selection.selectionsByLine()` → `lineSelection.bounds(for: page)` → one
   `PDFAnnotation` per line of subtype `.highlight` or `.strikeOut`, coloured
   appropriately, tagged `userName = DocumentSession.userAnnotationName`. Returns
   `[(page: PDFPage, annotation: PDFAnnotation)]` so the caller adds each to its
   page. Skips empty bounds (same guard the search code uses).

3. **`MarkupPDFView` + Coordinator** (inside `PDFKitView`, the existing
   `UIViewRepresentable`) — subclasses `PDFView`; customizes the selection edit
   menu (Approach A); adds a tap gesture that hit-tests `page.annotation(at:)` and,
   if the hit annotation is user-deletable (see Discrimination), presents a small
   **Delete** menu at that point. Applying a tool or deleting calls back into the
   SwiftUI layer to mutate the document and save.

4. **Wiring in `DocumentViewerView` / `PDFKitView`** — on tool pick: run
   `AnnotationFactory`, add the produced annotations to their pages, call
   `session.save()`. On delete: `page.removeAnnotation(_:)`, call `session.save()`.

## Persistence & Annotation Discrimination

This is the crux. Today `DocumentSession.save()` strips **every** `.highlight`
annotation because search highlights must stay ephemeral and the author didn't
trust `userName` across a disk round-trip. We change the discrimination so user
marks persist while search highlights stay ephemeral, **without** depending on a
user mark's `userName` surviving a round-trip.

Names (constants on `DocumentSession`):

- `searchHighlightAnnotationName = "DocumentScanner.searchHighlight"` (exists).
- `userAnnotationName = "DocumentScanner.userAnnotation"` (new).

Two rules:

- **Strip on save** — remove annotations where
  `userName == searchHighlightAnnotationName`. Search highlights are *only* ever
  added in-session by `PDFKitView` (never loaded from disk), so their `userName`
  is always freshly set and reliable at strip time — this is the same in-session
  reliability `PDFKitView.removeOurAnnotations` already depends on. User marks are
  not search-tagged, so they survive; `.strikeOut` already survives untouched.

- **Delete hit-test** — an annotation is user-deletable iff its `type` is
  `"Highlight"` or `"StrikeOut"` **and** its `userName != searchHighlightAnnotationName`.
  This deliberately keys on subtype, not on the user tag, so marks **loaded from
  disk** (whose `userName` may not have round-tripped) are still recognised as
  deletable. In-session search highlights are excluded by the `userName` check.

User marks are written into the PDF by the existing `dataRepresentation()` save
path, so they travel with the file. **Save is automatic** on every create and
delete, consistent with edit-mode mutations.

## Data Flow

```
select text → edit menu → pick colour / strikethrough
   → AnnotationFactory builds per-line annotations (tagged userAnnotation)
   → add each to its page → session.save()

tap a mark → (hit-test: Highlight/StrikeOut and not search-tagged) → Delete
   → page.removeAnnotation → session.save()

load doc → user marks return from disk as Highlight/StrikeOut annotations
   → PDFKitView strips only search-tagged highlights, so user marks stay visible
```

## Error Handling

- Save failures surface the same way edit-mode mutations do today — no new error
  surface is introduced.
- OCR-imprecise selection on a poorly recognised scan is an accepted limitation
  (see Non-Goals / Risks). No rectangle-drag fallback in this release.

## Testing

- **`AnnotationColor`** — raw-value round-trip and the expected colour set.
- **`AnnotationFactory`** — a `PDFSelection` produces annotations of the correct
  subtype (`.highlight` vs `.strikeOut`), the correct colour for highlights, one
  annotation per line, the `userAnnotationName` tag, and empty-bounds lines
  skipped.
- **Persistence regression (key)** — build a PDF; add (a) a user highlight tagged
  `userAnnotationName`, (b) a user strikethrough, and (c) a search highlight tagged
  `searchHighlightAnnotationName`; `save()`; reload from disk; assert the user
  highlight and strikethrough survive and the search highlight is gone. This
  **updates the existing `test_save_stripsHighlightAnnotations`**, whose semantics
  change deliberately (an untagged/user highlight now survives; only search-tagged
  highlights are stripped).
- **Delete discrimination** — a `Highlight`/`StrikeOut` annotation with no
  `userName` (as if loaded from disk) is classified user-deletable; a `Highlight`
  tagged `searchHighlightAnnotationName` is not.

UI-level gestures (menu customization, tap-to-delete presentation) are verified by
manual smoke test on device, consistent with prior releases.

## Version

- `MARKETING_VERSION` 1.3 → **1.4**
- `CURRENT_PROJECT_VERSION` 8 → **9**

Main-app Debug + Release configs only; test targets stay put. Set in Xcode, as in
prior releases.

## Risks

- **OCR selection precision** — selection is only as good as the recognised text;
  on a poor scan the drag-select may grab too much or too little. Accepted for v1;
  a rectangle-drag fallback is a future enhancement.
- **`userName` reliability** — mitigated by design: correctness never depends on a
  *user* mark's `userName` surviving a round-trip (strip keys on the search tag,
  which is always in-session; delete keys on subtype). The persistence regression
  test guards the strip behaviour.
