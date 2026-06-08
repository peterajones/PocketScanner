# Rotate in Strip — Design

**Date:** 2026-06-08
**Release:** v1.7 (build 12)
**Status:** Approved

## Problem

A sideways page can only be straightened by opening the full per-page editor
(`PageEditorView`), choosing a rotation, and saving — and that editor's rotation
*re-renders* the page and re-runs OCR, which is heavy and loses the original text
layer fidelity. There's no quick way to rotate a page from the edit-mode thumbnail
strip.

## Goal

In edit mode, let the user rotate a page 90° left or right directly from the
thumbnail's context menu, losslessly, with the change reflected immediately and
saved.

## Interaction

In edit mode, long-pressing a page thumbnail already shows a context menu with
"Select Multiple" and "Delete page". Add two items:

- **Rotate Left** (90° counter-clockwise)
- **Rotate Right** (90° clockwise)

Tapping either rotates that page and the thumbnail (and the main viewer) re-render
rotated immediately.

## Key technique: lossless `page.rotation`

Rotation sets the PDF page's `/Rotate` attribute via `PDFPage.rotation` — it does
**not** re-render the page image. This means:

- **Lossless** — no image re-encoding or quality loss.
- **Preserves the OCR text layer and annotations** — they are page content and
  rotate *with* the page, staying aligned and searchable. (Strictly better than
  `PageEditorView`'s rotate, which rebuilds the page image and re-OCRs.)
- **Persists** — `/Rotate` is written by `dataRepresentation()` and honored by
  PDFKit (`PDFView`, `PDFPage.thumbnail`) and other PDF viewers.

`PDFPage.thumbnail(of:for:)` and `PDFView` both render a page honoring its
`rotation`, so no thumbnail/render code needs to change — only the stored rotation.

## Non-Goals (YAGNI)

- No free-angle rotation (90° increments only).
- No change to the per-page editor's existing rotation (it stays as is for the
  crop/filter workflow).
- No rotate affordance outside edit mode.
- No multi-select "rotate all selected" (single page at a time, via its context
  menu).

## Components

- **`DocumentMutations.rotatePage(in:at:clockwise:)`** (new, pure/testable) — sets
  `page.rotation` to `normalized(current ± 90)`, where `clockwise` adds 90 and not-
  clockwise subtracts 90, normalized into `{0, 90, 180, 270}`:
  `((current + delta) % 360 + 360) % 360`. Mirrors the existing
  `reorder` / `deletePage` / `replacePage` mutation helpers. No-op safe if the
  index is out of range (guard like the siblings).
- **`EditModeView`** — add **Rotate Left** and **Rotate Right** buttons to the
  existing non-multiselect thumbnail `.contextMenu`, each calling
  `DocumentMutations.rotatePage(in: session.pdf, at: index, clockwise:)` then
  `_ = try? session.save()`. `save()` bumps `session.revision` (already observed by
  the strip), so the thumbnail re-renders rotated; the viewer's `PDFView` reflects
  it on its next update.

No changes to `PageThumbnail`, `PageEditorView`, or the rendering paths.

## Data flow

```
long-press thumbnail → Rotate Left / Rotate Right
  → DocumentMutations.rotatePage(in: session.pdf, at: index, clockwise:)
  → session.save()  (writes /Rotate into the PDF, bumps revision)
  → strip thumbnail + viewer re-render rotated
```

## Error handling

None new. Save uses the same `_ = try? session.save()` pattern as the strip's
existing delete/reorder actions.

## Testing

`DocumentMutationsTests` (new cases):

- `rotatePage(clockwise: true)` from 0 → 90; from 270 → 0 (wraps).
- `rotatePage(clockwise: false)` from 0 → 270; from 90 → 0.
- Result is always a multiple of 90 in `{0,90,180,270}`.
- Round-trip: rotate a page, `dataRepresentation()` → reload → the page's
  `rotation` persists, and `findString` still finds known text (the text layer
  survives rotation).

The context-menu wiring is verified by the manual smoke test.

## Version

- `MARKETING_VERSION` 1.6 → **1.7**
- `CURRENT_PROJECT_VERSION` 11 → **12**

Main-app Debug + Release configs only; test targets unchanged. Set in Xcode.
