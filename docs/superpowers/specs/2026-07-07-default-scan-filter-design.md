# Default scan filter — design (v2.6 / build 25)

## Summary

Let the user pick a **default scan filter** so new scans stop defaulting to washed-out
Color. A single Settings preference; new captures start from it (still overridable
per-scan). Uses the existing presets — no new filter, no sliders. Shipped default stays
**Color** (pure opt-in, zero behavior change for existing users). Small, inline feature.

## Motivation

Scans default to `Color` (`ImageFilter.none`) in `NameDocumentSheet`, which reads
washed-out; the user had to change the filter every scan (racy vs auto-capture). Editing
filters already exist (`PageEditorView`). The only gap: nothing remembers a default.
Bonus: a Greyscale/B&W default also shrinks files (drops color channels), compounding the
v2.5 file-size win.

## Design

- **Preference:** `@AppStorage("defaultScanFilter")` storing an `ImageFilter` raw value
  (String). Shipped default `ImageFilter.none.rawValue` (= Color). No migration.
- **Settings UI:** a **"Default Scan Filter"** picker in `SettingsView`, built from
  `ImageFilter.allCases` + `displayName` (Color / Greyscale / B&W / Photo).
- **Scan flow:** `NameDocumentSheet` initializes its `@State filter` from the preference
  (in `.onAppear`, fallback `.none`) instead of the hardcoded `.none`. Everything
  downstream is unchanged — the live preview, the in-sheet override picker, and
  `ScanPipeline.assemble` all take whatever `filter` is.
- **Page editor:** untouched — stays `.none` / apply-on-demand (avoids re-filtering an
  already-filtered page).

## Non-goals

- No new "Document"/flat-field preset (revisit later only if B&W-as-default proves
  insufficient).
- No change to the shipped default behavior (stays Color).
- No filter default in the editor.

## Components

- Modify: `SettingsView.swift` (add the picker + `@AppStorage`).
- Modify: `Capture/NameDocumentSheet.swift` (seed `filter` from the preference on appear).
- (`ImageFilter` already `String, CaseIterable, Identifiable` with `displayName` — reuse.)

## Testing

- Tiny round-trip: `ImageFilter(rawValue:)` ↔ raw value for all cases (guards the AppStorage
  encoding).
- Build + on-device smoke: set B&W in Settings → next scan's sheet starts on B&W; per-scan
  override still works; existing default (unset) → Color.

## Rollout

Ships as **v2.6 (25)**. Update `FutureEnhancements.md` (mark B shipped; A remains). Bump
2.5/24 → 2.6/25 at archive.
