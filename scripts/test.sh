#!/usr/bin/env bash
#
# Run the full Pocket Scanner unit-test suite (DocumentScannerTests) from the
# command line. Unlike Xcode's Product > Test, this always runs the WHOLE target
# — it is immune to the Test navigator's selection state (the "1 test" trap).
#
# Usage:  ./scripts/test.sh        (run from anywhere in the repo)
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$REPO_ROOT/DocumentScanner/DocumentScanner.xcodeproj"
SCHEME="DocumentScanner"
TEST_TARGET="DocumentScannerTests"

# Prefer an already-booted simulator; else fall back to the newest available iPhone.
pick_simulator() {
  local id
  id="$(xcrun simctl list devices booted 2>/dev/null \
        | grep -Eo '\([0-9A-F-]{36}\)' | head -1 | tr -d '()')"
  if [ -z "$id" ]; then
    id="$(xcrun simctl list devices available 2>/dev/null \
          | grep -E 'iPhone' | grep -Eo '\([0-9A-F-]{36}\)' | tail -1 | tr -d '()')"
  fi
  echo "$id"
}

DEVICE_ID="$(pick_simulator)"
if [ -z "$DEVICE_ID" ]; then
  echo "error: no iOS Simulator found. Add one via Xcode > Settings > Components." >&2
  exit 1
fi

echo "Running $TEST_TARGET on simulator $DEVICE_ID …"
LOG="$(mktemp)"

set +e
xcodebuild test \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,id=$DEVICE_ID" \
  -only-testing:"$TEST_TARGET" \
  2>&1 | tee "$LOG"
STATUS=${PIPESTATUS[0]}
set -e

# `|| true` so a zero-match grep (e.g. no failures) doesn't trip pipefail/set -e.
PASSED="$( { grep -Eo "Test case '[^']+' passed" "$LOG" || true; } | sort -u | wc -l | tr -d ' ')"
FAILED="$( { grep -Eo "Test case '[^']+' failed" "$LOG" || true; } | sort -u | wc -l | tr -d ' ')"
rm -f "$LOG"

echo ""
echo "──────────────────────────────────────────"
echo "  Passed: $PASSED   Failed: $FAILED"
echo "──────────────────────────────────────────"
exit "$STATUS"
