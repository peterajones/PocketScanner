# v3.0 Localization — Spanish + French (Design)

**Date:** 2026-07-15
**Status:** Approved design, pre-implementation
**Ships as:** v3.0 (build 29)

## Goal

Reach more App Store eyeballs (and therefore sales) by localizing Pocket Scanner
into **Spanish (es)** and **French (fr)** — as a pilot. Both the App Store
listing (the discovery/sales lever) and the in-app UI are localized, shipped
together as one coherent v3.0 release. The pipeline is built so adding further
languages later is cheap, but only es + fr are in scope now.

## Decisions (locked)

- **Scope:** both App Store metadata *and* in-app UI. Metadata is drafted first
  (it is the discovery lever) but ships in the same release as the localized
  binary — no window where an es/fr listing leads into an English-only app.
- **Languages:** Spanish + French only (pilot). Prove the end-to-end pipeline
  before scaling.
- **Translation source:** Claude drafts all es/fr copy (UI strings, store
  metadata, screenshot captions). **Peter QAs both** — he speaks/reads/writes
  Spanish and reads French. No professional translators, no raw unreviewed
  machine translation.
- **Screenshots:** fully localized — translated captions re-rendered per
  language (en/es/fr sets), not reused English shots.
- **App name:** stays "Pocket Scanner" untranslated in all stores (brand).
- **No untranslated-string safety check** — overkill for a two-language pilot
  with human QA on both.
- **Release structure:** single bundled launch as v3.0 (Approach A).

## Starting state (verified 2026-07-15)

- App is 100% hardcoded English: no String Catalog, no `.strings`, no `.lproj`,
  `developmentRegion = en`, `knownRegions = (en, Base)`.
- Already primed: `SWIFT_EMIT_LOC_STRINGS = YES` and
  `STRING_CATALOG_GENERATE_SYMBOLS = YES` in both app build configs.
- ~82 Swift files, ~200 user-facing string literals, almost all written as
  SwiftUI `Text("literal")` (auto-adopts `LocalizedStringKey`).
- **Zero** existing localization API usage (`String(localized:)`,
  `NSLocalizedString`, `LocalizedStringResource`, `LocalizedStringKey`).

## Components

### 1. In-app localization

**Catalog:** Add `Localizable.xcstrings` (String Catalog) to the app target,
plus `InfoPlist.xcstrings` for permission-prompt strings. Add es + fr as
localizations. Build once to auto-harvest all `Text("literal")` keys, then fill
es/fr values.

**Auto-extracted (~200):** the `Text("literal")`, `Label("…")`,
`Button("…")`, `.navigationTitle("…")`, `.alert("…")` cases. No code change —
the catalog harvests them on build.

**Manual (model-derived strings that will NOT auto-extract):** these are plain
`String`s produced in non-View model code and rendered via `Text(variable)`
(the verbatim initializer, which does not localize). Convert to
`LocalizedStringResource` (or wrap at the display site with `String(localized:)`):
- Scan-filter display names (`f.displayName`)
- Sort-key titles (`key.title`, `SortMenu`)
- Tips content (`tip.title` / `tip.body`, `Tip.swift` / `TipsView`)
- The alert model strings (`alert.title`, `alert.message`, `action.title` in
  `DocumentScannerApp.swift`)

**Info.plist:** camera + FaceID usage descriptions → `InfoPlist.xcstrings`.

**Plurals:** audit for count-bearing strings (page counts, the find-bar `n/m`
counter). Express any as plural variations in the catalog using correct es/fr
plural rules (both languages: one/other).

**Explicitly NOT localized (must stay verbatim / user data):**
- User document, folder, and signature names (`tree.main.name`, `group.folder.name`,
  `sub.name`, signature `name`)
- Version string (`versionString`), auth-error text (`authError`) — dynamic/system
- The "Pocket Scanner" brand name
- Date-stamp format *patterns* — the patterns stay; month/day names auto-localize
  via `DateFormatter` locale at render time

**Text expansion:** es/fr run ~15–30% longer than English. After translation,
re-check for clipping/truncation in the tightest layouts — especially the viewer
bottom toolbar (recently tightened in v2.9), buttons, and sheet labels.

### 2. App Store metadata

Source-controlled under `marketing/app-store-metadata/{en,es,fr}/`, one plain-text
file per field, drafted by Claude and pasted into ASC. Gives every future
release's translations a home + history.

- **Keep (all locales):** app name "Pocket Scanner".
- **Localize per locale:** subtitle (≤30 chars), **keywords (≤100 chars)** —
  real in-market search terms, not literal translations (biggest ASO win),
  description, promotional text, What's New.
- English files capture current live copy so all three locales are versioned
  together going forward.

### 3. Localized screenshots

- Extract the 8 current English captions into a **manifest** per language:
  `marketing/app-preview/captions/{en,es,fr}.tsv`
  (columns: shot#, line1, line2, top_px, optional font-size override).
- Add **`caption-all.sh`** — reads a language's manifest and renders the whole
  set in one command (repeatable each release).
- Extend **`caption.sh`** with an optional font-size override argument so longer
  es/fr lines don't overflow 1290px (current 78/66px is hardcoded).
- Output → `marketing/app-preview/v3.0/Stills-{es,fr}/` (English set carried/renamed
  as the `en` baseline).

### 4. Translation workflow

- Claude drafts es/fr for **all** surfaces: catalog values, store metadata,
  screenshot captions.
- **Peter QAs both** languages: on-device UI pass in each locale + read-through
  of store copy. Claude flags any phrase it is <90% confident on for extra
  scrutiny.
- Source of truth: `.xcstrings` catalog for UI; repo text files for
  metadata + captions.

### 5. Testing & verification

- Run the app forced into es and fr (scheme `-AppleLanguages (es)` / `(fr)`),
  screenshot key screens, eyeball overflow/clipping.
- Existing 225-test suite must stay green (logic unchanged by localization).
- Manual on-device Release/iCloud smoke before submit (storage-touching
  discipline still applies to any release).

### 6. Release mechanics (v3.0 / build 29)

- Bump `MARKETING_VERSION` 2.9 → 3.0 and `CURRENT_PROJECT_VERSION` 28 → 29 in
  both app build configs (Debug/.dev + Release/prod); leave test targets at 1/1.0.
  (Lesson from v2.9: the version bump is a *separate* step from the feature work —
  verify before archiving.)
- ASC: add Spanish + French as App Store localizations; paste localized metadata;
  upload es/fr screenshot sets to the **6.9" slot** (not 6.5" — the v2.9 trap);
  localized What's New per locale.
- On-device Release/iCloud smoke, then submit as one v3.0 review.

## Scope guardrails (YAGNI)

- Only es + fr this round. Pipeline is built to scale but no additional languages
  are added now.
- No fastlane / CI localization automation — manual ASC matches the existing
  solo workflow; we only source-control the text.
- No untranslated-string lint/safety check.

## Out of scope / deferred

- Additional languages (German, Japanese, etc.) — revisit after the pilot proves
  the pipeline and the es/fr install numbers justify the ongoing per-release
  maintenance.
- Localizing user-generated content or date-format pattern *choices*.
