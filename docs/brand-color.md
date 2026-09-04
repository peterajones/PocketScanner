# Brand colour

**`#7505A8`** — `rgb(117, 5, 168)`, sRGB. The purple in the Pocket Scanner app icon.

---

## Where it came from

Sampled from the app icon itself on 2026-09-04, not chosen. It is 8.3% of
`Assets.xcassets/AppIcon.appiconset/document-scanner-1024x1024.png` — the largest
non-white share, white being the background at 73.9%.

Reproduce it:

```bash
python3 -c "
from PIL import Image; from collections import Counter
im = Image.open('DocumentScanner/DocumentScanner/Assets.xcassets/AppIcon.appiconset/document-scanner-1024x1024.png').convert('RGB')
for (r,g,b), n in Counter(im.getdata()).most_common(5):
    print(f'#{r:02X}{g:02X}{b:02X}  {n/(im.width*im.height)*100:.1f}%')"
```

Neighbouring values (`#7505A6`, `#7306A8`) are anti-aliasing artefacts around the same
shape, not separate colours.

**The icon PNG is the source of truth.** If the icon is ever redrawn, re-sample rather
than assuming this value survived.

---

## The four accent tints

Since 2026-09-04 the user can choose the tint in **Settings ▸ Appearance ▸ Colour**. Purple
is the default and the brand colour; the rest exist because personalisation is a reasonable
thing for a mature app to offer.

**Four presets, never a free picker.** A `ColorPicker` was rejected on Peter's reasoning: a
user can tint everything white, or near enough, and then have no visible control left to
undo it with. Every preset below is contrast-checked in both schemes, so no choice can make
the app unusable.

| Tint | light (on white) | ratio | dark (on black) | ratio |
|---|---|---|---|---|
| Purple *(default)* | `#7505A8` | 8.96 | `#A046D2` | 4.30 |
| Blue | `#0A63C9` | 5.77 | `#4DA3FF` | 8.00 |
| Graphite | `#4A4A4F` | 8.81 | `#B0B0B8` | 9.75 |
| Green | `#1B7A3D` | 5.39 | `#45C46E` | 9.37 |

WCAG AA for UI components and graphical objects is **3.0:1**; every value clears it. This is
asserted by `AccentTintTests`, not just recorded here — adding a fifth tint that fails
contrast breaks the build.

**Light values are deeper, dark values are brighter**, which is the opposite of a naive
"darken it for dark mode". A luminous colour on white is the unreadable case. Saturation
stays 65–97% on the coloured tints so they read as luminescent rather than muted; graphite
is deliberately near-neutral at 4–6% as the "no colour" option.

Recompute before adding one:

```bash
python3 -c "
def lum(h):
    r,g,b=(int(h[i:i+2],16)/255 for i in (0,2,4))
    f=lambda c: c/12.92 if c<=0.03928 else ((c+0.055)/1.055)**2.4
    return 0.2126*f(r)+0.7152*f(g)+0.0722*f(b)
def ratio(a,b):
    la,lb=lum(a),lum(b); hi,lo=max(la,lb),min(la,lb); return (hi+0.05)/(lo+0.05)
print(round(ratio('7505A8','FFFFFF'),2), round(ratio('A046D2','000000'),2))"
```

---

## Where it is used

Set as **`AccentColor`** in `Assets.xcassets`, and applied at runtime with `.tint(...)` at
the `WindowGroup` root so the user's choice wins. The asset remains the default, and remains
the tint iOS uses outside the app — Home Screen badges, the app's row in Settings.app — which
cannot be changed at runtime.

Nothing hardcodes a colour; everything reads `Color.accentColor`:

| Where | What it tints |
|---|---|
| `PageEditor/QuadOverlay.swift` | crop outline, corner handles, edge handles |
| `Viewer/EditModeView.swift` | selected-page border and checkmark |
| Everywhere else | SwiftUI's default tint: buttons, links, pickers, switches |

Because it is the accent colour, **setting it changed the whole app**, not just the crop
overlay. Buttons and controls that were the system blue are now brand purple.

### Dark mode

The colorset carries a second appearance: **`#A046D2`**, the same hue lifted about 18% in
lightness. `#7505A8` is dark enough that a 1.5–2pt stroke of it disappears against the
shadows in a scan on a dark background. Anything added to the catalog later should carry
both appearances for the same reason.

---

## Why it was empty before

`AccentColor.colorset` existed but had **no colour defined** — Xcode creates the entry when
a project is made and nothing had ever filled it in. `Color.accentColor` therefore fell back
to the system blue, which is why the app looked like stock SwiftUI rather than like its own
icon. Found on 2026-09-04 while changing the crop-handle colour; the honest fix was to fill
in the accent colour rather than hardcode purple into one view.
