#!/usr/bin/env bash
# Populate a booted simulator with the canonical demo library, then relaunch the app
# in a chosen language — the setup step for capturing App Store screenshots.
#
# Usage:  ./marketing/app-preview/seed-simulator.sh [lang]
#           lang  en (default) | es | fr | de | it
#
# Why this instead of -SeedDemoData: that flag is DEBUG-only, and screenshots must come
# from a RELEASE build so the Settings ▸ Developer row is hidden (demo-library-recipe.md
# §A.2). Copying the library in works for either configuration.
#
# Why NOT the real iCloud container: a simulator that has never been signed into iCloud
# falls back to the app's own local Documents directory, so no real scans can appear in
# a screenshot (§A.5). That also keeps us out of ~/Library/Mobile Documents/, which is
# TCC-protected.
#
# PREREQUISITES
#   * A simulator is booted, and the RELEASE build has been installed and launched once
#     (the data container does not exist until first launch).
#   * On that first launch, tap "Try Anyway" on the iCloud onboarding screen — without
#     iCloud the app uses the local store, which is what this seeds.
set -euo pipefail

BUNDLE_ID="ca.peter-jones.DocumentScanner"          # Release. Debug is …DocumentScanner.dev
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SIGNATURES="$REPO_ROOT/marketing/app-preview/demo-signatures/signatures.dat"
LANG_CODE="${1:-en}"

# Every non-English language has its own library with translated FOLDER and FILE names.
# Seeding the English tree under a translated UI gives German folders called "Personal /
# Receipts / Work", which is not what any release shipped.
#
# The PDFs' CONTENTS are English in all of them — only names are translated. That is
# deliberate and matches what shipped; it is also why the search shot uses a proper noun
# (Northgate) rather than a word that would need translating.
#
# ES and FR were rebuilt 2026-08-31. The originals used at the v3.0 shoot no longer
# exist: marketing/translations/* is gitignored, so nothing under it was ever committed.
# The rebuild also corrects a mistranslation that has been live since v3.0 — the
# Receipts folder shipped as "Recetas" / "Recettes", which mean RECIPES. It is now
# "Recibos" / "Reçus", matching the app's own keyword fields, and matching DE/IT which
# had it right ("Belege", "Scontrini").
case "$LANG_CODE" in
  en) LOCALE="en_US"; LIBRARY="$REPO_ROOT/marketing/app-preview/PocketScannerDemoLibrary" ;;
  es) LOCALE="es_ES"; LIBRARY="$REPO_ROOT/marketing/translations/Document Scanner ES" ;;
  fr) LOCALE="fr_FR"; LIBRARY="$REPO_ROOT/marketing/translations/Document Scanner FR" ;;
  de) LOCALE="de_DE"; LIBRARY="$REPO_ROOT/marketing/translations/Document Scanner DE" ;;
  it) LOCALE="it_IT"; LIBRARY="$REPO_ROOT/marketing/translations/Document Scanner IT" ;;
  *)  echo "error: unknown language '$LANG_CODE' (expected en|es|fr|de|it)" >&2; exit 1 ;;
esac
[ -d "$LIBRARY" ] || {
  echo "error: library not found: $LIBRARY" >&2
  echo "       marketing/translations/* is gitignored — these libraries live only on disk." >&2
  exit 1
}

DEVICE="$(xcrun simctl list devices booted 2>/dev/null | grep -Eo '\([0-9A-F-]{36}\)' | head -1 | tr -d '()')"
[ -n "$DEVICE" ] || { echo "error: no booted simulator. Boot one and run the app once." >&2; exit 1; }

CONTAINER="$(xcrun simctl get_app_container "$DEVICE" "$BUNDLE_ID" data 2>/dev/null || true)"
[ -n "$CONTAINER" ] || {
  echo "error: $BUNDLE_ID is not installed on the booted simulator." >&2
  echo "       Build and run the RELEASE configuration to it first." >&2
  exit 1
}

DOCS="$CONTAINER/Documents"
SIGS="$CONTAINER/Signatures"

echo "device:    $DEVICE"
echo "container: $CONTAINER"
echo "library:   $(basename "$LIBRARY")"

# Start clean so a re-run cannot leave a stale folder in shot — the whole point is a
# library that matches the recipe exactly, every time.
rm -rf "$DOCS" "$SIGS"
mkdir -p "$DOCS" "$SIGS"

# --exclude .DS_Store: Finder litters the repo copy, and the app would list them.
rsync -a --exclude '.DS_Store' "$LIBRARY"/ "$DOCS"/
cp "$SIGNATURES" "$SIGS/signatures.dat"

echo
echo "seeded:"
find "$DOCS" -name '*.pdf' | sed "s|$DOCS/|  |" | sort
echo "  + 3 named signatures"

xcrun simctl terminate "$DEVICE" "$BUNDLE_ID" >/dev/null 2>&1 || true
# batteryState discharging, not charged: "charged" draws a charging bolt in the status bar.
xcrun simctl status_bar "$DEVICE" override --time "9:41" --batteryLevel 100 --batteryState discharging --cellularBars 4 --wifiBars 3 >/dev/null
xcrun simctl launch "$DEVICE" "$BUNDLE_ID" -AppleLanguages "($LANG_CODE)" -AppleLocale "$LOCALE" >/dev/null

# Derived, not hardcoded: this used to name v3.4 and would have gone stale the moment a
# release shipped new screenshots.
VERSION="$(awk -F' = ' '/MARKETING_VERSION/ {gsub(/;/,"",$2); print $2; exit}' \
  "$REPO_ROOT/DocumentScanner/DocumentScanner.xcodeproj/project.pbxproj")"

echo
echo "launched in $LANG_CODE. Capture with:"
echo "  xcrun simctl io booted screenshot marketing/app-preview/v${VERSION}/Base/$LANG_CODE/<shot>.png"
