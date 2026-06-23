# Spec: Multiple signatures

**Date:** 2026-06-23
**Status:** Approved (design) — ready for implementation plan
**Roadmap origin:** Signing 2.x follow-up (from the v2.0 signature feature's deferred list).
**Target release:** v2.x (next release after v2.0 / current main).

## Goal

Let the user keep **more than one** reusable signature (e.g. a full signature plus initials) and
**choose which to place** when signing. Local storage only (per-device), thumbnail-identified (no
names). The storage is structured so iCloud sync can be added later as a localized change — but
sync is **not** built here.

## Scope decisions (from brainstorming)

- **Multiple signatures**, stored locally (Application Support, like today). iCloud sync deferred
  (signatures are cheap to re-capture; sync adds a second subsystem of edge cases; some users
  prefer their signature stays on-device). Storage stays location-agnostic for an easy later add.
- **Thumbnail-only** — a signature is just an image; no names/labels. Cleaner data model and
  capture flow; signatures are recognized visually. Names can be added later, non-breaking.
- **Picker on Sign** only when it's ambiguous: 0 → capture; 1 → place directly (unchanged); 2+ →
  pick a thumbnail, then place.
- **Move** re-places the *same* signature by reading a signature id stored on the annotation.

## Architecture / components

### `Signature` (model)
```
struct Signature: Identifiable {
    let id: String      // its filename stem (a UUID)
    let image: UIImage
}
```
Pure value; `id` is the on-disk filename so the store and annotations can reference it.

### `SignatureStore` (refactor: single PNG → collection)
Directory of `<uuid>.png` files (injectable dir, unchanged for testability).
- `all() -> [Signature]` — every saved signature, **newest-first** (by file creation date).
- `add(_ image: UIImage) throws -> Signature` — writes a new `<uuid>.png`, returns it.
- `remove(id: String)` — deletes that file.
- `signature(withID id: String) -> Signature?` — load one by id (for Move).
- `var isEmpty: Bool` / `count`.
- **Migration:** on first access, if the legacy `signature.png` exists, rename it to a fresh
  `<uuid>.png` so an existing user's one signature becomes the first collection member. One-time,
  idempotent.

### `SignaturePicker` (new view)
A sheet listing the saved signatures as thumbnails (on the white card style). Tapping one calls
`onPick(Signature)`. Used by Sign (2+) and by Move's fallback when the source signature is gone.

### `SettingsView` — Signatures section
The single Add/Replace/Remove block becomes a **list**: `ForEach(store.all())` of thumbnail rows,
each with **swipe-to-delete** (consistent with the library), plus an **"Add Signature"** button
that runs the existing `SignatureCaptureView` capture flow and appends. No Replace, no names.

### `DocumentViewerView` — Sign, place, Move
- **Sign** button: `store.all()` → `[]` capture; `[one]` place it directly; `[2+]` present
  `SignaturePicker` → place the chosen one.
- **Place:** when creating the `ImageStampAnnotation`, set `annotation.contents = signature.id`
  (the PDF *Contents* field persists across save/reload), in addition to the existing
  `userName = signatureAnnotationName` tag.
- **Move:** read the tapped annotation's `contents` id → `store.signature(withID:)` → re-place that
  image at the moved position (existing remove-on-commit flow). If the id is missing or its
  signature was deleted, fall back to the `SignaturePicker` (choose a replacement). **Remove** is
  unchanged.

## Data flow

```
SETTINGS
  Add Signature → capture → store.add(image)            → list refreshes (newest-first)
  swipe a row  → store.remove(id)                       → list refreshes

SIGN (viewer)
  store.all().count == 0 → capture flow
                     == 1 → place that signature
                     >= 2 → SignaturePicker → place chosen
  place → ImageStampAnnotation(image, bounds, userName: tag); annotation.contents = signature.id
        → session.save()

MOVE (tap a placed signature → Move)
  id = annotation.contents
  store.signature(withID: id) ?  → re-place that image (seedRect = current bounds)
                                : → SignaturePicker → re-place chosen
```

## Error handling / edge cases

- **Legacy single signature**: migrated into the collection on first load (rename). Idempotent.
- **Move after the source signature was deleted**: `contents` id no longer resolves → fall back to
  the picker rather than failing silently.
- **Empty store on Sign**: routes to capture (unchanged).
- **`add` write failure**: surfaced like today's save failure (`try?` / no crash); the list just
  doesn't gain a row.
- Existing atomic-write + persistence behavior for the annotation is reused unchanged; `contents`
  rides along in the saved PDF.

## Testing

- **`SignatureStore` (unit):** `add` then `all` returns it; multiple adds order newest-first;
  `remove` drops one; `signature(withID:)` round-trips; **legacy `signature.png` migration** moves
  it into the collection exactly once.
- **Annotation id persistence (unit, extends `SignatureAnnotationPersistenceTests`):** an
  `ImageStampAnnotation` with `contents = id` survives `dataRepresentation()` → reload with the id
  intact (so Move can read it).
- **On-device:** add 2–3 signatures in Settings (thumbnails, swipe-delete); Sign with 2+ shows the
  picker and places the chosen one; Move re-places the same signature; delete a signature then Move
  one placed from it → picker fallback; single-signature path still places directly.

## Deliverables

- New: `Signature/Signature.swift`, `Signature/SignaturePicker.swift`.
- Refactor: `Signature/SignatureStore.swift` (collection + migration); update its tests.
- Touch: `Settings/SettingsView.swift` (list + Add), `Viewer/DocumentViewerView.swift` (picker on
  Sign, `contents` id on place, Move-by-id with picker fallback).
- Extend: `DocumentScannerTests/SignatureAnnotationPersistenceTests.swift` (id round-trip).
- Spec + plan under `docs/superpowers/`. On merge, note multiple-signatures shipped and that iCloud
  sync + names remain the 2.x follow-ups.

## Non-goals (deferred)

- iCloud sync of signatures (storage kept sync-ready; not built).
- Names / labels for signatures.
- Reordering the list.
- Typed or on-screen-drawn signatures; initials/date templates.
- Multiple signatures placed in one action.
