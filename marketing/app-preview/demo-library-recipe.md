# Demo Library Recipe

A reproducible recipe for building the **identical clean demo library** used in the
App Store screenshots and App Preview video. Rebuild this the same way every release
so media stays consistent and setup is fast. Pairs with the storyboard
(`2026-07-10-media-refresh-storyboard.md`) and the props in
`../templates/sample-docs/`.

---

## A. Environment prep (one-time per shoot)

1. **Recording device (for the video — needs a real camera to scan).** Delete and
   reinstall Pocket Scanner for a **fresh install**: empty library, no signatures, no
   legacy residue. (A Files-app iCloud "dump" does *not* clear the app's hidden
   `Signatures/` container — reinstall is the clean reset. See `docs/icloud-storage.md`.)
2. **Build config = Release.** Screenshots must come from a Release build so the
   DEBUG-only *Settings ▸ Developer* row is hidden.
3. **Status bar = 9:41.** On simulator: `xcrun simctl status_bar booted override --time "9:41" …`
   then capture with `xcrun simctl io booted screenshot`. On device, shoot near 9:41
   or clean up in post.
4. **Print the props** you'll scan live (US Letter, 100%): the docs below plus the
   three signature PNGs (they print black-on-white and scan like real signatures).
5. **Screenshots** can come from a fresh **simulator** (Release, 9:41) to stay isolated
   from real data — but the **video's scan beat needs a device** (no simulator camera).

---

## B. Canonical library contents

**7 documents**, arranged in **3 folders + 1 sub-folder**, plus **3 named signatures.**
All props are fictional (no real trademarks, seals, or PII).

### Folder tree
```
Library (root)
├── Work
│   └── Contracts              ← sub-folder (shows off v2.4 nesting)
│       ├── Consulting Agreement          (consulting-agreement.html)
│       └── Services Agreement (Multi-page)  (legal-document.html)
├── Personal
│   ├── Offer of Employment    (offer-of-employment.html)
│   └── Residential Lease      (lease-agreement.html)
├── Receipts
│   └── Costco Receipt         (costco-receipt.html)
├── Travel Itinerary           (travel-itinerary.html)   ← at root
└── Banana Bread Recipe        (banana-bread-recipe.html) ← at root
```

### Signatures (Settings ▸ Signature) — add all three, named
| Name | Prop file | Handwriting |
|------|-----------|-------------|
| Jordan Avery | `signatures/sig-JordanAvery.png` | Snell Roundhand |
| Taylor Morgan | `signatures/sig-TaylorMorgan.png` | Bradley Hand |
| Morgan Ellis | `signatures/sig-MorganEllis.png` | Savoye LET |

Three named signatures make the "Choose a Signature" picker look real and show off
the multiple-signatures + names features.

---

## C. Build order (step by step)

Do it in this order so docs land in the right folders and nothing needs moving:

1. **Folders first.** Library ▸ **＋ ▸ New Folder** → create `Work`, `Personal`,
   `Receipts`. Open `Work` ▸ **＋ ▸ New Sub-folder** → `Contracts`.
2. **Populate each folder by scanning from inside it.** Open the target folder ▸ **＋
   ▸ Scan** ▸ scan the printed prop ▸ name it exactly as in the tree ▸ Save. (Saving
   from inside a folder files it there — no Move needed.)
   - `Work/Contracts`: Consulting Agreement, Services Agreement (scan all 3 pages)
   - `Personal`: Offer of Employment, Residential Lease
   - `Receipts`: Costco Receipt
   - root: Travel Itinerary, Banana Bread Recipe
3. **Signatures.** Settings ▸ Signature ▸ **Add** ▸ scan each printed signature prop
   ▸ tap the row ▸ **Rename** to the name above. Repeat for all three.
4. **Leave the docs unsigned/undated in the standing library** — you sign + date
   *live* during the video and for the hero screenshot (below). Don't pre-sign.

---

## D. Capture-time notes (what's signed for which shot)

- **Hero screenshot (#1):** open **Consulting Agreement** → **Sign** (place *Jordan
  Avery* on the Consultant line) → **Date** (drop a date stamp beside it) → capture
  the finished page. This is the one doc you leave signed+dated.
- **Video:** record the live arc on the device per the storyboard — scan a prop →
  save → open → **Sign** → **Date** → rest on the finished page. Use the Consulting
  Agreement or Offer of Employment as the doc you sign.
- **Folders shot (#5):** capture the root library showing the `Work / Personal /
  Receipts` folders (and open `Work` to show the `Contracts` sub-folder if you want a
  second shot).
- **Search beat** (if used): search "Costco" or "banana" to show cross-doc search.

---

## E. Per-release quick checklist

Once the library exists, a refresh is fast:

- [ ] Fresh install on the recording device (Release build)
- [ ] Create folders (§C.1)
- [ ] Scan the 7 docs into their folders (§C.2)
- [ ] Add + name the 3 signatures (§C.3)
- [ ] Shoot screenshots per the storyboard (9:41, Release)
- [ ] Record the App Preview arc on device
- [ ] Sign+date the Consulting Agreement for the hero (§D)
- [ ] Conform the video (886×1920 / `setsar=1` / silent audio) — Claude can help
- [ ] Upload to ASC 6.9" slot

---

## Notes

- **Why not DemoSeeder?** The `-SeedDemoData` seeder is DEBUG-only (so the build shows
  the Developer row — bad for screenshots) and seeds test content including a
  deliberately corrupt doc. This hand-built Release library is cleaner for media.
- **Reproducibility:** because the doc names, folders, and signatures are fixed here,
  every release's media starts from the same library — no improvising.
