# Spec: Single-shot signature capture

**Date:** 2026-06-24
**Status:** Approved (design) — ready for implementation plan
**Roadmap origin:** Signing follow-up ("single-shot signature capture" candidate).
**Target release:** v2.1 (the next release after v2.0; build on a feature branch so `main` stays v2.0).

## Goal

Capture a signature with a **single photo** instead of the multi-page document scanner, removing
the friction where `VNDocumentCameraViewController` keeps auto-capturing until you tap **Done**
("the camera shooting off multiple times before the Done button"). One shot → preview.

## Scope decisions (from brainstorming)

- **Signature-only.** Document scanning stays the multi-page `VNDocumentCameraViewController`
  (unchanged) — documents are genuinely multi-page. There is **no user toggle**; the capture mode
  is implied by the task ("Add Signature" → single-shot; "Scan Document" → multi-page).
- **No crop step.** Rely on `SignatureProcessor` (B&W → key white→alpha → largest-ink-band crop,
  which drops separated background) + the existing **Rescan** button for bad framing.
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
  - `didFinishPickingMediaWithInfo` → take the `.originalImage` → `onFinish([image])`.
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
  → UIImagePickerController(.camera): shutter → Use Photo → onFinish([photo])
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
- A manual crop step.
- "Choose from Photos" / a photo-library import path.
- Perspective correction of the single-shot photo.
