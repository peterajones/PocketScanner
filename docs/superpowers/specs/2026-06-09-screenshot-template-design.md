# Spec: App Store screenshot template (iPhone 17 chrome)

**Date:** 2026-06-09
**Status:** Approved (design) — ready for implementation plan
**Roadmap entry:** `docs/FutureEnhancements.md` → *App Store presence → Device-frame template*

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
  available). **Figma** is a sanctioned fallback — the four-layer model maps cleanly
  either way.
- **Target size: 1290×2796 px** — the App Store 6.9" display slot.
- **Look: hybrid** — framed device on a solid background, **no captions by default**,
  but a caption layer is built in (hidden) for per-shot use when space allows.
- **Background: pale lavender `#F2E9F7`** — a subtle nod to the brand purple from the
  app icon (`AccentColor` asset is empty, so the icon is the real brand identity:
  vivid purple line-art on white).
- **Device placement: centered, full device visible, lavender margin all around,
  with ~top 18% reserved as the caption zone.**

## Non-goals

- App Preview video (recording, framing, or submission) — deferred to a later effort.
- Marketing copywriting / per-slot captions — the template *supports* captions via a
  hidden layer, but writing them is not part of this deliverable.
- Automated/scripted screenshot generation (e.g. fastlane snapshot) — manual
  swap-and-export workflow for now.
- Other display sizes (e.g. iPad). Only the 6.9" iPhone slot (1290×2796) is targeted.

## Output specification

| Property | Value |
|----------|-------|
| Format | PNG |
| Dimensions | 1290 × 2796 px (exact) |
| Color | sRGB |
| Alpha | None — flattened/opaque on export |

App Store screenshots must be RGB with no alpha channel; the exported PNG is flattened
over the lavender background so it is fully opaque.

## Layer stack (bottom → top)

| # | Layer | Content | Notes |
|---|-------|---------|-------|
| 1 | **Background** | Solid pale lavender `#F2E9F7` | Fills the entire 1290×2796 canvas |
| 2 | **Screen content** | A 1290×2796 simulator screenshot | Scaled to the frame's screen region and **clipped** to the rounded-screen shape (Krita: clip/alpha-inherit to a screen-shape mask; Figma: place inside the screen frame with "clip content") so nothing spills past the bezel |
| 3 | **Device chrome** | iPhone 17 frame with a transparent screen cut-out | Sits above the screen layer so the bezel covers the screen edges; centered, fully visible, margin all around |
| 4 | **Caption** | Empty text layer positioned in the top ~18% headroom | **Hidden by default**; turned on and edited per-shot only when a screenshot leaves room for it |

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
- **Background:** flat fill, `#F2E9F7`, no external asset needed.

## Per-shot workflow

1. Open the master template (`.kra`, or the Figma file if using the fallback).
2. Replace the **Screen content** layer's image with the next screenshot — the clip
   mask re-applies automatically so it fits the screen region.
3. Optionally: show and edit the **Caption** layer for this slot.
4. **Export As… → PNG**, confirm the canvas is exactly 1290×2796.
5. Repeat for each of the up to 10 App Store screenshot slots.

## Deliverables

1. The master template file committed to the repo under `marketing/templates/`
   (`marketing/templates/screenshot-iphone17-6.9.kra`, built in Krita on Apple's
   bezel PNG).
2. A short `marketing/templates/README.md` documenting the swap-and-export workflow,
   the output spec, and the asset sources/fallbacks above.

## Known constraints / accepted trade-offs

- The device is scaled down to leave margin, so the native 1290×2796 screenshot is
  rendered slightly smaller inside the frame. This is normal for framed marketing
  shots, remains visually crisp, and the *exported canvas* is still exactly 1290×2796.
- Workflow is manual (no scripting). Acceptable for an occasional, low-volume task.
