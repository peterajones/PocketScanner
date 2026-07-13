# App Store Media Refresh — Storyboard (2026-07-10)

**Status:** Approved 2026-07-10. Full refresh of the App Store screenshots **and** the
App Preview video, both of which had fallen behind the app (screenshots were the
v2.1 signing set; the App Preview was conformed from the v1.7 capture — several
releases stale). Positioning **leads with the differentiator: sign & date**.

## Positioning

Plain scanning is a commodity; the hook is **"scan a document, then sign *and* date
it right on your phone — no printer."** Scanning still appears, but it's not the
headline. Screenshot #1 and the video's payoff both center on a finished
signed-and-dated document.

## Screenshots (6.9" slot)

Six shots (trim to 5 by dropping #6 if it feels like filler). Framed device chrome
is allowed on screenshots (Guideline 2.3.3) — unlike the App Preview.

**FINAL SET AS SHIPPED (v2.8, 6 shots, 1290×2796, all top-aligned captions):**

| # | Shot | Caption (as shipped) |
|---|---|---|
| **1 — HERO** | Signed **Consulting Agreement** (Jordan Avery signature + date stamp on the Consultant line) | **Sign and date documents — right on your phone** |
| **2** | Scan **capture moment** (offer letter, live scanner UI + edge-detect). Dark top banner masks the on-screen chrome and carries the caption. | **No printer? No problem. — Scan it right off your screen** |
| **3** | "Choose a Signature" picker with 3 named signatures | **Save your signature — sign in a tap** |
| **4** | The **Add Date sheet** showing all 5 format presets | **Date it — in any format you need** |
| **5** | Library **grid view** — folder tiles + doc thumbnails | **Stay organized — with folders** |
| **6** | Inside **Work → Contracts** sub-folder (nesting) | **Folders within folders — keep it all sorted** |

Rationale: #1 = the sign+date one-two punch (unique), #2 = the core scan reframed as
the emailed-doc workflow, #3–4 = signing + the new date stamp, #5–6 = organize + nest.

**Changes from the original plan:** the optional filter shot was **dropped** (the
Default-Filter dropdown read as cluttered, and the feature is covered in the App
Store "What's New"). #2 became the **scan capture moment** (not the crisp result) to
break the run of viewer screens — reframed as "scan an emailed doc off your screen"
since the app is camera-only (see the **Import a PDF** candidate in
`docs/FutureEnhancements.md`).

**Caption style (locked):** SF Pro Display, line 1 Bold + line 2 Semibold, centered,
navy `#14315C` on light shots / white on the dark scanner shot. **All top-aligned** —
where a screen had no natural top band (grid, sub-folder), the content was nudged
down in-app to open a caption band before capture. Composited with `caption.sh`.

## App Preview video (≤30s, unframed screen capture)

Builds to the payoff (a finished signed + dated page). **Keep the scan brief** —
it's a scanner, worth showing once, but the clock belongs to sign + date. **Text
overlays: yes** — short captions echoing the screenshots (App Previews often play
muted).

| Beat | Action | Overlay | ~sec |
|---|---|---|---|
| 1 | Open on the library with a few docs already there (established, not empty) | — | 2 |
| 2 | Tap ＋ → scan a document (brief) | **Scan** | 5 |
| 3 | Name & save → the new doc lands in the library | — | 3 |
| 4 | Open it → tap **Sign** → pick signature → drag/resize into place | **Sign** | 7 |
| 5 | Tap **Date** → pick a format → drop it by the signature | **Date it** | 7 |
| 6 | Rest on the finished page — signature + date | — | 3 |

Total ≈ 27s. Pacing: CapCut speed-ramps on the scan/save beats; linger on the
sign + date moments (the hook).

### Record on DEVICE, not simulator

The scan beat needs a real camera — the simulator has none, so it can't scan.
Record the whole thing on a physical device. Best: **QuickTime Player** on the Mac
with the iPhone connected by cable (File → New Movie Recording → pick the iPhone),
which captures the device screen (incl. the live scanner viewfinder) at native res,
straight to the Mac. (Control Center screen-record + AirDrop also works.) The status
bar will show real time (not 9:41) — fine for App Previews. **The demo library must
be on the device** (recipe §C) — if it only exists on the simulator, rebuild it there.

**Touch indicators + the iCloud staging library (the catch-22, solved):** the tap-circle
overlay is DEBUG tooling, but the **Debug build uses the `.dev` bundle with no iCloud**,
so it can't see the staging library that lives in iCloud on the **Release/prod** build.
Fix (shipped): the overlay now also activates via a **`-TouchIndicators` launch argument**
that works in Release. To record on the real iCloud build:
- Edit Scheme → **Run → Info → Build Configuration = Release**
- Run → **Arguments → Arguments Passed On Launch → add `-TouchIndicators`** (check while recording)
- Run on the connected device (installs over the prod app → iCloud demo library intact)
- Afterward, uncheck the arg / set config back to Debug.

### Shot list (teleprompter — one continuous take, trim later)

**Before record:** demo library on the device (folders + docs + 3 signatures); a doc
ready to scan (print, or on a 2nd screen); one dry run.

1. **Library** — rest on the library, folders + docs visible. *(hold ~2s)*
2. **＋ → Scan Document** → aim at the doc → let it auto-capture → **Keep Scan** → **Save**. *(brisk)*
3. **Name sheet** → short name → **Save** → the new doc drops into the library. *(hold ~1s on the new row)*
4. **Tap the new doc** → the viewer opens.
5. **Sign** → pick the signature → **drag onto the signature line → pinch to size → Done**. *(slow — the hook)*
6. **Date** → tap a **format** → **drag it beside the signature → Done**. *(slow)*
7. **Rest on the finished signed + dated page.** *(hold ~3s)* → **Stop.**

Then: CapCut rough-cut (trim, speed-ramp beats 2–3, add **Scan / Sign / Date it**
overlays) → export → hand to Claude for the 886×1920 / `setsar=1` / silent-audio conform.

## Captions — decide placement BEFORE shooting

**Lesson (v2.8):** pick the caption *position* for the whole set **up front** and frame
every shot to leave room for it there. Retrofitting placement per-shot causes cramped
captions (the signature-picker shot taught us this). What we settled:

- **Font/format (fixed across the set):** SF Pro Display, 2 lines, line 1 **Bold** +
  line 2 **Semibold**, centered, tight line-height. Color adapts to the background —
  **navy `#14315C`** on light shots, **white** on dark.
- **Position:** **top** for this set. When shooting, **scroll so there's a clean band**
  under the nav bar before you capture.
- **Per-shot reality:**
  - *Viewer shots* (signed doc, etc.) — natural grey band under the nav bar; navy on light, roomy.
  - *Scanner shot* — no band + dark UI + on-screen chrome to hide → a **dark banner** at top (white text) both masks the "screen" tell and carries the caption.
  - *Signature picker* — cards start high, so the top band is shallow and the caption sits snug under the nav title. Next time, scroll for headroom first.
- **Tool:** `caption.sh <in> <out> "line 1" "line 2" [top_px]` composites it (Chrome, no Krita). The `top_px` arg positions the band per shot.

## Production constraints (from `marketing/app-preview/README.md` + v1-status notes)

**Screenshots:**
- 6.9" Display slot, **1320×2868**. Framed device chrome OK.
- Canonical **9:41** status bar: `xcrun simctl status_bar booted override --time "9:41" …` then capture via `xcrun simctl io booted screenshot` (a plain Cmd-S can miss the override).
- Shoot on a **Release** build so the DEBUG-only Settings ▸ Developer row is excluded.
- DemoSeeder gives clean demo content; verify each exported still is the right screen before committing (Krita save-as has silently written to stale filenames before).

**App Preview video:**
- **UNFRAMED** screen capture only — a device frame fails Guideline 2.3.4 (this is why v2.2 was rejected). Frames only on screenshots.
- **886×1920** with **square pixels** — re-encode with `scale=886:1920:flags=lanczos,setsar=1` or Media Manager rejects it as 885px.
- Needs a **silent AAC audio track** or ASC rejects "corrupted audio."
- Edit in **CapCut**; use **ffmpeg only for the final conform** (dimensions/SAR/audio), not for editing.

## Upload

Media is per-version and **locks once a version is live**. v2.8 (27) is currently
Waiting for Review — decide at execution time whether to attach the refreshed media
to v2.8 (if ASC still allows editing the in-review version) or ship it with the next
version. Upload to the 6.9" slot; the App Preview goes in the same slot's video well.

## Execution note

This is manual production work (on-device/simulator captures + CapCut), not a code
change — no implementation plan. This doc is the shot list / checklist. Claude can
help with the **final ffmpeg conform** (886×1920 / setsar / silent-audio) once the
CapCut export exists, and with caption wording.

---

## v2.9 addendum — Import screenshots (A + B) — added 2026-07-13

v2.9 ships **Import a PDF** (Open in Pocket Scanner from Mail/Files/Safari **+** the
in-app `+` → Import PDF picker). The shipped v2.8 set never shows it and the v2.9
"What's New" **leads** with it, so add **two** screenshots to the existing 6.9" set
(6 of 10 slots used — room for both). Both are app-UI shots in the locked caption
style. **The App Preview video ships as-is** (video well unchanged); these two stills
cover the Import gap.

This also supersedes the workaround in shot **#2** — its "scan it right off your
screen" caption existed *because the app was camera-only* (see the reframing note
under "Screenshots" above). Import now tells the emailed-document story directly.
Leave #2 as-is for v2.9; optionally demote/re-caption it in a later pass.

**Placement:** insert as the **new #2–#3, right after the hero**, so the carousel
reads *sign & date (hero) → bring in an emailed PDF → scan → signature/date →
organize* — mirroring the What's New order. Current #2–#6 shift to #4–#8 (still ≤10).

**Captions — LOCKED** (SF Pro Display, line 1 **Bold** / line 2 **Semibold**,
centered, navy `#14315C`, **top-aligned** band — identical treatment to the shipped
set; composite with `caption.sh <in> <out> "line 1" "line 2" [top_px]`):

| # | Shot | Caption line 1 (Bold) | Caption line 2 (Semibold) |
|---|------|------|------|
| **A** | Library with the **`+` menu open** → Scan Document / **Import PDF** / New Folder | **Already have a PDF?** | **Import it in a tap** |
| **B** | An **imported contract open in the viewer**, clean **Sign · Date** bottom bar visible | **Emailed a contract?** | **Sign and date it — no printer** |

**Capture notes:**
- **Match the shipped set: 1290×2796**, 6.9" slot, framed device chrome OK.
- **Simulator is fine for both** — neither A nor B needs a camera (unlike the scan
  shot and the video). Use a **Release** build + **DemoSeeder**, with the canonical
  **9:41** status bar (`xcrun simctl status_bar booted override --time "9:41" …`, then
  capture via `xcrun simctl io booted screenshot` — a plain Cmd-S can miss the override).
- **Shot A:** from the library, tap **`+`** so all three menu items are visible
  (Scan Document / **Import PDF** / New Folder). Leave a clean band under the nav bar
  for the top caption.
- **Shot B:** open an official-looking demo contract (e.g., the **Consulting
  Agreement** or a **bank Transfer Receipt**) in the viewer. **No active search** (so
  the find bar stays hidden) and **not in edit mode** — we want the clean
  **Sign · Date · —— · Share · ⋯** bar on screen, which also showcases the v2.9 toolbar
  cleanup. The natural grey band under the nav bar carries the navy caption.
- Keep the caption band position consistent with #1 (`top_px`).

**Upload:** add A + B to the 6.9" slot in the new #2–#3 positions; the video well is
unchanged (existing App Preview ships as-is).
