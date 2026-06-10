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
