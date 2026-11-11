# Page eraser: design

2026-11-11. Planned for Pocket Scanner 4.1. Agreed with Peter in conversation; mockup choice "A"
(a Crop / Erase switch inside the page editor).

## Why

Scanned pages often carry small things Peter wants gone: staple holes (usually top left), specks and
shadows along the page edges, and handwritten margin notes that are no longer needed. Crop handles
whole edges well, but it can't remove something small without losing part of the page. Peter wants
"something not fancy" for small cleanups.

## What it does

In the page editor, a new **Erase** mode lets you drag rectangles over parts of the page. On Apply,
those areas are **painted out of the page image for good** and the page is OCR'd again, so any text
in them no longer appears in search.

## Goals

- Remove small marks (staple holes, edge specks, margin notes) from one page with a few drags.
- The result is permanent: the pixels are gone from the saved PDF, and erased words are no longer
  found by search.
- An erased area blends in with the paper and doesn't show as a bright white patch on an off-white
  page.

## Non-goals

- A brush, a lasso, or any freehand shape. Rectangles only. Peter's targets sit in margins and
  corners, clear of the printed text. A brush can be considered later if rectangles prove too square.
- Smart "fill from the surroundings" repair (inpainting). A flat paper-coloured fill is enough.
- Undoing an erase after Apply. Before Apply, Undo removes the last box; after Apply the change is
  saved like any other page edit.
- Erasing several pages at once.
- Redaction as a security feature. Erasing does remove the pixels and the OCR text, but the app will
  not market it as redaction.

## Anti-goals

These would make it a failure even if it technically works:

- An erased area that is still found by search, or still visible in the saved PDF's image.
- A visible bright patch where the paper is cream, grey or shadowed (Color filter).
- Boxes that land somewhere other than where they were drawn.
- Losing the existing crop, rotate and filter behaviour, or making crop harder to use.

## How it works (decided with Peter)

- **Where:** the page editor (`PageEditor/PageEditorView.swift`) gets a segmented **Crop | Erase**
  switch at the top. Crop is the default and behaves exactly as today. In Erase mode the crop
  handles are hidden and dragging on the page draws a box.
- **Drawing:** each drag draws one rectangle, shown in red with a light red fill while you work.
  As many boxes as you like. **Undo** removes the most recent box. A small label shows how many
  areas are marked.
- **Apply** (the existing button) saves the crop, rotation, filter and erasing together. The page
  is rebuilt the way crop/filter already rebuild it: same page size, new image, OCR run again.
- **Permanent:** erased pixels are replaced in the image itself, not covered by an annotation.
- **Markup:** as with every page edit today, the page's highlights and strikethroughs are removed,
  and the existing "Discard this page's markup?" warning still appears.

## Confirmed by Peter (2026-11-11)

- **Erase mode shows the page as it will be saved**: cropped, perspective-corrected and rotated,
  with the filter applied. Boxes are drawn on that view, so they land where you expect. Box
  coordinates live in the corrected-and-rotated image's pixel space.
- **Changing the crop or rotation after drawing boxes clears them**, because they would no longer
  line up. If boxes exist, switching back to Crop shows a one-line note ("Changing the crop clears
  the erased areas") rather than a dialog. Changing the **filter** keeps the boxes.
- **Fill colour:** each box is filled with the paper colour sampled from a thin band just outside
  the box (median of the pixels in a band a few pixels wide, clipped to the image). The sample is
  taken from the corrected, rotated image **before** the filter, and the filter is applied after
  the fill, so the filled area is processed exactly like the paper around it. On Greyscale and
  B&W the result is effectively white or grey anyway.
- **"Apply <filter> to all pages"** erases only the current page; other pages get the filter only,
  as today.

## Calls I made (minor)

- **Pipeline order on Apply:** perspective-correct → rotate → erase (sample + fill) → filter → OCR
  → assemble at the existing page size. OCR runs on the final image, so erased text drops out.
- **Tiny boxes are ignored:** a drag shorter than a few points (a tap or a slip) doesn't add a box.
- **Box edges:** boxes are clipped to the image; a box drawn partly off the page erases the part on
  the page.

## Constraints

- iOS 17.6+, SwiftUI. Images follow the pipeline convention of 1 pt = 1 px (scale 1); any new
  `UIGraphicsImageRenderer` must set `format.scale = 1` (see `PageImageRenderer.rotated`).
- Page size is preserved on edit (`processAndReplaceCurrentPage` reuses the existing mediabox).
- Localized in en, es, fr, de, it, zh-Hans via `Localizable.xcstrings`. New strings so far: "Crop",
  "Erase", "Undo", the area-count label (pluralised), and the "clears the erased areas" note. FR/ES
  are reviewed by Peter; de/it/zh-Hans get a back-translation QA file in `docs/superpowers/qa/`.
  `scripts/verify-localization.py` must pass.
- Unit tests via `scripts/test.sh` (its count is authoritative). Test-first.
- Accessibility: the Crop/Erase switch and Undo need VoiceOver labels; the area count should be
  announced when it changes.

## Left to the builder

- How the box-drawing gesture and overlay are built, and how screen points map to image pixels
  (`QuadOverlay` already does this mapping for the crop corners and is the model to follow).
- Exact band width for colour sampling and the minimum box size.
- Where the erase step lives in code (a small pure type, e.g. `PageEraser`, that takes an image and
  a list of rects and returns a new image, is the obvious shape and is easy to unit test).
- Whether to show a live preview of the fill in Erase mode or only the red boxes until Apply.

## Testing

- Unit: the eraser fills each rect with the sampled colour and leaves pixels outside untouched;
  output size and scale equal input; rects are clipped to the image; colour sampling on a uniform
  off-white image returns that colour.
- Unit: after erasing a rect over rendered text, OCR on the result no longer finds that word
  (follows the existing OCR test style).
- Device check: erase staple holes on a real scan with the Color filter and confirm no visible
  patch; erase a margin note and confirm search no longer finds it; confirm the page size is
  unchanged and that crop, rotate and filter still work as before.

## Release

Ships in 4.1. Bump `CURRENT_PROJECT_VERSION` and `MARKETING_VERSION` in **both** the app and
`PocketScannerControlsExtension` targets via Build Settings (never the General tab). What's New text
in all 8 store locales. A Featuring Nomination is optional and needs 3+ weeks' notice before a
fixed release date.
