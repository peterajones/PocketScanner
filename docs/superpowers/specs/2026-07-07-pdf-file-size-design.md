# Reduce scanned-PDF file size — design (v2.5 / build 24)

## Summary

Scanned PDFs are ~24× larger than they should be — a single-page scan is **~3.5 MB**
vs **~146 KB** for a comparable document off a Canon flatbed (VueScan). Fix it by
**downsampling + JPEG-compressing** each page image at assemble time, in the one
place every page is built (`PDFAssembler.renderPage`). Expect **10–20× smaller**,
flatbed-comparable, with no loss of searchability. A single invisible default — no
user setting.

## Motivation

The driving workflow is tax season: scan dozens of slips → organize into folders →
archive → move to Dropbox → feed TaxSlipReader. At 3.5 MB/page, a 25-slip folder is
~90 MB (slow Dropbox sync, bloated archives) instead of a few MB. Every real scanner
(the user's flatbed included) produces compact JPEG-compressed pages; the app does not.

## Root cause

`PDFAssembler.renderPage` embeds each page at **full camera resolution, 1 point per
pixel, with no downsampling and no JPEG** — CoreGraphics' default lossless embedding.
A ~12-megapixel phone capture stored losslessly = ~3.5 MB. (Confirmed: the app's PDFs
report "macOS Quartz PDFContext" as producer; the flatbed's report VueScan, which
scans at ~200 DPI and JPEG-compresses to ~146 KB.)

`PDFAssembler.renderPage` is the **sole** image→PDF path in the app (verified:
`PDFPage(image:)` is used nowhere). All three page-producing flows route through it:

- New scans: `ScanPipeline.assemble` → `PDFAssembler.assemble`.
- Edited pages (crop / rotate / filter): `PageEditorView.processAndReplaceCurrentPage`
  / `…FilterOnly` → `PDFAssembler().assemble` → `DocumentMutations.replacePage`.
- Added pages: `DocumentViewerView` → `pipeline.process` → `PDFAssembler.assemble`.

So one change compresses all three.

## Design

### 1. The change (one method: `PDFAssembler.renderPage`)

Before the existing `context.draw(cgImage, in: pageRect)`, insert a compression step:

1. **Downsample** the orientation-normalized image: if its long edge exceeds a target
   cap, scale down to the cap (preserving aspect); if it's already ≤ cap, leave it
   (**never upsample**).
2. **JPEG-encode** the (possibly downsampled) image at the target quality and draw the
   JPEG-backed image so the emitted PDF embeds the compressed stream.

Everything else in `renderPage`/`assemble` stays exactly as-is: orientation
normalization, page mediaBox derivation, the invisible OCR-text layer
(`drawInvisibleText`), and the metadata (`auxiliaryInfo`).

The page's point size still derives from the (now downsampled) pixel size at 1pt/px,
so it shrinks proportionally. The invisible-text layer is positioned relative to
`pageRect` from normalized (0–1) OCR coordinates, so it stays aligned regardless of
the downsample — no change needed there.

### 2. Parameters (single default; tuned on-device, legibility-first)

Starting values, to be dialed against a real tax slip before ship:

- **Long-edge cap:** ~2200–2500 px (≈ letter at ~200–230 DPI — plenty for fine print).
- **JPEG quality:** ~0.6–0.7.

Tuning principle: **flatbed-comparable size is the floor, not "smallest at any
cost."** If size vs legibility ever conflict, favor legibility (tax-slip fine print
must stay crisp). No user-facing setting in v2.5 (add one later only if a real
max-fidelity need appears).

### 3. The spike (de-risk first)

Confirm that JPEG-encoding + drawing into the existing `CGContext` PDF actually yields
a **small** file — i.e. CoreGraphics passes the JPEG through (DCTDecode) rather than
re-inflating it losslessly. Verify with a quick assemble-and-measure test.

- If it embeds small → done, Approach A as above.
- If CoreGraphics re-inflates → swap **only** the image draw to a JPEG-preserving
  embed (e.g. build that page's image XObject from the JPEG data directly, or render
  that page via `UIGraphicsPDFRenderer` drawing the JPEG-backed `UIImage`), keeping
  the invisible-text + metadata code untouched. This is the pre-agreed "B" fallback,
  scoped to the embed only.

### 4. Where the compression logic lives

Add a small, testable pure helper (e.g. `PageImageCompressor` under `Pipeline/`) that
takes a `UIImage` + params (long-edge cap, JPEG quality) and returns the downsampled
**JPEG `Data`**. `PDFAssembler.renderPage` then builds a JPEG-backed `CGImage` from
that `Data` to draw (Approach A), or — if the spike shows CoreGraphics re-inflates —
embeds the `Data` directly via the fallback. Keeping the resize/encode logic in the
helper makes the resolution/quality behavior unit-testable without building a PDF.

## Non-goals (v2.5)

- **No change to page dimensions or crop.** Pages remain sized at 1pt/px (physically
  large); the VNDocumentCamera deskew/crop is unchanged. "Smaller bytes" ≠
  "letter-sized pages" — the page-dimension convention is a separate axis, revisited
  later only if the on-screen scale is a problem.
- **No re-compression of existing documents.** New scans + added/edited pages only
  (all via `renderPage`). A "reduce size" action for already-saved PDFs is a possible
  future add.
- **No user-facing quality setting.** Single baked-in default.

## Components

- New: `Pipeline/PageImageCompressor.swift` — pure downsample + JPEG helper (+ tests).
- Modify: `Pipeline/PDFAssembler.swift` — `renderPage` calls the compressor before
  drawing; possibly the fallback embed if the spike requires it.

## Testing

Unit (matching the existing `PDFAssembler`/pipeline test style):

- **Compression works:** assemble a PDF from a large synthetic image (e.g. 3024×4032)
  and assert the output `Data` size is below a threshold (e.g. < ~400 KB), proving the
  downsample+JPEG path shrinks it. (This test is also the spike's assertion.)
- **Searchability preserved:** assemble with OCR observations and assert
  `PDFDocument.string` still contains the recognized text (invisible-text layer intact
  after compression).
- **No upsampling:** a small input image (long edge below the cap) keeps its
  dimensions — assert the page pixel/point size is unchanged.
- **Aspect ratio preserved** after downsampling a non-square image.
- `PageImageCompressor` pure tests: downsamples above the cap, leaves small images
  untouched, produces decodable JPEG data.

On-device smoke (at release time): scan a real tax slip → confirm the saved PDF drops
to flatbed-comparable size **and** the fine print is legible; edit a page and add
pages → confirm those are compressed too; open an existing (pre-fix) doc → unchanged
(no retroactive compression).

## Rollout

- Ships as **v2.5 (24)**.
- Update `FutureEnhancements.md` (mark C shipped; B/A remain next).
- Bump `MARKETING_VERSION` 2.4 → 2.5 and `CURRENT_PROJECT_VERSION` 23 → 24 at archive
  (or before the Release smoke test).
- **Release/iCloud smoke matters here too:** verify file sizes on the real device +
  iCloud path, not just Debug.
