# Filter at Scan Time — Design

**Date:** 2026-06-08
**Release:** v1.6 (build 11)
**Status:** Approved

## Problem

Filters can only be applied *after* saving, by entering the per-page editor for each
page. A user who knows they want B&W (or Photo, etc.) for a whole scan has to save
first, then re-edit every page. There's no way to choose a look at save time — and
the Save sheet doesn't even show the scan, so there's nothing to judge a filter
against.

## Goal

Let the user pick a filter while saving a fresh scan, seeing it applied live, with
the choice baked into every page of the resulting PDF. Default is Color (today's
behavior) so the change is invisible to anyone who ignores it.

## UX

`NameDocumentSheet` (the "Save Scan" modal) gains, above the existing name field:

- A **live preview of page 1** with the currently-selected filter applied.
- A **segmented filter picker** — Color / Greyscale / B&W / Photo — the same
  `ImageFilter` cases and `.segmented` `Picker` style used in the per-page editor.

Behavior:

- The selected filter applies to **every page** of the scan; page 1 is the preview
  surface.
- Default selection is **Color** (`ImageFilter.none`) on every new scan — no hidden
  carry-over between scans, and no behavior change for users who don't touch it.
- Switching presets re-renders the preview live. The preview uses a **downscaled
  page-1 image** so switches feel instant regardless of scan resolution.

## Non-Goals (YAGNI)

- No per-page filter choice at scan time (that's what the per-page editor is for);
  one filter for the whole scan.
- No multi-page pager in the preview (page 1 only).
- No remembering the last-used filter across scans.
- No new filter presets or sliders (reuse the existing four).

## Key architectural change: split OCR from assembly

Today `ScanPipeline.process(images:)` does OCR **and** PDF assembly in one call,
kicked off before the Save sheet appears; the sheet just awaits the finished
`ScanResult`. To bake a *chosen* filter into the PDF, assembly must happen *after*
the user picks — but we want to keep today's overlap where OCR runs in the
background while the user types a name.

So split the pipeline:

- **`recognize(images:) -> [ScannedPage]`** — runs OCR on the **original** images,
  returning pages carrying the original image + observations. (Same per-page
  serial OCR + error-absorbing behavior as today.)
- **`assemble(pages:filter:createdAt:) -> ScanResult`** — applies `filter` to each
  page's image via `ImageFilterEngine`, then builds the searchable PDF from the
  filtered images + the original observations, and joins the OCR text.

`process(images:)` can remain as a thin convenience (`recognize` then
`assemble(... filter: .none)`) for any caller that doesn't need a filter, or be
removed if no caller needs it after the sheet is updated — implementer's choice
during the plan.

**OCR always runs on the original image.** A heavy B&W/high-contrast filter never
degrades text recognition. (This is deliberately better than the per-page editor's
re-render path, which OCRs the filtered image.)

## Components

- **`NameDocumentSheet`** — gains `@State private var filter: ImageFilter = .none`,
  the preview, and the picker. Its inputs change: instead of a finished
  `Task<ScanResult, Error>`, it takes the raw `images: [UIImage]` and a background
  recognize task (`Task<[ScannedPage], Error>`). On Save it calls
  `assemble(pages:filter:)` with the chosen filter, then `storage.write`.
- **`ScanPipeline`** — split into `recognize` / `assemble(pages:filter:)` as above.
- **Call sites** — `LibraryView` and `FolderContentsView` both present
  `NameDocumentSheet`. Their `NameSheetContext` currently wraps a
  `Task<ScanResult, Error>`; update both to start a `recognize` task and pass the
  raw images through. (FolderContentsView passes its folder-scoped `storage`, as
  today.)
- **Preview helper** — a small downscale of page 1 (e.g. fit within ~1000 px) fed
  through `ImageFilterEngine.apply(filter:)` for the live preview; the full-res
  filter is applied at assembly, not in the preview.

## Data flow

```
capture → raw images → NameDocumentSheet (page-1 preview + picker + name)
   (background) recognize(images) → [ScannedPage] (original images + observations)
pick filter → preview re-renders page 1 live (downscaled)
Save → assemble(pages with filter applied, filter) → ScanResult → storage.write
```

## Error handling

- Save failure surfaces through the existing `AlertCenter` retry/cancel alert — no
  new error surface.
- A filter that fails to render falls back to the original image (the existing
  `ImageFilterEngine.apply` nil-guard), so a render hiccup never blocks a save.
- Cancel still cancels the background recognize task, as today.

## Testing

- **`ScanPipeline.recognize`** — returns one `ScannedPage` per input image with
  observations, carrying the original (unfiltered) images.
- **`ScanPipeline.assemble(pages:filter:)`** — the produced PDF has the right page
  count and a working OCR text layer (`findString` for a known observation still
  matches), confirming the filter is applied to the visible image while text
  recognition is preserved.
- **A filtered-vs-Color assemble** differs in rendered page bytes but both keep the
  text layer (sanity that the filter actually changed the image).
- `ImageFilterEngine` is already covered.
- The preview + picker UI is verified by the manual smoke test.

## Version

- `MARKETING_VERSION` 1.5 → **1.6**
- `CURRENT_PROJECT_VERSION` 10 → **11**

Main-app Debug + Release configs only; test targets unchanged. Set in Xcode.
