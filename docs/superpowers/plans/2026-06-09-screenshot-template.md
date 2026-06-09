# App Store Screenshot Template Implementation Plan

> **For agentic workers:** This is a manual graphics deliverable built in Krita's GUI.
> Most tasks are performed by the human at the keyboard (marked **[Peter]**); a few
> are scriptable (marked **[Claude]**). Steps use checkbox (`- [ ]`) syntax for
> tracking. There is no code/TDD here — "verification" means visual checks plus a
> dimension/color check on the exported PNG.

**Goal:** Produce a reusable Krita layered master that frames a 1290×2796 Pocket
Scanner screenshot inside iPhone 17 chrome on a pale-lavender background, with a
hidden caption layer for optional per-shot use.

**Architecture:** Four-layer raster composite (background fill → clipped screen
content → device chrome → hidden caption), exported as a flattened opaque PNG at the
App Store 6.9" slot size. Manual swap-and-export workflow, one PNG per slot.

**Tech Stack:** Krita (primary; Figma sanctioned fallback), iOS Simulator, macOS
`sips` for export verification.

**Spec:** `docs/superpowers/specs/2026-06-09-screenshot-template-design.md`

---

## File Structure

- Create: `marketing/templates/README.md` — workflow + output spec + asset sources **[Claude]**
- Create: `marketing/templates/screenshot-iphone17-6.9.kra` — the layered master **[Peter, in Krita]**
- Working/throwaway (not committed): a sample simulator screenshot used to build & test the template

Only the `.kra` master and the README are committed. Simulator screenshots and the
exported gallery PNGs are outputs, produced per-release, and live outside this deliverable.

---

## Task 1: Scaffold the directory and write the README [Claude]

**Files:**
- Create: `marketing/templates/README.md`

- [ ] **Step 1: Create the directory and README with the exact content below**

```markdown
# App Store screenshot templates

Layered masters for framing Pocket Scanner screenshots for the App Store gallery.

Spec: `docs/superpowers/specs/2026-06-09-screenshot-template-design.md`

## Files

- `screenshot-iphone17-6.9.kra` — Krita master for the **6.9" iPhone slot**
  (iPhone 17 chrome). Four layers, bottom → top:
  1. **Background** — solid pale lavender `#F2E9F7`, fills the canvas.
  2. **Screen content** — the simulator screenshot, clipped to the screen shape.
  3. **Device chrome** — iPhone 17 frame, transparent screen, centered with margin.
  4. **Caption** — empty text layer in the top ~18%, **hidden by default**.

## Output spec

| Property   | Value             |
|------------|-------------------|
| Format     | PNG               |
| Dimensions | 1290 × 2796 px    |
| Color      | sRGB              |
| Alpha      | None (flattened)  |

## Make a screenshot (per slot)

1. Capture the screen content from the simulator:
   `xcrun simctl io booted screenshot ~/Desktop/scan.png`
   (Use a 6.9" sim — iPhone 17 Pro Max / 16 Pro Max — so it is 1290×2796.)
2. Open `screenshot-iphone17-6.9.kra` in Krita.
3. Select the **Screen content** layer → replace its pixels with the new screenshot
   (Layer ▸ Import/Export ▸ Import Layer, or paste and re-fit). It re-clips to the
   screen shape automatically.
4. Optional: unhide the **Caption** layer and edit the text for this slot.
5. File ▸ Export ▸ PNG. Confirm the canvas is exactly 1290×2796, flatten on export.
6. Repeat for each of the up to 10 App Store slots.

## Verify an export

    sips -g pixelWidth -g pixelHeight -g hasAlpha -g space export.png

Expect: pixelWidth 1290, pixelHeight 2796, hasAlpha no, space RGB.

## Asset sources

- **Device chrome:** Apple Design Resources (official iPhone bezel, transparent
  screen). Fallback: iPhone 16 Pro frame — visually near-identical, same screen
  resolution.
- **Screen content:** iOS Simulator (raw 1290×2796 screen; no chrome).
- **Background:** flat `#F2E9F7` fill.

## Fallback tool

Krita is primary. If it gets annoying, Figma works the same way: a 1290×2796 frame,
the screenshot placed inside a screen frame with "clip content", the chrome on top,
and a hidden text layer. Keep the same layer order and output spec.
```

- [ ] **Step 2: Commit**

```bash
git add marketing/templates/README.md
git commit -m "docs: marketing screenshot template README + workflow"
```

---

## Task 2: Acquire the device chrome and a test screenshot [Peter]

**Files:**
- Working: an iPhone 17 chrome PNG (transparent screen) + one sample screenshot

- [ ] **Step 1: Get the iPhone 17 chrome art**

Download Apple Design Resources (https://developer.apple.com/design/resources/) and
extract an **iPhone 17** device frame as a PNG with a **transparent screen area**.
If iPhone 17 is not yet in the resources, use the **iPhone 16 Pro** frame — it is
visually near-identical and shares the 1290×2796 screen resolution.

- [ ] **Step 2: Capture a sample simulator screenshot**

Boot a 6.9" simulator (iPhone 17 Pro Max or iPhone 16 Pro Max), open Pocket Scanner
to a good-looking screen (e.g. a scanned document), then run:

```bash
xcrun simctl io booted screenshot ~/Desktop/scan-sample.png
```

- [ ] **Step 3: Verify the screenshot size**

```bash
sips -g pixelWidth -g pixelHeight ~/Desktop/scan-sample.png
```
Expected: `pixelWidth: 1290`, `pixelHeight: 2796`. If different, you booted a
non-6.9" device — switch sims and re-capture.

---

## Task 3: Create the canvas, background, and chrome layers [Peter, in Krita]

**Files:**
- Create (in progress): `marketing/templates/screenshot-iphone17-6.9.kra`

- [ ] **Step 1: New image**

Krita ▸ File ▸ New: Width **1290 px**, Height **2796 px**, Color model **RGB/Alpha**,
Profile **sRGB**. Create.

- [ ] **Step 2: Background layer**

Rename the default layer to **Background**. Set the foreground color to `#F2E9F7`
and fill the layer (Edit ▸ Fill with Foreground Color, or Shift+Backspace).

- [ ] **Step 3: Import the chrome**

Layer ▸ Import/Export ▸ Import Layer → select the iPhone chrome PNG. Rename the new
layer **Device chrome**. Make sure it is the **top** layer.

- [ ] **Step 4: Position and scale the chrome**

With the **Device chrome** layer selected, use the Transform tool (Ctrl+T) to scale
it down so the **whole device is visible** with a comfortable lavender margin on all
sides, and roughly the **top ~18% of the canvas is empty headroom** above the device
(reserved for the caption). Center it horizontally. Apply the transform.

- [ ] **Step 5: Visual check**

You should see the full iPhone frame centered on lavender, with its screen area
showing through as transparent (the lavender shows inside the screen for now), and
clear empty space across the top. If the device touches the canvas edges, scale it
down a bit more.

---

## Task 4: Add the clipped screen-content layer [Peter, in Krita]

**Files:**
- Modify (in progress): `marketing/templates/screenshot-iphone17-6.9.kra`

- [ ] **Step 1: Import the screenshot below the chrome**

Layer ▸ Import/Export ▸ Import Layer → `~/Desktop/scan-sample.png`. Rename it
**Screen content**. Drag it in the Layers docker so it sits **directly below Device
chrome** and **above Background**.

- [ ] **Step 2: Fit it to the screen region**

With **Screen content** selected, use the Transform tool (Ctrl+T) to scale/position
it so it exactly covers the chrome's screen opening (use the chrome's bezel as the
visual guide). Apply.

- [ ] **Step 3: Clip it to the screen shape**

So the screenshot's corners don't poke past the rounded screen, clip it:
- Duplicate the **Device chrome** layer, move the copy directly **below** Screen
  content, and rename it **Screen mask**.
- On **Screen mask**, erase everything except a solid fill of the screen opening
  (quickest: Select the transparent screen hole via Select ▸ Opaque on the chrome,
  Select ▸ Invert to get the screen area, fill it solid on Screen mask, clear the
  rest).
- Select the **Screen content** layer → right-click ▸ **Inherit Alpha** (the
  alpha icon). It now shows only where **Screen mask** below it is opaque — i.e.
  inside the screen.

(Figma fallback: instead of all this, place the screenshot inside the screen frame
and enable "Clip content".)

- [ ] **Step 4: Visual check**

The screenshot now fills the screen exactly, with crisp rounded corners and no
overspill past the bezel. The chrome bezel sits cleanly on top.

---

## Task 5: Add the hidden caption layer [Peter, in Krita]

**Files:**
- Modify (in progress): `marketing/templates/screenshot-iphone17-6.9.kra`

- [ ] **Step 1: Add a text layer**

Select the Text tool, click in the **top ~18% headroom**, and type a placeholder
like `Caption goes here`. This creates a vector text layer. Rename it **Caption**.
Make sure it is the **topmost** layer.

- [ ] **Step 2: Style it**

Set a clean sans-serif (e.g. system default), a size that reads well in the headroom,
and a color with good contrast on lavender (dark grey `#2B2B2B` or the brand purple
`#7B12A1`). Center it horizontally.

- [ ] **Step 3: Hide it by default**

Toggle the **Caption** layer's visibility **off** (eye icon) in the Layers docker.
It stays in the file for per-shot use but is hidden in the default template.

---

## Task 6: Save the master, export, and verify [Peter + Claude]

**Files:**
- Create: `marketing/templates/screenshot-iphone17-6.9.kra`
- Verify: a throwaway exported PNG

- [ ] **Step 1: Save the master [Peter]**

File ▸ Save As → `marketing/templates/screenshot-iphone17-6.9.kra` (native Krita
format, preserves all four layers). Confirm all layers are present and the **Caption**
layer is hidden.

- [ ] **Step 2: Export a test PNG [Peter]**

File ▸ Export → `~/Desktop/export-test.png`, PNG format. Ensure it exports the
flattened, opaque canvas (no alpha). Keep dimensions at 1290×2796.

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
If `hasAlpha: yes`, re-export with the background flattened (the lavender Background
layer must be visible and the image flattened on export).

- [ ] **Step 4: Commit the master [Claude]**

```bash
git add marketing/templates/screenshot-iphone17-6.9.kra
git commit -m "feat: iPhone 17 App Store screenshot template (Krita master)"
```

- [ ] **Step 5: Clean up throwaways [Peter]**

Delete `~/Desktop/scan-sample.png` and `~/Desktop/export-test.png` (not part of the
deliverable).

---

## Done

After Task 6: a committed Krita master (`marketing/templates/screenshot-iphone17-6.9.kra`)
frames any 1290×2796 simulator screenshot in iPhone 17 chrome on pale lavender, with a
hidden caption layer, plus a README documenting the swap-and-export workflow. Producing
the actual App Store gallery (replace screen content → export → repeat per slot) is the
ongoing per-release use of this template, not part of this plan. Next steps outside this
plan: the App Preview video (deferred), and refreshing the live gallery.
