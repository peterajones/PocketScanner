#!/usr/bin/env bash
#
# Verify the identity baked into a BUILT archive before uploading it to App
# Store Connect. This reads the shipping artifact itself, never the project
# file, because the project file is exactly what can lie: Xcode 27's Info.plist
# migration silently flattened Release's display name to the Debug value
# ("Pocket Scanner Dev"), and a green build plus 322 passing tests did not
# catch it. Only the built plist did.
#
# Usage:  ./scripts/verify-release-name.sh                      (newest archive)
#         ./scripts/verify-release-name.sh path/to/Foo.xcarchive
#
set -euo pipefail

EXPECTED_NAME="Pocket Scanner"
EXPECTED_BUNDLE_ID="ca.peter-jones.DocumentScanner"
APP_NAME="DocumentScanner.app"

# Newest archive, unless one was named explicitly on the command line.
# `|| true` so a zero-match glob doesn't trip pipefail/set -e before we can
# print a useful error.
pick_archive() {
  local path
  path="$(ls -dt "$HOME/Library/Developer/Xcode/Archives/"*/*.xcarchive 2>/dev/null | head -1 || true)"
  echo "$path"
}

ARCHIVE="${1:-$(pick_archive)}"
if [ -z "$ARCHIVE" ] || [ ! -d "$ARCHIVE" ]; then
  echo "error: no .xcarchive found. Product > Archive first, or pass a path." >&2
  exit 1
fi

PLIST="$ARCHIVE/Products/Applications/$APP_NAME/Info.plist"
if [ ! -f "$PLIST" ]; then
  echo "error: no $APP_NAME/Info.plist inside $ARCHIVE" >&2
  exit 1
fi

read_key() {
  /usr/libexec/PlistBuddy -c "Print :$1" "$PLIST" 2>/dev/null || echo "<missing>"
}

NAME="$(read_key CFBundleDisplayName)"
BUNDLE_ID="$(read_key CFBundleIdentifier)"
VERSION="$(read_key CFBundleShortVersionString)"
BUILD="$(read_key CFBundleVersion)"

echo "Archive: $(basename "$ARCHIVE")"
echo "Version: $VERSION ($BUILD)"
echo ""

STATUS=0

check() {
  local label="$1" actual="$2" expected="$3"
  if [ "$actual" = "$expected" ]; then
    printf '  OK    %-22s %s\n' "$label" "$actual"
  else
    printf '  WRONG %-22s %s   (expected: %s)\n' "$label" "$actual" "$expected" >&2
    STATUS=1
  fi
}

check "CFBundleDisplayName" "$NAME" "$EXPECTED_NAME"
check "CFBundleIdentifier" "$BUNDLE_ID" "$EXPECTED_BUNDLE_ID"

echo ""
echo "──────────────────────────────────────────"
if [ "$STATUS" -eq 0 ]; then
  echo "  PASS - safe to upload"
else
  echo "  FAIL - do NOT upload this archive"
fi
echo "──────────────────────────────────────────"
exit "$STATUS"
