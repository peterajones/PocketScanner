# Spec: Single-shot signature capture

**Date:** 2026-06-24
**Status:** COMPLETE — device-verified 2026-06-25, merged to `main` (ships as v2.1; version bump happens at archive time). See Implementation status below.
**Roadmap origin:** Signing follow-up ("single-shot signature capture" candidate).
**Target release:** v2.1 (the next release after v2.0; build on a feature branch so `main` stays v2.0).

## Implementation status (2026-06-24, end of day)

- ✅ **Single-shot camera** — `Capture/SingleShotCameraScanner.swift` (conforms to `DocumentScannerPresenting`); both `SignatureCaptureView` call sites swapped; dead `scannerPresenter` removed from `SettingsView`. Commit `a35fd41`. Verified on device. Manual shutter (no auto-capture) is intended — user confirmed.
- ✅ **Orientation fix** — `SignatureProcessor` read `.cgImage` and dropped `imageOrientation`; a portrait `UIImagePickerController` capture (`.right`) saved rotated. `normalizedUp()` redraws to `.up` first. Regression test `test_process_honorsImageOrientation`. Commit `7eac7ad`. User confirmed upright.
- ✅ **Crop step** — native Move & Scale via `allowsEditing = true`, prefers `.editedImage`. Commit `7f9c829`. Works; not the problem (see below).
- ✅ **Uneven-lighting halo (fix applied; awaiting device re-check) —** the saved signature showed a faint **radial gradient / vignette around the signature** that the old path never had. Root cause: `VNDocumentCameraViewController` (the old "auto-select") does document *enhancement* — it flattens the page to uniform white before returning the image; `UIImagePickerController` returns a **raw** photo with natural lighting falloff, and `SignatureProcessor`'s white-keying left the dim edges as a halo. **A `SignatureProcessor` gap, not a crop gap.** Fix (`5c719da`): **flat-field correction** before keying — estimate the illumination with a heavy Gaussian blur (clamped, then cropped back), then divide the greyscale image by it via `CIDivideBlendMode` so paper normalizes to uniform white while ink stays darker than its local background. Replaced the old `ImageFilterEngine` B&W round-trip with an inline `CIColorControls` contrast push. Regression test `test_process_flattensUnevenLighting_noHalo` (white→grey ramp background: dim-side paper keys transparent, ink stays opaque).
- ✅ **Perimeter rim / faint border (fix `c7ad212`)** — after flat-fielding, a thin dark rim at the photo edge (page edge / crop-boundary shadow) became just visible and `inkBounds` counted it as ink on every row/column, inflating the crop to nearly the whole frame (signature sat low in an oversized box with a faint border). Fix: `inkBounds` ignores a ~2% perimeter margin. Regression test `test_process_dropsPerimeterRim`. Device-verified: no border.
- ℹ️ **Known cosmetic (not a defect):** the capture **preview** (checkerboard) sometimes shows faint "wavy lines" — partial-alpha pixels visible against the checkerboard. They're invisible on the white page and the saved/placed signature is clean (user-confirmed "on save it cleans right up").

## Goal

Capture a signature with a **single photo** instead of the multi-page document scanner, removing
the friction where `VNDocumentCameraViewController` keeps auto-capturing until you tap **Done**
("the camera shooting off multiple times before the Done button"). One shot → preview.

## Scope decisions (from brainstorming)

- **Signature-only.** Document scanning stays the multi-page `VNDocumentCameraViewController`
  (unchanged) — documents are genuinely multi-page. There is **no user toggle**; the capture mode
  is implied by the task ("Add Signature" → single-shot; "Scan Document" → multi-page).
- **Crop step: native Move & Scale.** *(Revised 2026-06-24 during device testing — the original
  "no crop step" decision wasn't enough in practice.)* `UIImagePickerController.allowsEditing = true`
  shows Apple's standard move/zoom crop right after the shutter (returns `.editedImage`); the
  `SignatureProcessor` band-crop then tightens further. The crop frame is a fixed square — you zoom
  onto the signature and let the band-crop finish. A custom wide-aspect crop was considered and
  declined as too "editor-y" for a one-line native win.
- **No "Choose from Photos."** Most people don't keep signature photos in their library; the camera
  is the universal path. A photo picker stays a clean future follow-up if demand appears.
- **No perspective correction.** `VNDocumentCamera` auto-dewarped; the single-shot photo won't be.
  Acceptable — `SignatureProcessor` doesn't dewarp anyway, and a signature is small and photographed
  roughly flat; you resize/place it after.

## Architecture / components

The capture is abstracted behind `DocumentScannerPresenting`:
```
protocol DocumentScannerPresenting {
    func makeViewController(onFinish: @escaping ([UIImage]) -> Void,
                            onCancel: @escaping () -> Void) -> UIViewController
}
```
`SignatureCaptureView` already takes a `presenter: DocumentScannerPresenting` and uses
`images.first`. So the change is a **new presenter** + swapping it in at the signature call sites.

### `SingleShotCameraScanner` (new) — conforms to `DocumentScannerPresenting`
- Wraps **`UIImagePickerController`** with `sourceType = .camera` (a single-photo camera: shutter →
  Retake / Use Photo → returns one image; no batch, no "tap fast").
- A `Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate`:
  - `didFinishPickingMediaWithInfo` → take the cropped `.editedImage` (fallback `.originalImage`) → `onFinish([image])`.
  - `imagePickerControllerDidCancel` → `onCancel()`.
- **Camera availability guard:** if `!UIImagePickerController.isSourceTypeAvailable(.camera)`
  (e.g. simulator), the presenter calls `onCancel()` rather than presenting (signature capture is
  device-only; documents already require a camera).
- Mirrors `SystemDocumentScanner`'s coordinator-retention pattern (associated object) so the
  delegate stays alive for the controller's lifetime.

### Wiring
`SignatureCaptureView` is constructed in two places — Settings (`SettingsView`) and the viewer's
first-run (`DocumentViewerView`) — both currently pass `presenter: scannerPresenter` (the app's
`SystemDocumentScanner`). Change both to pass `presenter: SingleShotCameraScanner()`.
**`SignatureCaptureView` itself, `SignatureProcessor`, the preview, Rescan, and `SignatureStore`
are unchanged.** Document-scan call sites are untouched.

## Data flow

```
Add Signature (Settings or viewer first-run)
  → SignatureCaptureView(presenter: SingleShotCameraScanner(), store:)
  → UIImagePickerController(.camera, allowsEditing): shutter → Move & Scale → Use Photo → onFinish([photo])
  → SignatureProcessor.process(photo) → preview (Save / Rescan / Cancel)   [unchanged]
```

## Error handling / edge cases

- **No camera available** → presenter calls `onCancel()` (no crash, no empty picker).
- **Camera permission** → reuses the existing `NSCameraUsageDescription` (already set for document
  scanning); no new prompt or key.
- **Cancel / empty result** → existing `SignatureCaptureView.handleScan` already handles
  `images.first == nil` (→ `processingFailed`) and the cancel path.
- **Poor photo** → existing **Rescan** + the capture **Tip** cover retries.

## Testing

- `SingleShotCameraScanner` is a thin `UIViewController` wrapper — not meaningfully unit-testable
  (no logic beyond delegate plumbing). `SignatureProcessor`/`SignatureStore` are already tested.
- Verified **on device:** Add Signature → single-shot camera (one photo, no repeat-capture) →
  preview → Save; Rescan re-opens the camera; the resulting signature places/saves normally.

## Deliverables

- New `Capture/SingleShotCameraScanner.swift`.
- `Settings/SettingsView.swift` + `Viewer/DocumentViewerView.swift`: pass
  `SingleShotCameraScanner()` to `SignatureCaptureView` (two call-site swaps).
- Spec under `docs/superpowers/`. On merge, mark the roadmap "single-shot signature capture"
  candidate as shipped (v2.1).

## Non-goals

- Any change to document scanning (stays multi-page) or a single/multi toggle.
- A *custom* crop step (the native Move & Scale crop is used instead — see Scope decisions).
- "Choose from Photos" / a photo-library import path.
- Perspective correction of the single-shot photo.
