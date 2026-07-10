#!/usr/bin/env bash
# Composite a 2-line App Store caption onto a framed 1290x2796 screenshot.
# Navy (#14315C) SF Pro Display — matches the demo docs' letterhead.
#
# Usage:  caption.sh <input.png> <output.png> "<line 1>" "<line 2>" [top_px]
#   top_px  vertical position of the caption band (default 430 — the viewer's
#           grey band under the nav bar). Adjust per shot if the layout differs.
#
# Requires Google Chrome (headless renderer). No Krita needed.
set -euo pipefail

CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
IN="$1"; OUT="$2"; L1="$3"; L2="$4"; TOP="${5:-430}"

ABS="$(cd "$(dirname "$IN")" && pwd)/$(basename "$IN")"
URL="file://$(python3 -c 'import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))' "$ABS")"

HTML="$(mktemp /tmp/caption.XXXXXX.html)"
cat > "$HTML" <<EOF
<!doctype html><html><head><meta charset="utf-8"><style>
 html,body{margin:0;padding:0;}
 .stage{position:relative;width:1290px;height:2796px;}
 .stage img{width:1290px;height:2796px;display:block;}
 .cap{position:absolute;top:${TOP}px;left:0;width:1290px;text-align:center;
      font-family:-apple-system,"SF Pro Display","Helvetica Neue",sans-serif;
      color:#14315C;line-height:1.06;letter-spacing:-0.01em;}
 .cap .l1{font-weight:700;font-size:78px;}
 .cap .l2{font-weight:600;font-size:66px;}
</style></head><body>
 <div class="stage"><img src="${URL}">
 <div class="cap"><div class="l1">${L1}</div><div class="l2">${L2}</div></div></div>
</body></html>
EOF

"$CHROME" --headless=new --disable-gpu --hide-scrollbars --window-size=1290,2796 \
  --screenshot="$OUT" "file://$HTML" >/dev/null 2>&1
rm -f "$HTML"
echo "wrote: $OUT"
