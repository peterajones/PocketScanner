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
