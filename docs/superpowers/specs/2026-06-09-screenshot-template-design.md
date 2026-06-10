# Spec: App Store screenshot template (iPhone 17 chrome)

**Date:** 2026-06-09 (revised 2026-06-10)
**Status:** Built — first screenshot (`LoadingView.png`) produced and verified
**Roadmap entry:** `docs/FutureEnhancements.md` → *App Store presence → Device-frame template*

> **2026-06-10 revision:** dropped the lavender background and the caption layer in
> favour of a **full-bleed** device whose screenshot fills the viewport, flattened to
> white. A lavender margin would read as a "halo" against the App Store's white
> background, and a full-bleed screen leaves no headroom for captions. Sections below
> reflect the revised design.

## Goal

Produce a reusable layered master file that frames a Pocket Scanner app screenshot
inside iPhone 17 device chrome, so the App Store gallery looks intentional and
consistent instead of like bare screen captures. This is the **first deliverable**
of the broader "App Store presence" effort; the App Preview *video* is explicitly
**out of scope** here (deferred — see Non-goals).

## Scope decisions (from brainstorming)

- **Static screenshots only.** The App Preview video is deferred; a video cannot be
  a layer in a raster image file, so it gets its own workflow later.
- **Tool: Krita** (primary), using Apple's iPhone 17 bezel **PNG** (no Photoshop
  available). **Figma** is a sanctioned fallback — the layer model maps cleanly either way.
- **Target size: 1290×2796 px** — the App Store 6.9" display slot.
- **Look: full-bleed device, no background tint, no captions.** The device fills the
  canvas; the screenshot fills the device's viewport. Anything transparent flattens to
  **white** on export so it blends into the App Store's white background (no coloured
  margin/"halo").
- **Caption text:** none. A full-bleed screen leaves no headroom; each screenshot's own
  content carries any messaging.

## Non-goals

- App Preview video (recording, framing, or submission) — deferred to a later effort.
- Caption / marketing copy overlays — dropped (full-bleed leaves no room); messaging
  lives in the screenshot content itself.
- Automated/scripted screenshot generation (e.g. fastlane snapshot) — manual
  per-shot layer-and-export workflow for now.
- Other display sizes (e.g. iPad). Only the 6.9" iPhone slot (1290×2796) is targeted.

## Output specification

| Property | Value |
|----------|-------|
| Format | PNG |
| Dimensions | 1290 × 2796 px (exact) |
| Color | sRGB |
| Alpha | None — flattened/opaque on export |

App Store screenshots must be RGB with no alpha channel; the exported PNG is flattened
to white so it is fully opaque (verified: `LoadingView.png` → `hasAlpha: no`).

## Layer stack (bottom → top)

The master `.kra` holds the **Device chrome** plus one **Screen content** layer per
screenshot (each hidden except the one being exported). On export, transparent areas
flatten to white.

| # | Layer | Content | Notes |
|---|-------|---------|-------|
| 1 | **Screen content** (one per slot) | A simulator screenshot | Sits behind the chrome and fills the device's viewport edge-to-edge. Only one is visible at export time |
| 2 | **Device chrome** | Apple's iPhone 17 bezel with a transparent screen cut-out | Top layer; full-bleed (device fills the canvas). Its transparent screen lets the screenshot show through; transparent outer corners flatten to white on export |

## Asset sources

- **Device chrome:** Apple's **official iPhone 17 bezel**, free and explicitly
  licensed for marketing materials, shipped as **Photoshop + PNG** with a transparent
  screen area:
  [Bezel-iPhone-17.dmg](https://devimages-cdn.apple.com/design/resources/download/Bezel-iPhone-17.dmg)
  (index: [Apple Design Resources](https://developer.apple.com/design/resources/)).
  - Apple ships an iPhone **17** bezel but not a 17 **Pro Max** one. The base 17's
    native screen is 1206×2622; it scales into the 1290×2796 canvas without distortion
    because all current iPhone screens share the ~19.5:9 aspect ratio.
- **Screen content:** iOS Simulator, **iPhone 17 device** (to match the bezel). A
  simulator screenshot is the raw screen content (what goes *inside* the viewport);
  it does **not** include device chrome.
- **Background:** none — transparent areas flatten to white on export.

## Per-shot workflow

1. Open the master `.kra` in Krita (or the Figma file if using the fallback).
2. Add a new **Screen content** layer for this slot (behind the chrome), drop in the
   screenshot, and fit it to fill the viewport.
3. Turn its visibility **on** (and any other slot layers **off**).
4. **Export As… → PNG**, flattened, no alpha; confirm the canvas is exactly 1290×2796.
5. Repeat for each of the up to 10 App Store screenshot slots.

## Deliverables

1. The master template file committed to the repo under `marketing/templates/`
   (`marketing/templates/PocketScannerAppPreview.kra`, built in Krita on Apple's
   bezel PNG).
2. A short `marketing/templates/README.md` documenting the swap-and-export workflow,
   the output spec, and the asset sources/fallbacks above.

## Known constraints / accepted trade-offs

- The device is full-bleed, so the screenshot is scaled to the viewport and only a
  thin white margin shows at the rounded canvas corners — intentional, to blend with
  the App Store's white background.
- Workflow is manual (no scripting). Acceptable for an occasional, low-volume task.
