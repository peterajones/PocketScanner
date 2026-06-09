# App Store Screenshot Template Implementation Plan

> **For agentic workers:** This is a manual graphics deliverable built in Krita's GUI.
> Most tasks are performed by the human at the keyboard (marked **[Peter]**); a few
> are scriptable (marked **[Claude]**). Steps use checkbox (`- [ ]`) syntax for
> tracking. There is no code/TDD here — "verification" means visual checks plus a
> dimension/color check on the exported PNG.

**Goal:** Produce a reusable Krita layered master that frames a Pocket Scanner
screenshot inside Apple's official iPhone 17 bezel (PNG) on a pale-lavender
background, with a hidden caption layer for optional per-shot use.

**Architecture:** Four-layer raster composite (background fill → clipped screen
content → device chrome → hidden caption), exported as a flattened opaque PNG at the
App Store 6.9" slot size. Manual swap-and-export workflow, one PNG per slot.

**Tech Stack:** Krita (Figma is a sanctioned fallback); Apple's iPhone 17 bezel PNG;
iOS Simulator; macOS `sips` for export verification.

**Spec:** `docs/superpowers/specs/2026-06-09-screenshot-template-design.md`

---

## File Structure

- Create: `marketing/templates/README.md` — workflow + output spec + asset sources **[Claude]**
- Create: `marketing/templates/screenshot-iphone17-6.9.kra` — the layered master **[Peter, in Krita]**
- Working/throwaway (not committed): the downloaded Apple bezel PNG and a sample
  simulator screenshot used to build & test the template

Only the `.kra` master and the README are committed. Simulator screenshots and the
exported gallery PNGs are outputs, produced per-release, and live outside this deliverable.

---

## Task 1: Scaffold the directory and write the README [Claude]

**Files:**
- Create: `marketing/templates/README.md`

- [x] **Step 1: Create the directory and README** (done — see committed README)

- [x] **Step 2: Commit** (done)

```bash
git add marketing/templates/README.md
git commit -m "docs: marketing screenshot template README + workflow"
```

---

## Task 2: Acquire the Apple bezel PNG and a test screenshot [Peter]

**Files:**
- Working: Apple's iPhone 17 bezel PNG + one sample screenshot

- [ ] **Step 1: Download Apple's official iPhone 17 bezel**

Download and mount the bezel (free, licensed for marketing materials):

```bash
curl -L -o ~/Downloads/Bezel-iPhone-17.dmg \
  https://devimages-cdn.apple.com/design/resources/download/Bezel-iPhone-17.dmg
open ~/Downloads/Bezel-iPhone-17.dmg
```

From the mounted volume, grab the iPhone 17 bezel **PNG** (transparent screen area).
We use the PNG, not the PSD (no Photoshop). Copy it somewhere handy, e.g.
`~/Desktop/iphone17-bezel.png`.
(Index page, for reference: [Apple Design Resources](https://developer.apple.com/design/resources/).)

- [ ] **Step 2: Capture a sample simulator screenshot**

Boot an **iPhone 17** simulator (to match the bezel), open Pocket Scanner to a
good-looking screen (e.g. a scanned document), then run:

```bash
xcrun simctl io booted screenshot ~/Desktop/scan-sample.png
```

- [ ] **Step 3: Verify the screenshot size**

```bash
sips -g pixelWidth -g pixelHeight ~/Desktop/scan-sample.png
```
Expected: `pixelWidth: 1206`, `pixelHeight: 2622` (iPhone 17, 6.3"). The exact pixel
size does not need to match the 1290×2796 canvas — it scales to fit the bezel's screen
region, same ~19.5:9 aspect, so no distortion. If you booted a different device you'll
see different numbers; that's fine as long as it's a portrait iPhone screenshot.

---

## Task 3: Build the composite in Krita [Peter]

**Files:**
- Create (in progress): `marketing/templates/screenshot-iphone17-6.9.kra`

- [ ] **Step 1: New image + background**

File ▸ New: **1290 × 2796 px**, RGB/Alpha, sRGB. Rename the default layer
**Background**, set foreground to `#F2E9F7`, fill it (Shift+Backspace).

- [ ] **Step 2: Import and place the chrome**

Layer ▸ Import/Export ▸ Import Layer → `~/Desktop/iphone17-bezel.png`. Rename it
**Device chrome**, keep it on **top**. Transform (Ctrl+T) to scale down so the whole
device is visible with margin and ~top 18% empty headroom; center horizontally; apply.

- [ ] **Step 3: Import and fit the screen content**

Layer ▸ Import/Export ▸ Import Layer → `~/Desktop/scan-sample.png`. Rename it
**Screen content**, place it **directly below Device chrome** and above Background.
Transform to cover the chrome's screen opening exactly; apply.

- [ ] **Step 4: Clip it to the screen shape**

- Duplicate **Device chrome**, move the copy **below** Screen content, rename it
  **Screen mask**.
- On **Screen mask**, keep only a solid fill of the screen opening: Select ▸ Opaque
  on the chrome, Select ▸ Invert to get the screen area, fill it solid, clear the rest.
- Select **Screen content** → right-click ▸ **Inherit Alpha**. It now shows only
  inside the screen.

- [ ] **Step 5: Add the hidden Caption layer**

Text tool → click in the top ~18% headroom → type `Caption goes here`. Rename
**Caption**, topmost layer, clean sans-serif, color `#2B2B2B` or brand purple
`#7B12A1`, centered. Toggle its visibility **off** (stays in the file for per-shot use).

- [ ] **Step 6: Visual check**

Full iPhone centered on lavender, screenshot filling the screen with crisp rounded
corners and no overspill past the bezel, empty headroom on top, caption hidden.

---

## Task 4: Save the master, export, and verify [Peter + Claude]

**Files:**
- Create: `marketing/templates/screenshot-iphone17-6.9.kra`
- Verify: a throwaway exported PNG

- [ ] **Step 1: Save the master [Peter]**

File ▸ Save As → `marketing/templates/screenshot-iphone17-6.9.kra` (native Krita
format, preserves all four layers). Confirm the **Caption** layer is hidden.

- [ ] **Step 2: Export a test PNG [Peter]**

File ▸ Export → `~/Desktop/export-test.png`, PNG, flattened and **opaque** (no alpha),
canvas 1290×2796.

- [ ] **Step 3: Verify the export [Claude]**

```bash
sips -g pixelWidth -g pixelHeight -g hasAlpha -g space ~/Desktop/export-test.png
```
Expected:
```
pixelWidth: 1290
pixelHeight: 2796
hasAlpha: no
space: RGB
```
If `hasAlpha: yes`, re-export flattened with the lavender Background visible.

- [ ] **Step 4: Commit the master [Claude]**

```bash
git add marketing/templates/screenshot-iphone17-6.9.kra
git commit -m "feat: iPhone 17 App Store screenshot template (Krita master)"
```

- [ ] **Step 5: Clean up throwaways [Peter]**

Delete `~/Desktop/iphone17-bezel.png`, `~/Desktop/scan-sample.png`, and
`~/Desktop/export-test.png`.

---

## Done

After Task 4: a committed Krita master
(`marketing/templates/screenshot-iphone17-6.9.kra`) frames any iPhone 17 simulator
screenshot in Apple's official iPhone 17 bezel on pale lavender, with a hidden caption
layer, plus a README documenting the swap-and-export workflow. Producing the actual
App Store gallery (replace screen content → export → repeat per slot) is the ongoing
per-release use of this template, not part of this plan. Next steps outside this plan:
the App Preview video (deferred), and refreshing the live gallery.
