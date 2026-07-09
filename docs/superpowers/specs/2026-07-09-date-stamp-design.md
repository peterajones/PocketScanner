# Date Stamp — Design

**Status:** Approved 2026-07-09. Signing follow-up (see `docs/FutureEnhancements.md`).

## Problem

Signing a document is rarely the whole job — you're usually also asked to **date**
it. Today the app can place a scanned signature, but there's no way to add a date.
Unlike a signature or initials (which can be *scanned* and are already handled by
the signing feature), the date is **generated** — it's today's date in a specific
format — so it can't be produced by the scan-based path. That's the gap this fills.

## Goal & scope

Add a **date stamp**: pick a date (defaulting to today) and a format, then place it
on the page like a signature — draggable, resizable, movable, removable.

In scope:
- A **date picker** defaulting to today (so backdating/postdating is possible, but
  the common case is one glance).
- **Five format presets** (fixed, explicit — the document dictates the format, not
  device locale).
- Reuse of the **existing signature-stamp machinery** end to end (placement sheet
  with drag + pinch-resize, `ImageStampAnnotation`, Move/Remove, persistence).

## Non-goals

- **Initials** — redundant: scanned initials already work via the multi-signature
  feature (save a named signature "Initials"). Not built here.
- **Arbitrary free text** — deliberately excluded; typing arbitrary text onto a page
  drifts from "scanner" toward "PDF editor." (Dropped in brainstorming.)
- **No font / colour / size controls** beyond pinch-resize — presets, not sliders.
- No auto-detect-signature-line, no multi-page apply (both parked as "maybe").
- No localization of month names yet (app is English-only; `en_US_POSIX`).

## Chosen approach

**Render the date to a small image and place it as an `ImageStampAnnotation`** — the
same path signatures use. Rejected alternative: a native PDFKit `.freeText`
annotation (real selectable text, but PDFKit freeText is fiddly, has limited font
control and its own editing model, so it wouldn't reuse the placement UI). The
image-stamp path is proven, gives guaranteed rendering, and reuses everything.

## Format engine

A pure value type `DateStampFormat` (enum, 5 cases) with one function
`string(for date: Date) -> String`, using explicit fixed format strings and a fixed
`en_US_POSIX` locale so output never shifts with device settings:

| Case | Format string | Example (2026-07-09) |
|---|---|---|
| `.iso` | `yyyy-MM-dd` | `2026-07-09` |
| `.numericUS` | `MM/dd/yyyy` | `07/09/2026` |
| `.numericIntl` | `dd/MM/yyyy` | `09/07/2026` |
| `.longUS` | `MMMM d, yyyy` | `July 9, 2026` |
| `.longIntl` | `d MMMM yyyy` | `9 July 2026` |

The long forms use `d` (no zero padding on single-digit days). `en_US_POSIX` gives
English month names and stable digit ordering. The enum is `CaseIterable` so the UI
can list all five.

## Rendering

`DateStampRenderer.image(for text: String) -> UIImage` draws the string via
`UIGraphicsImageRenderer`:
- **Transparent background, black text**, a clean system font.
- **High resolution** — rendered at a large point size so pinch-resizing up stays
  crisp (the one text-specific concern; a scanned signature tolerates scaling, text
  does not).
- Image aspect ratio matches the text bounds, so the placement sheet opens with a
  sensibly-proportioned box.

## UX flow

1. **Bottom-bar "Date" button** in the viewer, beside "Sign".
2. Tap → **"Add Date" sheet**:
   - A `DatePicker` (`.compact`) bound to `@State selectedDate = Date()` (today).
   - Below it, the **five formats as a list**, each a **live `Text` preview rendered
     with `selectedDate`** (updates as the date changes). The **last-used format is
     checkmarked** (persisted via `@AppStorage("dateStampFormat")`).
   - Note: the list rows are plain `Text` previews (cheap); the high-res *image*
     render happens once, on confirm.
3. **Tapping a format row is the confirm** → sheet dismisses, `@AppStorage` updates
   to that format → `DateStampRenderer` renders `(selectedDate, format)` to an image
   → the existing placement sheet (`SignaturePlacementView`) opens (drag + pinch).
4. Confirm placement → placed as an `ImageStampAnnotation` on the current page.

## Move / Remove

Placed date stamps are `ImageStampAnnotation`s and route through the viewer's
existing tap→edit alert (Move / Remove) — with one distinction:

- A **signature's** Move re-fetches its image from `SignatureStore` by id.
- A **date stamp** has no store entry, so its **Move re-places using the image
  embedded in the annotation** (which `ImageStampAnnotation` already holds).

Date-stamp annotations are **tagged distinctly** (a marker in the annotation, the way
signatures carry their signature id) so the viewer routes correctly: signature →
store-backed move; date → self-image move. **Remove is identical** for both. The edit
alert title reads "Date" vs "Signature" accordingly.

## Persistence & page-edit behaviour

A placed date stamp persists into the PDF like any stamp annotation (no new
persistence work). Editing a page (crop/rotate/filter) rebuilds the page and drops
that page's annotations — existing, already-warned behaviour; a date stamp is no
different. No change needed.

## Error handling

- **Rendering fails / empty string** → no stamp placed; the flow simply doesn't open
  the placement sheet (guard on a nil/empty image). No crash, no partial state.
- **No current page to place on** → the "Date" button is a no-op in that state
  (mirrors how signing already guards `currentPageForSigning`).
- Placement cancel → nothing placed (existing `SignaturePlacementView` behaviour).

## Testing

- **`DateStampFormat`** (pure, unit): all five cases against a fixed date
  (`2026-07-09`) assert exact strings; plus a single-digit day+month date
  (e.g. `2026-03-05`) to prove `d` isn't zero-padded on the long forms and `dd`/`MM`
  *is* on the numeric forms; and locale-independence (force a non-US locale, output
  unchanged).
- **`DateStampRenderer`** (smoke): returns a non-empty image of expected size with a
  transparent background (a corner pixel is clear).
- **Placement / persistence / Move / Remove**: rides on the already-tested signature
  machinery; add a focused test that a date-stamp annotation is tagged as a date (not
  a signature) so Move routes to self-image.
- On-device smoke: place each of the 5 formats, resize, Move, Remove; verify a
  non-today date via the picker; confirm the stamp survives save→reopen.

## Files (anticipated)

- **Create** `DocumentScanner/DocumentScanner/DateStamp/DateStampFormat.swift` — the
  pure enum + formatting.
- **Create** `DocumentScanner/DocumentScanner/DateStamp/DateStampRenderer.swift` —
  text → transparent UIImage.
- **Create** `DocumentScanner/DocumentScanner/DateStamp/AddDateSheet.swift` — the
  date picker + live-previewed format list.
- **Modify** `DocumentScanner/DocumentScanner/Viewer/DocumentViewerView.swift` — the
  "Date" bottom-bar button, present the sheet, render + hand to placement, and the
  date-stamp tag + Move routing in the edit alert.
- **Possibly modify** `Signature/ImageStampAnnotation.swift` — if a tag/marker field
  is cleanest there.
- **Create** tests under `DocumentScannerTests/` for `DateStampFormat` (+ renderer
  smoke).
- Update `docs/FutureEnhancements.md` (mark the date stamp built) in the same session.
