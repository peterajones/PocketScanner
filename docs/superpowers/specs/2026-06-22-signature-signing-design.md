# Spec: Sign a document with a scanned signature

**Date:** 2026-06-22
**Status:** Approved (design) — ready for implementation plan
**Roadmap origin:** new idea (2026-06-22) — supersedes the shelved "Annotation rectangle-drag fallback" as the way to place free-form marks.
**Target release:** **v2.0 (18)** — signing is a marquee capability (scan → sign → send back), worth a major-version beat. Ships lean; the non-goals below land across 2.x.

## Goal

Let a user **sign a scanned document**: capture a real pen-on-paper signature **with the camera** (the app's core strength — not a finger smear), clean it to a transparent cut-out, and **drag/resize it onto a page**. One reusable saved signature; placed signatures are **editable** (deletable like existing highlights).

## Why scan-to-capture (key insight)

On-screen finger/stylus signatures look poor. The app already does VisionKit capture + perspective correction + a Black & White filter — so "sign paper, scan it" reuses the core competency and yields a real signature. The one genuinely new step is **removing the white paper to transparency** (a controlled, high-contrast keying problem — dark ink on light paper), which the existing B&W filter pre-conditions almost perfectly.

## Scope decisions (from brainstorming)

- **One saved, reusable signature** (not per-document, not multiple — yet).
- **Capture by scanning** paper via the existing VisionKit flow; **automatic** cleanup (no sliders) with a **preview + Rescan** escape — consistent with [[feedback-scope-scanner-not-editor]] (presets, not knobs).
- **Drag + pinch-resize placement** on the currently-viewed page.
- **Editable**: a placed signature persists as a deletable stamp annotation (same non-destructive model as highlights/strikethroughs), **not** flattened into the page.

## Architecture / components

New `Signature/` group, four focused units + two touch points.

### `SignatureProcessor` (pure-ish, testable)
`process(_ scanned: UIImage) -> UIImage?` — scanned signature paper → tight transparent cut-out:
1. **Perspective-correct** (reuse `PerspectiveCorrector`; use the detected document quad, falling back to the full-rect when none is detected).
2. **Black & White** (reuse the existing `ImageFilter` B&W preset) — drives paper→white, ink→black.
3. **Key white → alpha** — a Core Image luminance-to-alpha step: bright pixels become transparent, dark ink stays opaque.
4. **Auto-crop to ink bounds** — trim to the non-transparent bounding box so the saved asset is tight.
Returns nil on failure (caller offers Rescan).

### `SignatureStore`
Owns the **one** signature PNG on disk (a known app-storage path; **not** iCloud-synced in v1 — it's a local convenience, re-scannable on a new device).
- `save(_ image: UIImage)`, `load() -> UIImage?`, `clear()`, `var hasSignature: Bool`.

### `SignatureCaptureView`
Scan → `SignatureProcessor` → **preview on a checkerboard** (so transparency is visible) → **Save** (to `SignatureStore`) or **Rescan**. Used by both Settings and the viewer's first-run.

### `SignaturePlacementView`
Given the saved PNG and the current page, shows a **draggable, pinch-resizable** overlay over the page; **Done** maps the overlay's frame from view space → PDF page coordinates and asks the viewer to create the stamp annotation. **Cancel** discards.

### Touch points
- **`SettingsView`** — a small new **"Signature"** section (its own `Section`, since it has two actions + state): *Add / Replace Signature* and *Remove Signature* (calls `SignatureStore`); shows a thumbnail of the current signature when one exists.
- **`DocumentViewerView`** — a **"Sign"** toolbar action:
  - no saved signature → route into `SignatureCaptureView` first, then continue to placement;
  - on **Done**, create an image **stamp `PDFAnnotation`** at the chosen page rect, tagged with a new `DocumentSession.signatureAnnotationName`, and save via the existing `DocumentSession.save()`.
  - **move / delete**: extend the existing tap-to-annotation path — `AnnotationFactory.isUserDeletable` recognizes the signature tag → a **Move / Remove** dialog. **Move** re-opens placement seeded at the current rect; **Remove** deletes. Both are v1 (user confirmed move + remove wanted at launch).
- **Persistence RESOLVED (2026-06-22 spike):** image stamp annotations both persist *and render* across save→reload (verified: reloaded page renders the signature, center luminance 0.0). Editable-stamp model is viable as-is — no flatten / no appearance-stream injection.

## Data flow

```
SETTINGS (or first-run from viewer)
  scan paper → SignatureProcessor (perspective → B&W → key → crop) → preview
    Save → SignatureStore.save(png)   |   Rescan → re-capture

SIGN A DOCUMENT (viewer "Sign")
  hasSignature? no → capture flow first
  load png → SignaturePlacementView (drag/resize over current page)
    Done → view-rect → page-rect → stamp PDFAnnotation (tagged) → DocumentSession.save()
    Cancel → discard

LATER
  tap signature → Move (re-place, seeded at current spot) / Remove (delete) → save
```

## Error handling

- **Processing fails** (`SignatureProcessor` returns nil / empty crop): preview shows nothing useful → **Rescan**; never save an empty asset.
- **No signature on Sign**: route to capture, don't dead-end.
- **Stamp-annotation persistence (the one real risk):** PDFKit image-stamp annotations can be unreliable across the save→reload round-trip. The **plan front-loads a persistence spike**; if stamps don't survive reliably, escalate to the user with the fallback (flatten-on-commit) rather than silently changing the editable-vs-permanent decision.
- Existing save/coordination (atomic write + `NSFileCoordinator`) is reused unchanged.

## Testing

- **Unit — `SignatureProcessor`:** keying yields transparency (a white-background ink image → non-opaque corners, opaque ink); crop tightens to ink bounds; nil/empty handled.
- **Unit — `SignatureStore`:** save→load round-trips the image; `clear()` removes it; `hasSignature` tracks state.
- **Spike/integration:** a stamp `PDFAnnotation` with an image survives `DocumentSession.save()` → reload (assert it's still present and deletable). This is the go/no-go for the editable model.
- **On-device:** capture (good + deliberately bad scan → Rescan); place/drag/resize; reopen → signature present → remove; multi-page (signs the viewed page).

## Deliverables

- `Signature/SignatureProcessor.swift`, `Signature/SignatureStore.swift`, `Signature/SignatureCaptureView.swift`, `Signature/SignaturePlacementView.swift` (+ tests for the first two and the persistence spike).
- `SettingsView` Signature row; `DocumentViewerView` Sign action + stamp create/delete; `DocumentSession.signatureAnnotationName` tag.
- Spec + plan under `docs/superpowers/`. On merge, note signing shipped in v2.0 and that the deferred items below are the 2.x roadmap.

## Non-goals (deferred to 2.x)

- Multiple saved signatures.
- Typed or on-screen-drawn signatures.
- Initials / date / text stamps.
- iCloud-syncing the saved signature across devices.
- Auto-detecting the signature line / auto-placement.
- Signing multiple pages in one action.
