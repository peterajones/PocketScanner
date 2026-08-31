# v3.4 Screenshot Reorder

**Date:** 2026-08-29
**Ships with:** v3.4 (screenshots are version metadata; a live version's media is locked)
**Why now:** see the ASO section of `docs/FutureEnhancements.md` and the funnel data in the
project-status memory — impressions are the bottleneck, but the gallery is broken independently
of that and this is the cheap half of the fix.

---

## The problem

Verified against `marketing/app-preview/captions/*.tsv`. The eight shots currently run:

| # | Subject |
|---|---|
| 1 | signing (document already signed) |
| 2 | importing a PDF |
| 3 | signing (same document, unsigned) |
| 4 | scanning — *off a monitor* |
| 5 | saving a signature |
| 6 | date stamp |
| 7 | folders |
| 8 | folders (nested) |

**Five of eight are about signing.** Scanning a document — the thing the app is named for —
appears only at position 4 and is captioned as a screen-scanning niche. There is **no shot at
all** for searchable PDFs or on-device OCR, which is the actual technical differentiator.
Someone landing cold sees a signing app.

The first assets shown in search results carry most of the weight, and today they are signing,
importing, signing.

---

## Decisions taken

**1. The scan shot does not need a real paper document.** VisionKit's capture UI is identical
whatever the camera is pointed at — paper on a desk, a document on a monitor, a cat. The
existing frame (`v2.8/Stills/2a. Scanning a Document.png`) already shows the edge-detection
quad locked onto an *Offer of Employment* letter whose footer reads
`ACCEPTED AND AGREED / SIGNATURE / DATE` — which sets up scanning *and* signing in one image.

The caption was the problem, not the capture: *"No printer? No problem. Scan straight from the
screen"* took a generic scanning image and narrowed it to a niche. **Recaption generically and
the shot is fine.** This removes the only blocker that would have required device captures.

**2. Known limitation, accepted: that frame's UI text is English in all seven locales.**
`Flash` / `Filters` / `Shutter` are VisionKit's own labels, not ours — iOS renders them in the
device language, but our single shared capture was taken in an English simulator. Fixing it
properly means camera captures in five languages, which is precisely the work decision 1
avoids. **Mitigation:** move the caption band to the bottom so it covers the label row.
`render-captions.py` already supports arbitrary band position and colour (shot 2 uses
`top 2060`). The shutter circle stays visible below it and is language-neutral. The band is
also to be made **slightly taller** than the current default so the text isn't cramped.

**3. No localized App Preview videos. Closing this, not deferring it again.** It has been
"still open, deferred" at every release since v3.0. App Previews autoplay muted with no
narration, so there is nothing to translate but incidental UI text; the value is showing the
interaction, which reads identically in any language. Five CapCut projects is a bad trade for
that. The current v2.9 video is also feature-current — everything since (v3.0–v3.3) was
localization and bug fixes — so it is not stale, merely English. Remove the item from
`FutureEnhancements.md` rather than carrying it a sixth time.

**4. Shots 1 and 3 are the same document and one must go.** Both are Meridian Advisory Group's
Consulting Services Agreement: shot 3 blank, shot 1 signed with "Jordan Avery / July 12, 2026".
Same layout, same toolbar. They are a before/after pair **shown in the wrong order** — the
viewer meets the result before the setup.

Keep **shot 1's image** (the signature is the proof) with **shot 3's caption** (*"Emailed a
contract? Sign and date it — no printer"* is the stronger hook). One catch: shot 1's nav title
reads `Meridian Advisory Group Receipt — Jul 12` over a document that is plainly an agreement.
That is not `DemoSeeder` — its names differ — it is the app's own auto-namer misclassifying a
contract as a receipt during the capture session. **Rename the document before re-capturing.**

**5. The search shot must be the in-document highlighted match, NOT the results list.**

Search covers both scopes, confirmed from the shipped tip string: *"Search reads the text inside
every scan, even ones filed in folders. Tap a result to jump straight to the highlighted match."*

An earlier draft of this plan called for the **results list**. That was wrong. `DocumentRow`
renders only `displayName`, `formattedSubtitle` and the folder name — **there is no matched-text
snippet**. A viewer looking at a list of results cannot tell whether the term matched a filename
or the page contents, so the shot would prove nothing about OCR.

The proof is one tap further in: the document open with the term **highlighted on the page**,
plus the match counter and prev/next arrows in the toolbar. That is visible, unambiguous evidence
that the app read the page.

**Search term: `Northgate`.** Verified with PDFKit against the demo library — the PDFs do carry
text layers (Spotlight reports nothing for that folder, but it simply has not indexed it;
`Offer of Employment.pdf` has 1480 characters, `Consulting Agreement.pdf` 2258). `Northgate`
appears in the *body* of `Offer of Employment.pdf` and **in no filename**, so a hit can only have
come from OCR. `Costco` would be ambiguous — it is in that document's title too.

**This also disposes of a problem that would otherwise have blocked the shot.** The translated
demo libraries in `marketing/translations/` translate only document *titles*; the document
*contents* are English in every language. So a German user searching a German word would find
nothing. `Northgate` sidesteps it entirely: a proper noun is identical in all five languages, and
the proof here is **visual** — a highlight and a counter — rather than linguistic.

**Bonus narrative:** shot 1 is the scan frame showing that exact Northgate offer letter being
captured. The gallery therefore reads as *scan this document* → *find it again by a word buried
inside it*, which is a far better pair than two unrelated screens.

**6. Drop old shot 8 (nested folders).** Unlike 1 and 3 this is not literal duplication — shot 7
is the library root in grid view with three folders and two documents; shot 8 is inside the Work
folder showing one sub-folder and one document. But **roughly two-thirds of shot 8 is empty white
space**, its entire payload is two rows, and it currently ends the gallery on a near-empty
screen. What it sells — folders can contain folders — is an organisational nicety, not a reason
anyone picks a scanner.

Re-capturing it with a fuller Work folder was considered and rejected: a third capture across
five languages for the least compelling feature in the set. Apple permits ten shots and imposes
no penalty for fewer; **seven strong shots beat eight with a weak one**, and it is one less shot
to caption, render, QA and upload across seven locales.

(Incidental: shot 7 is grid view and shot 8 is list view, which was unintentional. Moot now.)

---

## Proposed order

Renumbered to match display order — the file name is the slot.

| New # | Shot | Source |
|---|---|---|
| 1 | Scan any document in seconds | existing 2a frame, **recaptioned**, taller bottom band |
| 2 | Search inside every scan | **new capture** — in-document highlighted match on `Northgate` |
| 3 | Emailed a contract? Sign and date it — no printer | **re-capture** (signed, corrected title) |
| 4 | Already have a PDF? Import it | old 2 |
| 5 | Save a signature once, reuse it | old 5 |
| 6 | Add a date in any format | old 6 |
| 7 | Keep everything in folders | old 7 |

**Seven shots, down from eight** — old 3 merges into old 1 (decision 4), and old 8 is dropped
(decision 6).

---

## Work

**Captures — 2 shots × 5 base languages = 10.** Only `en`, `es`, `fr`, `de`, `it` need captures;
`es-MX` rides `es` and `fr-CA` rides `fr`. Both are pure app UI — no camera, no device captures.

| Shot | What must be on screen |
|---|---|
| 2 | The Offer of Employment open, `Northgate` **highlighted on the page**, match counter and prev/next arrows visible in the toolbar |
| 3 | The Meridian consulting agreement **signed and dated**, renamed so the title bar reads "Consulting Agreement" and not "…Receipt" |

Raw simulator screenshots at 1290×2796, **no device chrome and no caption** — `caption.sh` adds
both. Status bar forced to 9:41. Save to `v3.4/Base/<lang>/2.png` and `v3.4/Base/<lang>/3.png`.

**Build/library setup.** Per the recipe (`demo-library-recipe.md` §A.2, §A.5): **Release** build
so the DEBUG-only Settings ▸ Developer row is hidden, on a **simulator never signed into iCloud**
so real documents cannot appear. Without iCloud the app falls back to its own local Documents
directory, so the library is populated by copying
`marketing/app-preview/PocketScannerDemoLibrary/*` into
`$(xcrun simctl get_app_container booted ca.peter-jones.DocumentScanner data)/Documents/`, and
the three named signatures by copying the prebuilt
`marketing/app-preview/demo-signatures/signatures.dat` into `…/Signatures/`. No seeding flag, no
scanning, no TCC-protected paths. Languages are then a relaunch:
`xcrun simctl launch booted ca.peter-jones.DocumentScanner -AppleLanguages '(de)' -AppleLocale de_DE`.

**Caption manifests.** Only `de.tsv` and `it.tsv` survive; `en`, `es`, `fr` and `fr-CA` were
deleted in the v3.1 restructure and are recoverable from git history. All seven need rewriting
for the new order and numbering.

**Slots 4–7 need no capture at all.** `v3.0/Base` and `v3.1/Base` no longer exist on disk — only
`de` and `it` kept theirs — but those four shots keep their captions and change only position,
so the **already-rendered Stills are copied and renumbered** (`v3.0/Stills/en/2.png` →
`v3.4/Stills/en/4.png`). No re-shoot, no re-render.

**Output tree:** `marketing/app-preview/v3.4/Base/<lang>/` and `v3.4/Stills/<lang>/`, matching
the v3.2 layout. `Base/` is gitignored; `Stills/` is committed.

**Localization QA.** New de/it caption copy triggers the standing back-translation obligation
(see `docs/FutureEnhancements.md` ▸ Internationalization). es/fr are Peter's own QA.

---

## Division of labour

| Task | Owner |
|---|---|
| Simulator captures, 2 shots × 5 languages | Peter |
| Recover deleted manifests, rewrite all 7 for the new order | Claude |
| Caption copy in 5 languages + de/it back-translation QA | Claude |
| Render via `render-captions.py`, verify dimensions | Claude |
| **Visual review of `v3.4/Stills/<lang>`** | Peter |
| Upload to ASC | Peter |

---

## ⚠️ ASC upload is real work, not a footnote

**49 images** — 7 locales × 7 shots — uploaded by hand into the 6.9" slot, one locale at a time,
through a UI whose **language selector resets on every page navigation**. This is the same toil
recorded against the metadata fields, and it has already caused one shipped mistake (the EN/ES
subtitles swapped in v3.0).

Budget real time for it, and verify the language indicator on every page before uploading.

This is also the strongest argument yet for the **ASC API push** item in `FutureEnhancements.md`
▸ Release tooling: the canonical assets already live in this repo, and screenshots are a far
bigger upload burden than the text fields that motivated the idea originally.
