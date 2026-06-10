# App Store Screenshot Template Implementation Plan

> **For agentic workers:** This is a manual graphics deliverable built in Krita's GUI.
> Most tasks are performed by the human at the keyboard (marked **[Peter]**); a few
> are scriptable (marked **[Claude]**). Steps use checkbox (`- [ ]`) syntax for
> tracking. There is no code/TDD here — "verification" means visual checks plus a
> dimension/color check on the exported PNG.

**Goal:** Produce a reusable Krita layered master that frames a Pocket Scanner
screenshot inside Apple's official iPhone 17 bezel (PNG), **full-bleed** (screenshot
fills the viewport), exported flattened to white.

**Architecture:** Full-bleed composite — Apple's iPhone 17 bezel (transparent screen)
on top, one screenshot layer per slot behind it filling the viewport, exported as a
flattened opaque PNG (transparent → white) at the App Store 6.9" slot size. Manual
per-shot layer-and-export workflow, one PNG per slot. No background tint, no captions
(a lavender margin would "halo" against the App Store's white background, and a
full-bleed screen leaves no caption headroom).

**Tech Stack:** Krita (Figma is a sanctioned fallback); Apple's iPhone 17 bezel PNG;
iOS Simulator; macOS `sips` for export verification.

**Spec:** `docs/superpowers/specs/2026-06-09-screenshot-template-design.md`

---

## File Structure

- Create: `marketing/templates/README.md` — workflow + output spec + asset sources **[Claude]**
- Create: `marketing/templates/PocketScannerAppPreview.kra` — the layered master **[Peter, in Krita]**
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
- Create (in progress): `marketing/templates/PocketScannerAppPreview.kra`

- [ ] **Step 1: New image**

File ▸ New: **1290 × 2796 px**, RGB/Alpha, sRGB. (No background fill — transparent
areas flatten to white on export.)

- [ ] **Step 2: Import and place the chrome (full-bleed)**

Layer ▸ Import/Export ▸ Import Layer → `~/Desktop/iphone17-bezel.png`. Rename it
**Device chrome**, keep it on **top**. Transform (Ctrl+T) so the device fills the
canvas (full-bleed); center it; apply.

- [ ] **Step 3: Import and fit the screen content (one per slot)**

Layer ▸ Import/Export ▸ Import Layer → `~/Desktop/scan-sample.png`. Rename it after
the slot (e.g. **LoadingView**), place it **directly below Device chrome**. Transform
it to fill the chrome's viewport edge-to-edge; apply. Add one such layer per
screenshot, keeping only the one you're exporting visible.

- [ ] **Step 4: Visual check**

Full-bleed iPhone, the screenshot filling the viewport behind the bezel with no
overspill, and the area outside the device transparent (will flatten to white).

---

## Task 4: Save the master, export, and verify [Peter + Claude]

**Files:**
- Create: `marketing/templates/PocketScannerAppPreview.kra`
- Verify: a throwaway exported PNG

- [ ] **Step 1: Save the master [Peter]**

File ▸ Save As → `marketing/templates/PocketScannerAppPreview.kra` (native Krita
format, preserves the chrome + all per-slot screenshot layers).

- [ ] **Step 2: Export the PNG [Peter]**

With only the target slot's screenshot layer visible: File ▸ Export → the slot's PNG
(e.g. `marketing/templates/LoadingView.png`), PNG, flattened and **opaque** (no alpha,
transparent → white), canvas 1290×2796.

- [ ] **Step 3: Verify the export [Claude]**

```bash
sips -g pixelWidth -g pixelHeight -g hasAlpha -g space marketing/templates/LoadingView.png
```
Expected:
```
pixelWidth: 1290
pixelHeight: 2796
hasAlpha: no
space: RGB
```
If `hasAlpha: yes`, re-export flattened (no "Store alpha channel / transparency" in
Krita's PNG export) so transparent areas become white.

- [ ] **Step 4: Commit the master + exported shots [Claude]**

```bash
git add marketing/templates/PocketScannerAppPreview.kra marketing/templates/*.png
git commit -m "feat: iPhone 17 App Store screenshot template (Krita master) + first shots"
```

- [ ] **Step 5: Clean up throwaways [Peter]**

Delete the downloaded bezel and any sample captures left on the Desktop. The exported
slot PNGs in `marketing/templates/` are kept.

---

## Done

After Task 4: a committed Krita master
(`marketing/templates/PocketScannerAppPreview.kra`) frames any iPhone 17 simulator
screenshot full-bleed in Apple's official iPhone 17 bezel, flattened to white, plus a
README documenting the per-shot layer-and-export workflow. Producing the full App Store
gallery (add a screenshot layer → export → repeat per slot) is the ongoing per-release
use of this template, not part of this plan. Next steps outside this plan: the App
Preview video (deferred), and refreshing the live gallery.
