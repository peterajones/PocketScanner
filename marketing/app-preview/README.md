# App Preview video

The App Store preview video for Pocket Scanner (6.9" iPhone slot), framed in iPhone 17
chrome.

Spec: `docs/superpowers/specs/2026-06-10-app-preview-design.md`
(Note: the spec/plan describe an earlier iMovie-based plan. This README documents what
actually shipped — the iMovie route was abandoned; see "Lessons" below.)

## Files

- `PocketScanner-v1.8-AppPreview-886x1920.mp4` — **the App Store upload** (App Preview slot 1).
  App Previews use **886×1920**, NOT the 1290×2796 screenshot size — see Output spec.
- `PocketScanner-v1.8-Framed.mp4` — high-res framed master (1290×2796). NOT the App Preview
  upload (wrong size for video); it's the source the 886×1920 is downscaled from, and is handy
  for web/social/press.
- Working inputs (not committed): the CapCut 4K export (`…-v1.7.mp4`, 2160×4692) and the
  chrome overlay PNG (`PocketScannerAppPreviewChrome1290x2796.png`).

## Output spec

⚠️ **App Preview video = 886×1920 — NOT the 1290×2796 screenshot size.** Apple's app-preview
resolution differs from the screenshot resolution; App Store Connect rejects a 1290×2796 video
as "wrong dimensions." Screenshots stay 1290×2796; only the **video** is 886×1920 (square pixels).

| Property   | App Preview **video**       | Screenshots (reference) |
|------------|------------------------------|-------------------------|
| Resolution | **886 × 1920 px** (SAR 1:1)  | 1290 × 2796 px          |
| Duration   | ≤ 30 s                       | —                       |
| Codec      | H.264                        | —                       |
| Frame rate | 30 fps                       | —                       |
| Audio      | none (muted autoplay)        | —                       |
| Max size   | 500 MB                       | —                       |

## Pipeline (what actually worked)

`capture → edit (CapCut) → 4K export → frame in chrome (ffmpeg) → downscale to 886×1920 → verify → upload`

### 1. Capture
QuickTime ▸ New Movie Recording ▸ select the cabled iPhone as camera/mic source. Records
the screen at native **1206×2622**, no red recording bar. Phone in Do Not Disturb, 100%
battery, strong Wi-Fi. Shoot each beat as its own take (we used `1.mov`–`7.mov`).

### 2. Edit — CapCut (NOT iMovie)
- New project; set the canvas to **Custom 1290×2796** (or let it match the first clip).
  This keeps the tall ~19.5:9 aspect — no letterboxing.
- Drag the takes onto the timeline in order; trim each by dragging its edges.
- **Export at 4K**, H.264, 30 fps, highest bitrate. (4K matters — see Lessons.)

### 3. Frame in the chrome (ffmpeg)
The chrome is a 1290×2796 PNG with a **transparent viewport** and **opaque white**
everywhere else. We scale the video to cover the viewport, lay it on a white base, then
overlay the chrome on top.

```bash
SRC="PocketScanner-v1.7.mp4"                          # CapCut 4K export (2160x4692)
CHROME="PocketScannerAppPreviewChrome1290x2796.png"
OUT="PocketScanner-v1.8-Framed.mp4"

ffmpeg -i "$SRC" -i "$CHROME" -filter_complex \
"color=white:s=1290x2796[bg];\
 [0:v]scale=1222:2655,setsar=1[scr];\
 [bg][scr]overlay=34:70:shortest=1[t];\
 [t][1:v]overlay=0:0[outv]" \
-map "[outv]" -t 28.366667 -r 30 -c:v libx264 -preset veryfast -crf 20 \
-pix_fmt yuv420p -an "$OUT"
```

What each piece does:
| Piece | Purpose |
|-------|---------|
| `color=white:s=1290x2796[bg]` | white base canvas at the App Store size |
| `[0:v]scale=1222:2655,setsar=1[scr]` | scale the video to **cover** the viewport (preserve aspect; slight L/R overscan gets masked by the bezel — avoids distortion) |
| `[bg][scr]overlay=34:70:shortest=1[t]` | place the video centered over the viewport |
| `[t][1:v]overlay=0:0[outv]` | lay the chrome on top; its clear viewport reveals the video, its frame + white hide the overscan |
| `-t 28.366667` | clip duration (App Store ≤30s) |

**⚠️ The infinite-render gotcha (this bit us):** `color=white` is an *infinite* source. The
first overlay therefore runs forever unless stopped — pegging all CPU cores. Always guard
it with **`shortest=1`** (end with the video) **and** an explicit **`-t <duration>`**.

#### How the viewport numbers were found
The screen rectangle (`scale=1222:2655`, `overlay=34:70`) came from measuring the chrome's
alpha channel. To re-derive for a different chrome PNG:

```bash
# 1. extract the alpha as grayscale (transparent = black)
ffmpeg -i "$CHROME" -vf alphaextract /tmp/alpha.png
# 2. sample a center row / column and find the 255->0 (into viewport) and
#    0->255 (out of viewport) transitions:
ffmpeg -i /tmp/alpha.png -vf "crop=1290:1:0:1398,format=gray" -f rawvideo - 2>/dev/null \
  | od -An -v -tu1 | tr -s ' ' '\n' | grep -v '^$' \
  | awk 'NR==1{p=$1;next}{i++} $1!=p{print "x="i": "p"->"$1; p=$1}'
```
Measured viewport here: **x 69–1221 (1152 wide), y 70–2725 (2655 tall)**, centered. We
scale the video to cover it (1222×2655) and place it at x=34, y=70 (overscan under the bezel).

### 3b. Downscale to the App Preview size (886×1920)
The chrome composite is 1290×2796; the App Preview must be **886×1920** — same ~19.5:9 aspect,
so a clean downscale. `setsar=1` forces **square pixels**: 886/1920 isn't *exactly* 1290/2796,
so without it ffmpeg leaves a non-1:1 SAR that App Store Connect also rejects as wrong-dimensions.

```bash
ffmpeg -i PocketScanner-v1.8-Framed.mp4 \
  -vf "scale=886:1920:flags=lanczos,setsar=1" \
  -c:v libx264 -preset veryfast -crf 20 -pix_fmt yuv420p -r 30 -an \
  PocketScanner-v1.8-AppPreview-886x1920.mp4
```

### 4. Verify
```bash
ffprobe -v error -select_streams v:0 \
  -show_entries stream=width,height,sample_aspect_ratio,codec_name \
  -show_entries format=duration -of default=noprint_wrappers=1 "$OUT"
```
Expect `width=886`, `height=1920`, `sample_aspect_ratio=1:1`, `codec_name=h264`, `duration ≤ 30`.
(`mdls` returns null on `/tmp`; use `ffprobe`.)

### 5. Upload
App Store Connect ▸ the editable version ▸ **6.9″** media ▸ **App Preview slot 1**. Media
is only editable on a version in "Prepare for Submission" — a live version's media is
locked, so this ships with the next version.

## Lessons (why the pipeline looks like this)

- **App Preview video resolution ≠ screenshot resolution.** Screenshots are 1290×2796, but
  the App Preview *video* is 886×1920 (Apple's app-preview spec). Uploading a 1290×2796 video
  fails with "dimensions are wrong." Also force `setsar=1` on the downscale — a non-1:1 pixel
  aspect triggers the same rejection even at the right pixel dimensions.
- **iMovie was a dead end.** Standard iMovie projects are locked to 16:9; portrait footage
  gets letterboxed, and a 1080p export left the phone only ~497 px wide → heavy artifacting
  when scaled back up. Its "App Preview" project type is inconsistent/removed across
  versions, and iMovie can't composite a transparent-PNG frame (it ignores alpha). Use a
  portrait-native editor (**CapCut**, DaVinci Resolve, or iMovie on iPhone/iPad).
- **Export at 4K from the editor.** Quality is set by how many pixels the phone occupies in
  the export. A 1080p export downscales the ~1206-wide source; 4K preserves it, and the
  final downscale to 1290 stays sharp.
- **Framed vs unframed.** We shipped framed (in chrome) for a premium look; Apple slightly
  prefers raw screen recordings, so a framed preview carries a small review risk. The
  unframed full-bleed version is the lower-risk fallback.
