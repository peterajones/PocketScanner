#!/bin/bash
# Render the invented demo props (ID, prescriptions, receipt, tax organizer) to PNG.
# Every name, number and organization on them is made up; phone numbers use the
# reserved 555-01xx range.
#
#   out/raw/<name>.png  the bare page
#   out/<name>.png      the page centred on a dark background with a border, sized for
#                       a Mac screen: open it full-screen and scan it with the phone.
#
# Usage: ./render.sh
set -euo pipefail
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
DIR="$(cd "$(dirname "$0")" && pwd)"
STAGE_W=2560 STAGE_H=1600
mkdir -p "$DIR/out/raw"

shoot() { # url width height out [scale]
  "$CHROME" --headless=new --force-device-scale-factor="${5:-1}" --disable-gpu --hide-scrollbars --default-background-color=00000000 --window-size="$2,$3" \
    --screenshot="$4" "$1" >/dev/null 2>&1
}

render() { # name width height [corner-radius]
  shoot "file://$DIR/$1.html" "$2" "$3" "$DIR/out/raw/$1.png" 2  # 2x, so text stays sharp when staged
  shoot "file://$DIR/stage.html?src=out/raw/$1.png&r=${4:-}" "$STAGE_W" "$STAGE_H" "$DIR/out/$1.png"
  echo "$DIR/out/$1.png"
}

render id-card 1012 638 72
render eye-prescription 1275 825
render prescription 850 1100
render receipt 600 1020
render tax-form 1275 1650
render lab-results 1275 1650
render agreement 816 1056
