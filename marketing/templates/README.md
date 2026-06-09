# App Store screenshot templates

Layered masters for framing Pocket Scanner screenshots for the App Store gallery.

Spec: `docs/superpowers/specs/2026-06-09-screenshot-template-design.md`

## Files

- `screenshot-iphone17-6.9.kra` — Krita master for the **6.9" iPhone slot**, built on
  Apple's official iPhone 17 bezel PNG. Four layers, bottom → top:
  1. **Background** — solid pale lavender `#F2E9F7`, fills the canvas.
  2. **Screen content** — the simulator screenshot, clipped to the screen shape.
  3. **Device chrome** — Apple's iPhone 17 bezel, transparent screen, centered with margin.
  4. **Caption** — empty text layer in the top ~18%, **hidden by default**.

## Output spec

| Property   | Value             |
|------------|-------------------|
| Format     | PNG               |
| Dimensions | 1290 × 2796 px    |
| Color      | sRGB              |
| Alpha      | None (flattened)  |

## Make a screenshot (per slot)

1. Capture the screen content from an **iPhone 17 simulator** (matches the bezel):
   `xcrun simctl io booted screenshot ~/Desktop/scan.png`
   (The iPhone 17 sim captures at 1206×2622; it gets scaled to fit the bezel inside
   the 1290×2796 canvas — same ~19.5:9 aspect, so no distortion.)
2. Open `screenshot-iphone17-6.9.kra` in Krita.
3. Replace the **Screen content** layer with the new screenshot (Layer ▸ Import/Export
   ▸ Import Layer, then re-fit). It re-clips to the screen shape automatically.
4. Optional: unhide the **Caption** layer and edit the text for this slot.
5. Export ▸ PNG. Confirm the canvas is exactly 1290×2796, flatten on export.
6. Repeat for each of the up to 10 App Store slots.

## Verify an export

    sips -g pixelWidth -g pixelHeight -g hasAlpha -g space export.png

Expect: pixelWidth 1290, pixelHeight 2796, hasAlpha no, space RGB.

## Asset sources

- **Device chrome:** Apple's **official iPhone 17 bezel** (Photoshop + PNG, free,
  licensed for marketing materials) —
  [Bezel-iPhone-17.dmg](https://devimages-cdn.apple.com/design/resources/download/Bezel-iPhone-17.dmg)
  (index: [Apple Design Resources](https://developer.apple.com/design/resources/)).
  The `.dmg` mounts on macOS and contains a PSD + PNG with a transparent screen area;
  we use the **PNG** in Krita.
  - Note: Apple ships an iPhone **17** bezel but not a 17 **Pro Max** one. The base
    17's native screen is 1206×2622; it scales into the 1290×2796 canvas cleanly
    because all iPhone screens share the ~19.5:9 aspect ratio.
- **Screen content:** iOS Simulator, iPhone 17 device (no chrome).
- **Background:** flat `#F2E9F7` fill.

## Tool paths

- **Krita (primary)** — four layers as above; clip the screen content to the screen
  shape with Inherit Alpha over a screen-shape mask (duplicate the bezel, reduce it
  to a solid screen fill, and use it as the mask below the screenshot).
- **Figma (fallback)** — a 1290×2796 frame, screenshot inside a screen frame with
  "clip content", chrome on top, hidden text layer.

Keep the same layer order and output spec regardless of tool.
