# Pocket Scanner App Preview Implementation Plan

> **For agentic workers:** This is a manual video-production deliverable shot on a
> physical iPhone 17 and edited in iMovie. Most tasks are performed by the human at
> the keyboard/camera (marked **[Peter]**); a few are scriptable (marked **[Claude]**).
> Steps use checkbox (`- [ ]`) syntax for tracking. There is no code/TDD here —
> "verification" means visual review plus a dimension/duration check on the final file.

**Goal:** Produce a ≤30s App Preview video (1290×2796) for the App Store 6.9" slot,
shot end-to-end on the iPhone 17 following Storyboard A (scan-first hero journey).

**Architecture:** Capture each beat via QuickTime from a cabled iPhone 17 (native
1206×2622, real camera + iCloud), assemble + caption + end-card in iMovie's App
Preview project (preserves the tall aspect), conform to exactly 1290×2796 with a
one-off `ffmpeg` re-encode, verify with `mdls`, commit, and upload to App Store Connect.

**Tech Stack:** iPhone 17, QuickTime Player, iMovie (App Preview project), `ffmpeg`
(conform), `mdls` (verify).

**Spec:** `docs/superpowers/specs/2026-06-10-app-preview-design.md`

---

## File Structure

- Create: `marketing/app-preview/README.md` — storyboard + capture/edit/export steps **[Claude]**
- Create: `marketing/app-preview/pocket-scanner-preview-6.9.mp4` — the final video **[Peter+Claude]**
- Working/throwaway (not committed): raw QuickTime takes, the iMovie intermediate export

Only the final `.mp4` and the README are committed. Raw takes and the iMovie
intermediate stay local (too large for git).

---

## Task 1: Scaffold the directory and write the README [Claude]

**Files:**
- Create: `marketing/app-preview/README.md`

- [x] **Step 1: Create the directory and README with the exact content below**

```markdown
# App Preview video

The App Store preview video for Pocket Scanner (6.9" iPhone slot).

Spec: `docs/superpowers/specs/2026-06-10-app-preview-design.md`

## Files

- `pocket-scanner-preview-6.9.mp4` — final preview: 1290×2796, ≤30s, H.264.

## Output spec

| Property   | Value          |
|------------|----------------|
| Resolution | 1290 × 2796 px |
| Duration   | ≤ 30 s         |
| Codec      | H.264          |
| Frame rate | 30 fps         |
| Max size   | 500 MB         |

## Storyboard A (scan-first hero, ~25–28s)

| Beat | ~Time | On screen | Caption |
|------|-------|-----------|---------|
| Scan | 0–7s | Tap + → camera detects page → capture → pick filter → PDF saved | "Scan anything" |
| Organize | 7–13s | Library → move a doc into a folder | "Stay organized" |
| Search | 13–20s | Search a word → matches highlight → open doc | "Find any word" |
| Mark up | 20–27s | Highlight a line, rotate a page | "Mark it up" |
| End card | 27–30s | Pocket Scanner logo (LoadingView look) | — |

Captions: brand purple `#7B12A1` on white, title-safe.

## Capture (QuickTime, Mac + cable)

QuickTime ▸ New Movie Recording ▸ select the iPhone as camera/mic source. Records
native 1206×2622 with no red recording bar. Phone in Do Not Disturb, 100% battery,
strong Wi-Fi. Shoot each beat as its own take.

## Edit (iMovie App Preview project)

`File ▸ New App Preview` (preserves the tall aspect; a normal iMovie project is 16:9
and would letterbox). Assemble beats, add captions + end card, trim to ~25–28s, no
music. Share ▸ File to export a portrait master (will be 1206×2622).

## Conform to 1290×2796

    ffmpeg -i <imovie-export>.mov -vf "scale=1290:2796:flags=lanczos" \
           -c:v libx264 -pix_fmt yuv420p -r 30 -an pocket-scanner-preview-6.9.mp4

(`-an` drops audio — previews autoplay muted. If a licensed track was added, replace
`-an` with `-c:a aac -b:a 128k`.)

## Verify

    mdls -name kMDItemPixelWidth -name kMDItemPixelHeight \
         -name kMDItemDurationSeconds pocket-scanner-preview-6.9.mp4

Expect width 1290, height 2796, duration ≤ 30.

## Upload

App Store Connect ▸ the version ▸ 6.9" media ▸ App Preview slot 1.
```

- [x] **Step 2: Commit**

```bash
git add marketing/app-preview/README.md
git commit -m "docs: app preview README + storyboard/workflow"
```

---

## Task 2: Pre-production [Peter]

**Files:** none (physical + device prep)

- [ ] **Step 1: Print the sample papers**

Print the ready-made fake documents in `marketing/app-preview/sample-docs/` (Costco
receipt, banana-bread recipe, lease, travel itinerary, and a 3-page legal document).
Open each in a browser and print (Cmd+P, US Letter, 100%). Set one aside to scan
**live** during the take; see `sample-docs/README.md`.

- [ ] **Step 2: Seed the on-device library**

On the iPhone 17, open Pocket Scanner and scan the other prepared papers so the
library looks lived-in: create a **Receipts** folder and a **Recipes** folder, leave
one doc loose at the root. This mirrors the demo themes (receipts, recipes, a lease).

- [ ] **Step 3: Scrub anything private**

Make sure no real/sensitive iCloud documents are visible in the library or recents —
only the prepared samples should appear on screen.

- [ ] **Step 4: Prep the device for a clean capture**

Enable Do Not Disturb / a Focus, charge to 100% (or keep plugged in), confirm strong
Wi-Fi, raise brightness, and clear any Dynamic Island / Live Activities.

---

## Task 3: Capture the beats (QuickTime) [Peter]

**Files:**
- Working: raw `.mov` takes on the Mac (e.g. `~/Desktop/app-preview-takes/`)

- [ ] **Step 1: Start a QuickTime device recording**

Cable the iPhone 17 to the Mac. QuickTime Player ▸ File ▸ **New Movie Recording** ▸
click the arrow next to the record button ▸ select the **iPhone** as Camera and
Microphone. The iPhone screen mirrors into QuickTime at native resolution.

- [ ] **Step 2: Shoot Beat 1 — Scan**

Record: tap **+** → point the camera at the live sample paper → let edge-detection
capture it → pick a **filter** (Color/Greyscale/B&W/Photo) → save. Pause ~1s on the
saved PDF. Stop. Save the take.

- [ ] **Step 3: Shoot Beat 2 — Organize**

Record: in the library, move a document into a **folder** (drag or the move action).
Pause ~1s on the organized library. Stop. Save the take.

- [ ] **Step 4: Shoot Beat 3 — Search**

Record: tap search, type a word that exists in a sample (e.g. "Costco" or "banana"),
show the **highlighted** matches, open the matching doc. Stop. Save the take.

- [ ] **Step 5: Shoot Beat 4 — Mark up**

Record: **highlight** a line of text, then open the edit strip and **rotate** a page
left/right. Pause ~1s. Stop. Save the take.

- [ ] **Step 6: Review the takes**

Play each take back in QuickTime. Re-shoot any that are shaky, mistimed, or show
private content. Keep the best take of each beat.

---

## Task 4: Edit in iMovie (App Preview project) [Peter]

**Files:**
- Working: iMovie library + a portrait master export on the Mac

- [ ] **Step 1: New App Preview project**

iMovie ▸ `File ▸ New App Preview`. (This project type preserves the iPhone's tall
19.5:9 aspect — a normal iMovie project is locked to 16:9 and would letterbox.)

- [ ] **Step 2: Import and order the beats**

Import the four kept takes. Drag them to the timeline in storyboard order: Scan →
Organize → Search → Mark up. Trim each to its essential moment; total ~22–25s so far.

- [ ] **Step 3: Add captions**

Add a text title over each beat (iMovie titles), kept inside the title-safe area:
- Scan → "Scan anything"
- Organize → "Stay organized"
- Search → "Find any word"
- Mark up → "Mark it up"

Style: brand purple `#7B12A1` text on a white/clear background.

- [ ] **Step 4: Add the end card (~3s)**

Add a closing ~3s card with the Pocket Scanner logo (reuse the `LoadingView` look —
you can drop in `marketing/templates/LoadingView.png` or the app icon on white). Total
≤30s; aim for 25–28s.

- [ ] **Step 5: Export a portrait master**

iMovie ▸ Share ▸ **File** → highest quality, H.264. Save as
`~/Desktop/app-preview-master.mov`. (It will be 1206×2622 — the conform step fixes the
size.)

---

## Task 5: Conform, verify, deliver [Peter + Claude]

**Files:**
- Create: `marketing/app-preview/pocket-scanner-preview-6.9.mp4`

- [ ] **Step 1: Ensure ffmpeg is available [Claude]**

```bash
ffmpeg -version || brew install ffmpeg
```
Expected: a version banner (install first if missing).

- [ ] **Step 2: Conform to exactly 1290×2796 [Claude]**

```bash
ffmpeg -i ~/Desktop/app-preview-master.mov \
       -vf "scale=1290:2796:flags=lanczos" \
       -c:v libx264 -pix_fmt yuv420p -r 30 -an \
       marketing/app-preview/pocket-scanner-preview-6.9.mp4
```
(Same 19.5:9 aspect in and out, so this is a clean upscale with no letterboxing.
`-an` drops audio for the muted autoplay; if a licensed track was added in iMovie,
replace `-an` with `-c:a aac -b:a 128k`.)

- [ ] **Step 3: Verify dimensions and duration [Claude]**

```bash
mdls -name kMDItemPixelWidth -name kMDItemPixelHeight \
     -name kMDItemDurationSeconds \
     marketing/app-preview/pocket-scanner-preview-6.9.mp4
```
Expected:
```
kMDItemPixelWidth     = 1290
kMDItemPixelHeight    = 2796
kMDItemDurationSeconds = <= 30
```
Also confirm the file is ≤500 MB (`ls -lh` on the file).

- [ ] **Step 4: Visual review [Peter]**

Play `pocket-scanner-preview-6.9.mp4`. Confirm: no letterbox bars, captions readable
and title-safe, beats flow, no private content, ends on the logo card, ≤30s.

- [ ] **Step 5: Commit [Claude]**

```bash
git add marketing/app-preview/pocket-scanner-preview-6.9.mp4
git commit -m "feat: Pocket Scanner App Preview video (1290x2796)"
```

- [ ] **Step 6: Upload to App Store Connect [Peter]**

App Store Connect ▸ the app version ▸ the **6.9"** media set ▸ drag the `.mp4` into
**App Preview slot 1**. (Can be done on the current "Waiting for Review" version's
editable media, or the next version.)

- [ ] **Step 7: Clean up throwaways [Peter]**

Delete the raw QuickTime takes and `~/Desktop/app-preview-master.mov`. The committed
`.mp4` is the kept deliverable.

---

## Done

After Task 5: a committed, verified App Preview
(`marketing/app-preview/pocket-scanner-preview-6.9.mp4`, 1290×2796, ≤30s) shot
end-to-end on the iPhone 17 following Storyboard A, plus a README documenting the
storyboard and re-shoot workflow, uploaded to App Store Connect slot 1. Next steps
outside this plan: optional additional previews (App Store allows up to 3) and
localized variants.
