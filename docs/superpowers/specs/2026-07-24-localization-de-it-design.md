# v3.2 Localization — German + Italian

**Date:** 2026-07-24
**Status:** Design approved; ready for implementation plan
**Predecessors:** v3.0 (es-ES + fr-FR, full in-app + metadata) · v3.1 (es-MX + fr-CA, metadata-only variants)

## Goal

Add **German (`de`)** and **Italian (`it`)** as fully localized languages — in-app UI + App Store listing — to reach two more markets. German is the priority market (over-indexes on people paying for utility apps). One bundled release: **v3.2 (build 31)**.

## Scope

Full in-app localization for both languages, mirroring the v3.0 es/fr launch (NOT the v3.1 metadata-only variant approach — a German/Italian store listing that opens into an English app is the unfinished look we avoid).

- **In-app UI** — add `de` + `it` to the String Catalog (~150 keys, already primed from es/fr).
- **App Store metadata** — de + it subtitle, keywords, description, promotional text, what's-new.
- **Localized screenshots** — 8-shot captioned set per language.
- **One bundled submission** — both languages ship together in v3.2.

### Explicitly out of scope / deferred
- **Localized App Preview videos** — deferred again (highest cost, lowest marginal value; the English-UI video was accepted through es/fr/es-MX/fr-CA). Reuse the English App Preview video across all wells.
- **Regional variants** (de-AT, it-CH, etc.) — not now.

## Quality assurance — AI-only, accepted risk

Peter is fluent in Spanish and reads French, but does **not** read German or Italian, so there is **no native human review** before ship. This is an accepted, deliberate trade-off ("a $4.99 app, not a flawless international product"). Risk is mitigated, not eliminated:

1. Claude drafts `de` + `it` for all in-app keys **and** metadata.
2. **Back-translation check:** Claude independently translates the de/it back to English and diffs against the source to catch meaning drift and errors.
3. Claude hands Peter a **short flagged list** — only genuinely low-confidence strings (idiom, Italian gender agreement, questionable German compounds, register slips) — not all 150.
4. Peter does the **German overflow visual pass** (see below) and a quick Italian one.

**Why the risk is relatively small:** the in-app strings are mostly short *functional* labels (Scan, Sign, Date, Settings, folder actions), which AI translates reliably and back-translation verifies well. The higher idiom/tone risk lives in the marketing **description** — and that is a store-listing field editable anytime without an app release, not shipped inside the binary.

## In-app localization

The String Catalog groundwork from es/fr carries over; this is largely "add two more columns."

- **~150 UI keys** in `Localizable.xcstrings` — add `de` + `it` values.
- **Model-derived strings** (image-filter names, sort keys, `Tip.title/body`, alert copy) already use `String(localized:)` from es/fr — no new plumbing, just translations.
- **Plurals** (`%lld selected`, `%lld pages`) — German and Italian are both simple two-form (like English); add their plural rules.
- **`InfoPlist.xcstrings`** (camera / Face ID usage strings) — add `de` + `it`.
- **Harvest gotcha:** command-line `xcodebuild` does not write harvested strings back into `.xcstrings`; only an Xcode IDE build (`⌘B`) does. Only relevant if new keys appear — likely none this time.

### Register
Match Apple's own iOS platform conventions:
- **German → informal "du"** (Apple moved German to *du* years ago; reads modern, not stuffy).
- **Italian → informal "tu"**.

Consistent with the friendly indie tone and the informal *tú* used for Spanish.

### Terminology anchoring
Pick Apple's platform-standard terms up front (the de/it analogue of the fr *scanner→numériser* lesson):
- "scan" verb → German **scannen**, Italian **scansiona / scansione**
- Settings → **Einstellungen** / **Impostazioni**
- and similar for folders, search, share, etc.

### German overflow — the one thing needing Peter's eyes
German compound words run long ("Einstellungen", "Dokumente durchsuchen"), stressing button/label layout and screenshot captions harder than es/fr did. This is the main **implementation-side** risk, separate from translation quality. Peter can catch it **without reading German**: truncation shows as clipped text or "…" regardless of language. Workflow: after translations load, Peter runs the app in forced-German locale and scans each screen for anything visually cut off; Claude shortens the offending strings. Quick repeat in Italian (far less likely to overflow).

## App Store metadata

Per language: subtitle, keywords, description, promotional_text, whats_new — each within ASC limits.
- **German subtitle is the tight constraint** (30-char cap vs German length) — watch it explicitly.
- Keywords: researched in-market German/Italian search terms (search-driven, not purity-driven).
- Files live under `marketing/app-store-metadata/{de,it}/` following the existing per-locale layout.

## Screenshots

- Peter re-shoots the **8 base captures per language** on the simulator in forced-locale (German, then Italian), same process as es/fr. Shot #4 (live-scan frame) reuses the shared uncaptioned `v2.8/Stills/2a. Scanning a Document.png`.
- The batch renderer was retired after v3.1 but is **restorable from git history**. Restore `render-captions.py` + add `captions/de.tsv` and `captions/it.tsv` manifests (cleaner than hand-running `caption.sh` 16 times).
- Output lands in a fresh **`marketing/app-preview/v3.2/Stills/{de,it}/`** (flat `1.png`–`8.png`), matching the versioning established in the v3.1 cleanup.
- Caption font sizes (`fs1/fs2`) may need shrinking for longer German captions to avoid overflow past 1290px width.

## Testing

- Unit suite stays green (225 tests).
- Forced-locale de/it smoke passes: overflow scan + basic navigation.
- No storage/sync changes, so no heavy on-device Release/iCloud pass required.

## Release mechanics

- Bump **`MARKETING_VERSION` 3.1 → 3.2** and **`CURRENT_PROJECT_VERSION` 31** (app target only; test targets stay 1.0/1). Verify the pbxproj bump *before* archiving (recurring lesson).
- Archive (Release, Any iOS Device arm64), upload.
- In ASC: **add German + Italian localizations** to the v3.2 version; do **not** change the primary language. Paste the de/it metadata, upload the de/it captioned screenshots to the 6.9″ slot, reuse the English App Preview video across wells.
- Watch the **language-selector-reset footgun** (the selector reverts on every page navigation — confirm the language indicator on each page before editing).

## Risks

| Risk | Mitigation |
|------|------------|
| Unreviewed translation errors (no native QA) | Back-translation diff + low-confidence flagging; functional-string bias keeps risk low; description editable post-ship |
| German UI/caption overflow | Forced-locale visual pass (language-agnostic); shorten strings / reduce caption font size |
| Wrong register/tone | Anchor to Apple's du/tu conventions up front |
| German subtitle exceeds 30 chars | Watch explicitly during metadata drafting |
| ASC language-selector reset | Verify language indicator per page |

## Success criteria

- App fully renders in German and Italian with no truncation on any screen.
- de/it App Store listings complete, within limits, and live with the v3.2 release.
- Unit suite green; no regressions in existing locales.
