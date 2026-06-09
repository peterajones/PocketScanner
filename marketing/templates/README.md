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
