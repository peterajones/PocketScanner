#!/usr/bin/env bash
# Composite a 2-line App Store caption onto a 1290x2796 screenshot, optionally
# adding the iPhone device chrome in the same pass.
# Navy (#14315C) SF Pro Display — matches the demo docs' letterhead.
#
# Usage:  caption.sh <input.png> <output.png> "<line 1>" "<line 2>" [top_px] [fs1] [fs2] [band]
#   top_px  vertical position of the caption band (default 430 — the viewer's
#           grey band under the nav bar). Adjust per shot if the layout differs.
#   fs1/fs2 font sizes for line 1 / line 2 (default 78 / 66). Shrink these when a
#           longer localized caption (es/fr) would overflow the 1290px width.
#   band    optional CSS background behind the caption (e.g. "rgba(248,248,250,0.97)")
#           for full-bleed shots (the scan frame) that lack the app's own grey strip.
#   chrome  optional path to the device-bezel PNG (10th arg). When given, the raw
#           capture is placed INSIDE the bezel's screen cutout and the bezel is
#           composited over it — replacing the manual Krita step in
#           marketing/templates/README.md. Omit it for an input that is already
#           framed (e.g. the shared v2.8 scan frame).
#
# Requires Google Chrome (headless renderer). No Krita needed.
set -euo pipefail

CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
IN="$1"; OUT="$2"; L1="$3"; L2="$4"; TOP="${5:-430}"; FS1="${6:-78}"; FS2="${7:-66}"; BAND="${8:-}"; COLOR="${9:-#14315C}"
CHROME_PNG="${10:-}"
# Padding sets the band's height. Raised from 44/48 for v3.4: at the old values the
# two caption lines sat hard against the strip's edges and looked cramped.
BANDCSS=""; [ -n "$BAND" ] && BANDCSS="background:${BAND};padding:72px 0 76px;"

# The caption box is constrained to these same bounds (not the full 1290 canvas), so a
# banded caption stops at the bezel instead of running off the sides of the phone. Text
# position is unaffected: the cutout is symmetrical, so centring in 1152 offset by 69
# lands on the same pixel as centring in 1290.
#
# Screen cutout inside PocketScannerAppPreviewChrome1290x2796.png, measured from
# the PNG's alpha channel (the fully-transparent region): the bezel's glass.
# `object-fit:cover` reproduces Krita's "fit to fill the viewport" — the capture
# (1206x2622) is a slightly wider aspect than the cutout (1152x2656), so it
# scales to cover and the overflow is cropped evenly rather than distorted.
SCREEN_L=69; SCREEN_T=70; SCREEN_W=1152; SCREEN_H=2656

tourl() { python3 -c 'import urllib.parse,sys; print("file://"+urllib.parse.quote(sys.argv[1]))' "$1"; }
ABS="$(cd "$(dirname "$IN")" && pwd)/$(basename "$IN")"
URL="$(tourl "$ABS")"

if [ -n "$CHROME_PNG" ]; then
  CABS="$(cd "$(dirname "$CHROME_PNG")" && pwd)/$(basename "$CHROME_PNG")"
  [ -f "$CABS" ] || { echo "!! chrome PNG not found: $CABS" >&2; exit 1; }
  CURL="$(tourl "$CABS")"
  # Capture sits in the cutout, bezel on top, white behind (transparent areas of
  # the bezel flatten to white, matching the App Store's background).
  SHOT_LAYER="<img class=\"shot\" src=\"${URL}\"><img class=\"chrome\" src=\"${CURL}\">"
  SHOT_CSS=".stage{background:#fff;}
 .shot{position:absolute;left:${SCREEN_L}px;top:${SCREEN_T}px;
       width:${SCREEN_W}px;height:${SCREEN_H}px;object-fit:cover;display:block;}
 .chrome{position:absolute;left:0;top:0;width:1290px;height:2796px;display:block;}"
else
  SHOT_LAYER="<img src=\"${URL}\">"
  SHOT_CSS=".stage img{width:1290px;height:2796px;display:block;}"
fi

HTML="$(mktemp /tmp/caption.XXXXXX.html)"
cat > "$HTML" <<EOF
<!doctype html><html><head><meta charset="utf-8"><style>
 html,body{margin:0;padding:0;}
 .stage{position:relative;width:1290px;height:2796px;}
 ${SHOT_CSS}
 .cap{position:absolute;top:${TOP}px;left:${SCREEN_L}px;width:${SCREEN_W}px;text-align:center;
      ${BANDCSS}
      font-family:-apple-system,"SF Pro Display","Helvetica Neue",sans-serif;
      color:${COLOR};line-height:1.06;letter-spacing:-0.01em;}
 .cap .l1{font-weight:700;font-size:${FS1}px;}
 .cap .l2{font-weight:600;font-size:${FS2}px;}
</style></head><body>
 <div class="stage">${SHOT_LAYER}
 <div class="cap"><div class="l1">${L1}</div><div class="l2">${L2}</div></div></div>
</body></html>
EOF

"$CHROME" --headless=new --disable-gpu --hide-scrollbars --window-size=1290,2796 \
  --screenshot="$OUT" "file://$HTML" >/dev/null 2>&1
rm -f "$HTML"
echo "wrote: $OUT"
