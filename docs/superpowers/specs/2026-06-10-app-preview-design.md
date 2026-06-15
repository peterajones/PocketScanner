# Spec: Pocket Scanner App Preview video (v1)

**Date:** 2026-06-10
**Status:** Shipped (v1.8) — built differently than planned; see as-built note.
**Roadmap entry:** `docs/FutureEnhancements.md` → *App Store presence → App Preview video*

> **As-built (2026-06-15):** the iMovie route in this spec did not pan out (iMovie
> letterboxes portrait footage and can't composite a transparent frame). The shipped
> video was edited in **CapCut** (4K export) and framed in iPhone 17 chrome via an
> **ffmpeg** overlay. The authoritative, reproducible workflow — including the exact
> ffmpeg command and the infinite-render gotcha — lives in
> `marketing/app-preview/README.md`. Final asset: `PocketScanner-v1.8-Framed.mp4`.

## Goal

Produce a ≤30-second App Preview video for the App Store's **6.9" iPhone slot**
(1290×2796), shot end-to-end on a physical **iPhone 17**, that leads with the hero
scan and shows the recently shipped features (filter-at-scan, search, annotate,
rotate). This is the second deliverable of the "App Store presence" effort, after the
screenshot template.

## Scope decisions (from brainstorming)

- **Single source: the physical iPhone 17** (6.3"). Real camera + real iCloud, one
  continuous capture source, no splicing. The only compromise is resolution (see below).
- **Storyboard A** — chronological "scan-first hero journey" with short on-screen
  captions so it reads while muted (App Store previews autoplay silent).
- **Content: prepared sample papers** (fake but realistic — receipt, recipe,
  lease/letter). No real/sensitive documents on screen.
- **Capture via QuickTime** on a Mac (iPhone connected by cable) — native resolution,
  no on-device red recording bar.
- **Edit in iMovie's App Preview project** (`File ▸ New App Preview`) — purpose-built
  for App Store previews; preserves the device's tall 19.5:9 aspect (a normal iMovie
  project is locked to 16:9 and would letterbox), and enforces the 30s limit. A final
  conform step scales the result to exactly 1290×2796.
- **Music: none by default** (muted autoplay; avoids copyright risk). Optional
  royalty-free track only if desired.

## Non-goals

- 6.5"/smaller iPhone or iPad preview sizes — only the required 6.9" slot (1290×2796).
- More than one preview — one App Preview for v1 (App Store allows up to 3).
- Voiceover narration — captions carry meaning; no spoken track.
- Automated/scripted capture — manual shoot-and-edit.

## Output specification

| Property | Value |
|----------|-------|
| Resolution | 1290 × 2796 px (portrait, exact) |
| Duration | ≤ 30 s (target ~25–28 s) |
| Codec | H.264 (ProRes 422 HQ also accepted by Apple) |
| Container | .mov or .mp4 |
| File size | ≤ 500 MB |
| Frame rate | 30 fps (record and export at the same rate) |

Source: [Apple — App preview specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/app-preview-specifications/).

### Resolution note

The iPhone 17 is the 6.3" model and screen-records at **1206×2622**. That is the same
~19.5:9 aspect ratio as the required 1290×2796, so on export the footage is **scaled
up ~7%** to hit 1290×2796 exactly. This minor upscale is the only trade-off of shooting
on the 6.3" device; it is visually acceptable and keeps everything to one authentic source.

## Storyboard A (beats)

Target ~25–28 s. Captions are short text overlays, brand purple `#7B12A1` on white,
kept inside the title-safe area.

| Beat | ~Time | On screen | Caption |
|------|-------|-----------|---------|
| 1. Scan | 0–7 s | Tap **+** → camera detects the page → capture → pick a **filter** (Color/Greyscale/B&W/Photo) → clean PDF saved | "Scan anything" |
| 2. Organize | 7–13 s | Library with thumbnails → move a doc into a **folder** | "Stay organized" |
| 3. Search | 13–20 s | Type a word in search → match **highlights** across docs → open the doc | "Find any word" |
| 4. Mark up | 20–27 s | **Highlight** a line, then **rotate** a page from the edit strip | "Mark it up" |
| 5. End card | 27–30 s | Pocket Scanner logo card (reuse the `LoadingView` look) | — |

The live scan in Beat 1 is the hero moment; pause ~1 s on each result so cuts breathe.

## Production pipeline

### 1. Pre-production
- Print 3–4 fake sample papers (receipt, recipe, lease/letter); keep one aside to scan
  **live** during the take.
- Pre-scan the others so the library looks lived-in (a Receipts folder, a Recipes
  folder, a loose doc). Remove/hide any real iCloud documents so only samples show.
- Device prep: Do Not Disturb / Focus on, battery 100% (or charging), strong Wi-Fi,
  brightness up, no Dynamic Island activities.

### 2. Capture (QuickTime, Mac + cable)
- QuickTime ▸ **New Movie Recording** ▸ select the iPhone as the camera/mic source.
- Shoot each beat as its own take; re-do freely (trimmed in edit). Move deliberately.
- QuickTime captures the live camera viewfinder during the scan beat at native res,
  with no red on-device recording bar.

### 3. Post-production (iMovie App Preview project)
- `File ▸ New App Preview`; import takes; assemble the five beats; trim to ~25–28 s.
- Add **caption** text overlays per the storyboard (title-safe, brand purple on white).
- Add the **end card** (~3 s) reusing the Pocket Scanner / `LoadingView` look.
- Music: none by default.
- Share ▸ **File** to export a portrait master (H.264). It will be at the source's
  1206×2622, not the target size — the conform step fixes that.

### 4. Conform, verify, deliver
- **Conform to exactly 1290×2796** (clean upscale, same 19.5:9 aspect — no letterbox).
  Run by Claude; needs `ffmpeg` (`brew install ffmpeg` if missing):
  ```
  ffmpeg -i <imovie-export>.mov -vf "scale=1290:2796:flags=lanczos" \
         -c:v libx264 -pix_fmt yuv420p -r 30 -an <final>.mp4
  ```
  (`-an` drops audio; previews autoplay muted. Keep audio only if a licensed track
  was added — then replace `-an` with `-c:a aac -b:a 128k`.)
- **Verify** with `mdls` (no install needed):
  ```
  mdls -name kMDItemPixelWidth -name kMDItemPixelHeight \
       -name kMDItemDurationSeconds <final>.mp4
  ```
  Expect width 1290, height 2796, duration ≤ 30.
- Commit the final export to `marketing/app-preview/`. Raw takes and the iMovie
  intermediate stay local (too large for git).
- Upload to App Store Connect as App Preview slot 1 of the 6.9" gallery.

## Deliverables

1. The final App Preview video committed under `marketing/app-preview/`
   (e.g. `marketing/app-preview/pocket-scanner-preview-6.9.mp4`).
2. A short `marketing/app-preview/README.md` documenting the storyboard, capture
   settings, and export/verify steps for re-shoots.

## Known constraints / accepted trade-offs

- ~7% upscale from 1206×2622 to 1290×2796 (shooting on the 6.3" iPhone 17).
- Manual workflow (no scripting). Acceptable for an occasional task.
- A normal iMovie project is locked to 16:9 and would letterbox portrait footage; we
  use iMovie's **App Preview** project to preserve the tall aspect, then conform to the
  exact 1290×2796 with a one-off `ffmpeg` re-encode (iMovie can't emit that custom size).
