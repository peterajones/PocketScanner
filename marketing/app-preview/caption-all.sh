#!/usr/bin/env bash
# Render a whole language's captioned App Store screenshots in one command.
#
# Reads captions/<lang>.tsv and, for each row, composites the caption onto the
# matching uncaptioned base capture via caption.sh, writing the final still.
#
# Layout (all under this script's dir):
#   captions/<lang>.tsv          caption manifest (shot, line1, line2, top, fs1, fs2)
#   v3.0/Base-<lang>/<shot>.png   uncaptioned 1290x2796 capture, app in <lang>
#   v3.0/Stills-<lang>/<shot>.png final captioned still (output)
#
# Usage:  caption-all.sh <lang>        e.g.  caption-all.sh es
set -euo pipefail
LANG_CODE="${1:?usage: caption-all.sh <lang>}"
DIR="$(cd "$(dirname "$0")" && pwd)"
MANIFEST="$DIR/captions/$LANG_CODE.tsv"
BASE="$DIR/v3.0/Base-$LANG_CODE"
OUT="$DIR/v3.0/Stills-$LANG_CODE"

[ -f "$MANIFEST" ] || { echo "no manifest: $MANIFEST" >&2; exit 1; }
mkdir -p "$OUT"

missing=0
while IFS=$'\t' read -r shot line1 line2 top fs1 fs2; do
  [ "$shot" = "shot" ] && continue          # header row
  [ -z "${shot:-}" ] && continue            # blank line
  src="$BASE/$shot.png"
  if [ ! -f "$src" ]; then
    echo "!! missing base capture: $src" >&2
    missing=$((missing + 1))
    continue
  fi
  "$DIR/caption.sh" "$src" "$OUT/$shot.png" "$line1" "$line2" "$top" "$fs1" "$fs2"
done < "$MANIFEST"

[ "$missing" -eq 0 ] && echo "done: $OUT" || echo "done with $missing missing base(s): $OUT"
