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

## Where it is used

Set as **`AccentColor`** in `Assets.xcassets`, which is the app-wide tint. It is not
hardcoded anywhere — everything reads `Color.accentColor`:

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
