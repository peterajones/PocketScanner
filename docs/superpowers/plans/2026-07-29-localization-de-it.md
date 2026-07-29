# v3.2 Localization — German + Italian Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship Pocket Scanner v3.2 (build 31) with German (`de`) and Italian (`it`) as fully localized languages — in-app UI, App Store metadata, and captioned screenshots — mirroring the v3.0 es/fr launch.

**Architecture:** No new localization machinery is needed. The v3.0 work already converted every user-visible string to either a `Text("literal")` (auto-harvested into `Localizable.xcstrings`) or a `String(localized:)` call for model-derived strings. This release is therefore "add two more columns" to two String Catalogs, plus one project-configuration change (`knownRegions`), plus marketing assets. The only production-code changes expected are *shortening* German strings that overflow the layout.

**Tech Stack:** Xcode String Catalogs (`.xcstrings`, JSON on disk), Swift/SwiftUI, Python 3 (catalog edit + verification scripts), `caption.sh` (headless-Chrome screenshot compositor), `xcodebuild` via `scripts/test.sh`.

**Spec:** `docs/superpowers/specs/2026-07-24-localization-de-it-design.md`
**Predecessor plan (same shape, read it for context):** `docs/superpowers/plans/2026-07-15-localization-es-fr.md`

---

## Global Constraints

These apply to every task. Do not restate them per task; they are always in force.

- **Register — German: informal `du`. Italian: informal `tu`.** Never `Sie` / `Lei`. This matches Apple's own iOS conventions and the informal `tú` already used in Spanish.
- **The app name "Pocket Scanner" is a brand and is NEVER translated**, in any language, in-app or in metadata.
- **Source language stays `en`.** `developmentRegion = en` in the pbxproj must not change. In App Store Connect, English remains the PRIMARY language — do **not** change the primary language (that would demand screenshots for every past version).
- **Version for this release: `MARKETING_VERSION = 3.2`, `CURRENT_PROJECT_VERSION = 31`.** App target only — the `DocumentScannerTests` and `DocumentScannerUITests` targets stay at `1.0` / `1`.
- **Test command is `./scripts/test.sh`** run from the repo root. Never use Xcode's Product ▸ Test to judge suite health — the Test navigator's selection state can silently scope a run to a single test. `scripts/test.sh` always runs the whole target.
- **App Store Connect character limits:** subtitle ≤ **30**, promotional text ≤ **170**, keywords ≤ **100** (comma-separated, no spaces after commas), What's New ≤ **4000**, description ≤ **4000**. The 170 limit on promotional text has bitten this project twice (es/fr in v3.0, fr-CA in v3.1) — verify programmatically, never by eye.
- **Commit, do not push.** Peter pushes. Every task ends with a local `git commit` only.
- **Do not run `git push`, `git reset --hard`, or delete branches.** Each of those needs Peter's separate explicit go-ahead.

### Terminology glossary (anchor decisions)

Pick these once and apply them consistently across in-app strings, metadata, and screenshot captions. This is the de/it analogue of the fr `scanner`→`numériser` lesson from v3.1.

| English | German (`de`) | Italian (`it`) |
|---|---|---|
| scan (verb) | scannen | scansionare |
| scan (noun, a scanned doc) | Scan | scansione |
| Scan Document | Dokument scannen | Scansiona documento |
| Settings | Einstellungen | Impostazioni |
| Folder / Sub-folder | Ordner / Unterordner | Cartella / Sottocartella |
| Search (verb) | suchen | cercare |
| Sign (verb) | unterschreiben | firmare |
| Signature | Unterschrift | Firma |
| Date (noun) | Datum | Data |
| Save | Sichern | Salva |
| Delete | Löschen | Elimina |
| Remove | Entfernen | Rimuovi |
| Move | Bewegen | Sposta |
| Rename | Umbenennen | Rinomina |
| Cancel | Abbrechen | Annulla |
| Done | Fertig | Fine |
| Merge | Zusammenführen | Unisci |
| Import | Importieren | Importa |
| Share | Teilen | Condividi |

**Save vs Delete vs Remove:** German uses `Sichern` for Save (Apple's iOS convention) and must keep `Löschen` (Delete, destructive/permanent) distinct from `Entfernen` (Remove, e.g. removing a placed signature mark). Italian likewise keeps `Elimina` distinct from `Rimuovi`. This exact distinction caused QA fixes in v3.0 for both es and fr — get it right up front.

**Task 2 Step 1 verifies these anchors empirically against a German/Italian iOS simulator** rather than trusting them from memory. If the simulator contradicts a row above, the simulator wins — update this table and note the change in the commit message.

---

## File Structure

**Modified:**
- `DocumentScanner/DocumentScanner.xcodeproj/project.pbxproj` — `knownRegions` gains `de`, `it`; later, `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`.
- `DocumentScanner/DocumentScanner/Localizable.xcstrings` — 150 keys gain `de` + `it` localizations.
- `DocumentScanner/DocumentScanner/InfoPlist.xcstrings` — `NSCameraUsageDescription` + `NSFaceIDUsageDescription` gain `de` + `it`.
- `DocumentScanner/DocumentScannerTests/DateStampFormatTests.swift` — de/it long-date coverage.
- Various `.swift` files — German string shortening only, and only where Task 7 finds overflow.
- `marketing/app-store-metadata/{en,es,es-MX,fr,fr-CA}/whats_new.txt` — refreshed for v3.2.
- `docs/FutureEnhancements.md`, `marketing/app-preview/demo-library-recipe.md` — status updates.

**Created:**
- `scripts/verify-localization.py` — catalog completeness checker (the "test" for translation tasks).
- `scripts/verify-metadata.py` — App Store metadata character-limit checker.
- `marketing/app-store-metadata/{de,it}/{subtitle,keywords,description,promotional_text,whats_new}.txt`
- `marketing/app-preview/render-captions.py` — restored from git history, retargeted at v3.2.
- `marketing/app-preview/captions/{de,it}.tsv`
- `marketing/app-preview/v3.2/Stills/{de,it}/1.png … 8.png`
- `docs/superpowers/qa/2026-07-29-de-it-back-translation.md` — QA record + Peter's flag list.

**A note on translation content:** this plan specifies the *method*, the *glossary*, the *verification*, and worked examples — it deliberately does not inline all 300 translated strings. Generating those is the implementation work of Tasks 2 and 3, gated by `scripts/verify-localization.py` (completeness) and Task 6 (back-translation accuracy). That is not a placeholder; it is the correct division between plan and execution for generative content.

---

## Current State (verified 2026-07-29)

Do not re-derive these; they were checked against the working tree.

- `Localizable.xcstrings`: **150 keys**, `sourceLanguage: en`. Coverage: `es` 150, `fr` 150, `en` 5 (source-language entries are implicit — an English-only key carries no `en` localization).
- **Plural keys (exactly two):** `%lld pages`, `%lld selected`. Both use `variations.plural` with `one` / `other`. German and Italian are both two-form, same shape as English.
- `InfoPlist.xcstrings`: `NSCameraUsageDescription` and `NSFaceIDUsageDescription` have en/es/fr. `CFBundleDisplayName` and `CFBundleName` are **en-only with `state: "new"`** — leave them alone; the display name is the brand.
- `project.pbxproj`: `knownRegions = (en, Base, es, fr)` at line ~205. **`de` and `it` are missing** — this is a real gap the spec did not mention.
- **The date-stamp long format is already locale-driven.** `DateStampFormat.long` (`DateStamp/DateStampFormat.swift:31-42`) sets `f.locale = locale` with `.dateStyle = .long`, so German and Italian long dates come free with no production change. `DateStampFormatTests.swift` currently pins en/es/fr only.
- Strings legitimately identical to English in existing locales: es → `' '`, `'%lld'`, `'Color'`, `'OK'`; fr → `' '`, `'%lld'`, `'Date'`, `'Format'`, `'OK'`, `'Photo'`, `'Signature'`, `'Version'`.
- Metadata locales on disk: `en`, `es`, `es-MX`, `fr`, `fr-CA` — **5 today, 7 after this release.**
- Screenshot stills layout: `marketing/app-preview/v3.0/Stills/{en,es,fr}/1.png…8.png` and `v3.1/Stills/{es-MX,fr-CA}/1.png…8.png`, all flat. The batch renderer was retired in commit `335da59`; recover it with `git show 335da59^:marketing/app-preview/render-captions.py`.

---

## Task 1: Register German and Italian as project languages

Without `de`/`it` in `knownRegions`, Xcode will not treat the new catalog columns as buildable languages, and the compiled `.lproj` resources may be silently omitted from the app bundle. This is the gate for everything else, so it ships as its own reviewable commit.

**Files:**
- Modify: `DocumentScanner/DocumentScanner.xcodeproj/project.pbxproj:205-210`

**Interfaces:**
- Consumes: nothing.
- Produces: a project that recognizes `de` and `it` as build regions. Tasks 2–4 depend on this.

- [x] **Step 1: Read the current `knownRegions` block**

```bash
grep -n -A8 "knownRegions" DocumentScanner/DocumentScanner.xcodeproj/project.pbxproj
```

Expected output — note the exact indentation is **tabs**:

```
205:			knownRegions = (
206:				en,
207:				Base,
208:				es,
209:				fr,
210:			);
```

- [x] **Step 2: Add `de` and `it`**

Use the Edit tool (not `sed` — the pbxproj is tab-indented and easy to corrupt). Replace:

```
			knownRegions = (
				en,
				Base,
				es,
				fr,
			);
```

with:

```
			knownRegions = (
				en,
				Base,
				es,
				fr,
				de,
				it,
			);
```

Keep `developmentRegion = en` on line 203 unchanged.

- [x] **Step 3: Verify the project file still parses**

```bash
plutil -lint DocumentScanner/DocumentScanner.xcodeproj/project.pbxproj
```

Expected: `... OK`

If this fails, the edit corrupted the file — `git checkout DocumentScanner/DocumentScanner.xcodeproj/project.pbxproj` and redo the edit by hand.

- [x] **Step 4: Verify Xcode agrees the regions are registered**

```bash
xcodebuild -project DocumentScanner/DocumentScanner.xcodeproj -list 2>/dev/null | head -20
grep -A8 "knownRegions" DocumentScanner/DocumentScanner.xcodeproj/project.pbxproj
```

Expected: `xcodebuild -list` completes without a parse error, and the grep shows all six regions.

- [x] **Step 5: Run the full unit suite**

```bash
./scripts/test.sh
```

Expected: PASS, with the same test count as before this task (record the number in the commit message — it is the baseline the rest of the plan is measured against). No behavior changed, so any failure here means the pbxproj edit broke the build.

- [x] **Step 6: Commit**

```bash
git add DocumentScanner/DocumentScanner.xcodeproj/project.pbxproj
git commit -m "$(cat <<'EOF'
localization: register de + it as project known regions

Adds German and Italian to knownRegions so the String Catalog columns
added in the next tasks compile into the app bundle. developmentRegion
stays en; English remains the source and the ASC primary language.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: German in-app UI translations

**Files:**
- Create: `scripts/verify-localization.py`
- Modify: `DocumentScanner/DocumentScanner/Localizable.xcstrings`

**Interfaces:**
- Consumes: `knownRegions` from Task 1.
- Produces: `scripts/verify-localization.py`, invoked as `python3 scripts/verify-localization.py [lang ...]` (defaults to all required languages), exit code 0 = pass / 1 = fail. Tasks 3 and 4 reuse it unchanged.

- [ ] **Step 1: Verify the glossary against a real German simulator**

Do not trust the glossary table from memory. Boot a German-locale simulator and read Apple's own terms:

```bash
xcrun simctl list devices available | grep iPhone | tail -3
# pick a UDID from the output, then:
xcrun simctl boot <UDID>
xcrun simctl spawn <UDID> defaults write -g AppleLanguages -array de
xcrun simctl spawn <UDID> defaults write -g AppleLocale -string de_DE
xcrun simctl shutdown <UDID> && xcrun simctl boot <UDID>
open -a Simulator
```

Open **Files** and **Notes** in the booted simulator and confirm: Settings=`Einstellungen`, Folder=`Ordner`, Move=`Bewegen`, Save=`Sichern`, Delete=`Löschen`, Done=`Fertig`, Cancel=`Abbrechen`, and the Notes scan action (`Dokumente scannen`).

If any term differs from the Global Constraints glossary, **the simulator wins**: update the glossary table in this plan file and say so in the Step 8 commit message. If the simulator is unavailable, proceed with the table as written and note in the commit message that the anchors are unverified.

- [ ] **Step 2: Write the verification script**

Create `scripts/verify-localization.py`:

```python
#!/usr/bin/env python3
"""Verify String Catalog completeness for every shipped language.

Checks, for both Localizable.xcstrings and InfoPlist.xcstrings:
  1. every key has a localization for every required language
  2. plural keys carry BOTH 'one' and 'other' variations per language
  3. no localized value is empty or whitespace-only
  4. no localized value is byte-identical to the English key unless it is
     explicitly allowlisted (catches copy-paste and untranslated leakage)

Usage:  python3 scripts/verify-localization.py [lang ...]
        (no args = check every language in REQUIRED)
Exit 0 = pass, 1 = failures found.
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CATALOGS = [
    ROOT / "DocumentScanner/DocumentScanner/Localizable.xcstrings",
    ROOT / "DocumentScanner/DocumentScanner/InfoPlist.xcstrings",
]
REQUIRED = ["es", "fr", "de", "it"]

# Keys exempt from the whole check: source-language-only bundle metadata.
EXEMPT_KEYS = {"CFBundleDisplayName", "CFBundleName"}

# Values that are legitimately identical to English, per language. Anything
# identical and NOT listed here fails — that forces a conscious decision
# rather than letting an untranslated string slip through.
IDENTICAL_OK = {
    "es": {" ", "%lld", "%@  %@", "Color", "OK"},
    "fr": {" ", "%lld", "%@  %@", "Date", "Format", "OK", "Photo",
           "Signature", "Version"},
    # Populate as the de/it translations are written (Tasks 2 and 3).
    "de": {" ", "%lld", "%@  %@", "OK"},
    "it": {" ", "%lld", "%@  %@", "OK"},
}


def check_catalog(path, languages):
    failures = []
    data = json.loads(path.read_text())
    name = path.name
    for key, entry in data["strings"].items():
        if key in EXEMPT_KEYS:
            continue
        locs = entry.get("localizations", {})
        is_plural = "variations" in json.dumps(entry)
        for lang in languages:
            loc = locs.get(lang)
            if loc is None:
                failures.append(f"{name}: [{lang}] MISSING  {key!r}")
                continue
            if is_plural:
                plural = loc.get("variations", {}).get("plural", {})
                for form in ("one", "other"):
                    unit = plural.get(form, {}).get("stringUnit", {})
                    if not unit.get("value", "").strip():
                        failures.append(
                            f"{name}: [{lang}] plural '{form}' empty  {key!r}")
                continue
            value = loc.get("stringUnit", {}).get("value", "")
            if not value.strip() and key.strip():
                failures.append(f"{name}: [{lang}] EMPTY    {key!r}")
            elif value == key and value not in IDENTICAL_OK.get(lang, set()):
                failures.append(
                    f"{name}: [{lang}] UNTRANSLATED (identical to source, not "
                    f"allowlisted)  {key!r}")
    return failures


def main():
    languages = sys.argv[1:] or REQUIRED
    unknown = [l for l in languages if l not in IDENTICAL_OK]
    if unknown:
        print(f"warning: no allowlist entry for {unknown} — identical-value "
              f"check will be strict for those languages")
    all_failures = []
    for path in CATALOGS:
        if not path.exists():
            print(f"error: missing catalog {path}")
            return 1
        all_failures += check_catalog(path, languages)
    if all_failures:
        print(f"FAIL — {len(all_failures)} problem(s):")
        for f in all_failures:
            print("  " + f)
        return 1
    print(f"PASS — {', '.join(languages)} complete across "
          f"{len(CATALOGS)} catalog(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 3: Run it to confirm it fails for German**

```bash
python3 scripts/verify-localization.py de
```

Expected: `FAIL — 152 problem(s):` (150 Localizable keys + 2 InfoPlist usage descriptions), each line reading `[de] MISSING`.

Also confirm it passes for the languages already done — this proves the script is measuring the right thing and not just failing on everything:

```bash
python3 scripts/verify-localization.py es fr
```

Expected: `PASS — es, fr complete across 2 catalog(s)`, exit 0.

Both expectations were **verified against the working tree on 2026-07-29** by running this exact script: es/fr passed, `de` produced exactly 152 failures, and `de it` together produced 304. If your numbers differ, the catalog changed — investigate before writing translations.

If the es/fr run fails, fix the script (likely the `IDENTICAL_OK` allowlist) before writing any translations.

- [ ] **Step 4: Write the German translations**

Translate all 150 keys in `Localizable.xcstrings` into German, applying the Global Constraints glossary and the `du` register. Apply them by script (a scratchpad Python file editing the catalog JSON directly) — this is how v3.0 did it, and hand-editing 150 JSON entries is error-prone.

The insertion shape for a normal key — add a `"de"` sibling alongside the existing `"es"` / `"fr"`:

```json
"Delete Folder?": {
  "localizations": {
    "de": { "stringUnit": { "state": "translated", "value": "Ordner löschen?" } },
    "es": { "stringUnit": { "state": "translated", "value": "..." } },
    "fr": { "stringUnit": { "state": "translated", "value": "..." } }
  }
}
```

The insertion shape for the two plural keys:

```json
"%lld pages": {
  "localizations": {
    "de": {
      "variations": {
        "plural": {
          "one":   { "stringUnit": { "state": "translated", "value": "%lld Seite" } },
          "other": { "stringUnit": { "state": "translated", "value": "%lld Seiten" } }
        }
      }
    }
  }
}
```

Worked examples establishing the expected register and quality bar:

| English key | German |
|---|---|
| `Scan Document` | `Dokument scannen` |
| `Save Scan` | `Scan sichern` |
| `New Sub-folder` | `Neuer Unterordner` |
| `Tap + to scan a document.` | `Tippe auf +, um ein Dokument zu scannen.` |
| `Choose a new name for this folder.` | `Wähle einen neuen Namen für diesen Ordner.` |
| `Add a signature in Settings first.` | `Füge zuerst in den Einstellungen eine Unterschrift hinzu.` |
| `Remove this mark?` | `Diese Markierung entfernen?` |
| `This folder and all documents inside it will be deleted.` | `Dieser Ordner und alle darin enthaltenen Dokumente werden gelöscht.` |
| `%lld selected` | `%lld ausgewählt` / plural `other`: `%lld ausgewählt` |
| `Unlock with Face ID` | `Mit Face ID entsperren` |

Hard rules while translating:
- Preserve **every** format specifier exactly (`%@`, `%lld`) and in an order that reads naturally in German. Never drop or reorder a specifier without also checking the call site.
- `'Pocket Scanner'` inside a sentence stays untranslated.
- `' '` (the bare space key) translates to `' '`.
- Keys that are pure format strings (`'%lld'`, `'%@  %@'`) stay identical.
- If a German value comes out identical to the English key, add it to `IDENTICAL_OK["de"]` in `scripts/verify-localization.py` **and** justify it in the commit message. Expect `Format` and `Version` to land here.

- [ ] **Step 5: Verify German completeness**

```bash
python3 scripts/verify-localization.py de
```

Expected: `PASS — de complete across 2 catalog(s)` — **except** the two `InfoPlist.xcstrings` usage descriptions, which are Task 4's job. If those two are the only failures, that is the expected state at this step:

```
FAIL — 2 problem(s):
  InfoPlist.xcstrings: [de] MISSING  'NSCameraUsageDescription'
  InfoPlist.xcstrings: [de] MISSING  'NSFaceIDUsageDescription'
```

Confirm `Localizable.xcstrings` contributes **zero** failures.

- [ ] **Step 6: Confirm the catalog is still valid JSON and counts are right**

```bash
python3 -c "
import json
d=json.load(open('DocumentScanner/DocumentScanner/Localizable.xcstrings'))
from collections import Counter
c=Counter()
for k,v in d['strings'].items():
    for l in v.get('localizations',{}): c[l]+=1
print(dict(c))
print('total keys:', len(d['strings']))
"
```

Expected: `{'es': 150, 'fr': 150, 'en': 5, 'de': 150}` and `total keys: 150`. If `total keys` is not 150, the script deleted or added a key — revert and retry.

- [ ] **Step 7: Build and run the full suite**

```bash
./scripts/test.sh
```

Expected: PASS with the same count as the Task 1 baseline. Translations don't change logic, so a failure means malformed catalog JSON broke the build.

- [ ] **Step 8: Commit**

```bash
git add DocumentScanner/DocumentScanner/Localizable.xcstrings scripts/verify-localization.py
git commit -m "$(cat <<'EOF'
localization: German (de) in-app UI translations

All 150 Localizable.xcstrings keys translated to German, informal "du"
register, anchored to Apple's iOS terminology (Einstellungen, Ordner,
Sichern, Löschen vs Entfernen). Both plural keys carry one/other forms.

Adds scripts/verify-localization.py, which fails on missing, empty, or
untranslated-but-not-allowlisted values across both catalogs. es/fr pass
it unchanged, so it measures real coverage rather than trivially passing.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Italian in-app UI translations

Same shape as Task 2. Kept separate so a reviewer can reject one language while accepting the other.

**Files:**
- Modify: `DocumentScanner/DocumentScanner/Localizable.xcstrings`
- Modify: `scripts/verify-localization.py` (only if the `IDENTICAL_OK["it"]` allowlist needs entries)

**Interfaces:**
- Consumes: `scripts/verify-localization.py` from Task 2; `knownRegions` from Task 1.
- Produces: `it` coverage in `Localizable.xcstrings`.

- [ ] **Step 1: Verify the Italian glossary against a simulator**

As in Task 2 Step 1, but with `it` / `it_IT`:

```bash
xcrun simctl spawn <UDID> defaults write -g AppleLanguages -array it
xcrun simctl spawn <UDID> defaults write -g AppleLocale -string it_IT
xcrun simctl shutdown <UDID> && xcrun simctl boot <UDID>
```

Confirm: Settings=`Impostazioni`, Folder=`Cartella`, Move=`Sposta`, Save=`Salva`, Delete=`Elimina`, Done=`Fine`, Cancel=`Annulla`. Simulator wins over the glossary table.

- [ ] **Step 2: Run the verifier to confirm it fails for Italian**

```bash
python3 scripts/verify-localization.py it
```

Expected: `FAIL — 152 problem(s):` all reading `[it] MISSING`.

- [ ] **Step 3: Write the Italian translations**

Translate all 150 keys into Italian, `tu` register, per the glossary. Same scripted-edit approach and same JSON shapes as Task 2 Step 4.

Worked examples:

| English key | Italian |
|---|---|
| `Scan Document` | `Scansiona documento` |
| `Save Scan` | `Salva scansione` |
| `New Sub-folder` | `Nuova sottocartella` |
| `Tap + to scan a document.` | `Tocca + per scansionare un documento.` |
| `Choose a new name for this folder.` | `Scegli un nuovo nome per questa cartella.` |
| `Add a signature in Settings first.` | `Aggiungi prima una firma in Impostazioni.` |
| `Remove this mark?` | `Rimuovere questo segno?` |
| `This folder and all documents inside it will be deleted.` | `Questa cartella e tutti i documenti al suo interno verranno eliminati.` |
| `%lld selected` | `%lld selezionato` / plural `other`: `%lld selezionati` |
| `Unlock with Face ID` | `Sblocca con Face ID` |

Italian-specific hard rules, in addition to Task 2's:
- **Gender and number agreement is the top accuracy risk.** Adjectives and past participles must agree with the noun they modify — and the noun is often only visible at the call site, not in the key. `%lld selected` refers to pages/documents; the `one`/`other` plural forms must agree (`selezionato` / `selezionati`).
- Articles elide before vowels (`l'originale`, `dell'ordine`) — write them correctly rather than leaving `lo`/`la`.
- Same format-specifier and brand-name rules as German.

- [ ] **Step 4: Verify Italian completeness**

```bash
python3 scripts/verify-localization.py it
```

Expected: only the two `InfoPlist.xcstrings` failures remain (Task 4). Zero failures from `Localizable.xcstrings`.

- [ ] **Step 5: Verify counts and that German did not regress**

```bash
python3 -c "
import json
d=json.load(open('DocumentScanner/DocumentScanner/Localizable.xcstrings'))
from collections import Counter
c=Counter()
for k,v in d['strings'].items():
    for l in v.get('localizations',{}): c[l]+=1
print(dict(c)); print('total keys:', len(d['strings']))
"
python3 scripts/verify-localization.py es fr de
```

Expected: `{'es': 150, 'fr': 150, 'en': 5, 'de': 150, 'it': 150}`, `total keys: 150`, and the es/fr/de run showing only the known InfoPlist gaps.

- [ ] **Step 6: Build and run the full suite**

```bash
./scripts/test.sh
```

Expected: PASS, same count as baseline.

- [ ] **Step 7: Commit**

```bash
git add DocumentScanner/DocumentScanner/Localizable.xcstrings scripts/verify-localization.py
git commit -m "$(cat <<'EOF'
localization: Italian (it) in-app UI translations

All 150 Localizable.xcstrings keys translated to Italian, informal "tu"
register, anchored to Apple's iOS terminology (Impostazioni, Cartella,
Salva, Elimina vs Rimuovi). Plural forms carry correct gender/number
agreement (selezionato/selezionati).

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: German + Italian privacy usage descriptions

The camera and Face ID strings are what iOS shows in the system permission alert. They are short, high-visibility, and reviewed by Apple — worth their own commit.

**Files:**
- Modify: `DocumentScanner/DocumentScanner/InfoPlist.xcstrings`

**Interfaces:**
- Consumes: `scripts/verify-localization.py` from Task 2.
- Produces: full de/it coverage across both catalogs — after this task, `python3 scripts/verify-localization.py` with no arguments passes.

- [ ] **Step 1: Confirm the remaining failures are exactly these two keys, in both languages**

```bash
python3 scripts/verify-localization.py
```

Expected:

```
FAIL — 4 problem(s):
  InfoPlist.xcstrings: [de] MISSING  'NSCameraUsageDescription'
  InfoPlist.xcstrings: [de] MISSING  'NSFaceIDUsageDescription'
  InfoPlist.xcstrings: [it] MISSING  'NSCameraUsageDescription'
  InfoPlist.xcstrings: [it] MISSING  'NSFaceIDUsageDescription'
```

- [ ] **Step 2: Add the four translations**

Edit `DocumentScanner/DocumentScanner/InfoPlist.xcstrings`. Add `de` and `it` siblings inside each key's `localizations` object, alongside the existing `en`/`es`/`fr`.

English source and the translations to add:

| Key | English | German | Italian |
|---|---|---|---|
| `NSCameraUsageDescription` | Pocket Scanner uses the camera to scan paper documents. | `Pocket Scanner verwendet die Kamera, um Papierdokumente zu scannen.` | `Pocket Scanner usa la fotocamera per scansionare documenti cartacei.` |
| `NSFaceIDUsageDescription` | Pocket Scanner can lock your library behind Face ID. | `Pocket Scanner kann deine Bibliothek mit Face ID sperren.` | `Pocket Scanner può bloccare la tua libreria con Face ID.` |

Use `"state": "translated"` for each new `stringUnit`. Do **not** touch `CFBundleDisplayName` or `CFBundleName` — the brand name stays English, and their `state: "new"` is pre-existing and harmless.

- [ ] **Step 3: Verify everything passes**

```bash
python3 scripts/verify-localization.py
```

Expected: `PASS — es, fr, de, it complete across 2 catalog(s)`

- [ ] **Step 4: Build and run the full suite**

```bash
./scripts/test.sh
```

Expected: PASS, same count as baseline.

- [ ] **Step 5: Commit**

```bash
git add DocumentScanner/DocumentScanner/InfoPlist.xcstrings
git commit -m "$(cat <<'EOF'
localization: de + it camera and Face ID usage descriptions

Completes String Catalog coverage — verify-localization.py now passes
for es, fr, de, and it across both catalogs. CFBundleDisplayName stays
English (brand name).

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Date-stamp long-format coverage for German and Italian

`DateStampFormat.long` already formats via the passed-in `Locale`, so German and Italian long dates should work with no production change. This task **proves** that rather than assuming it, and locks it against future regression.

> **Note on TDD shape:** this is a *characterization* test — it documents behavior the release depends on, so it is expected to pass on first run. Do not manufacture a fake red step. If it fails, that is a genuine finding and the production code needs work.

**Files:**
- Modify: `DocumentScanner/DocumentScannerTests/DateStampFormatTests.swift`

**Interfaces:**
- Consumes: `DateStampFormat.long.string(for:locale:)` from `DocumentScanner/DocumentScanner/DateStamp/DateStampFormat.swift:31`.
- Produces: nothing other tasks depend on.

- [ ] **Step 1: Check what German and Italian actually produce**

```bash
python3 - <<'EOF'
# Quick sanity read of what ICU produces for these locales; Swift's
# DateFormatter uses the same CLDR data.
import subprocess
print(subprocess.run(
    ["swift", "-e", '''
import Foundation
let c = DateComponents(year: 2026, month: 7, day: 9, hour: 12)
let d = Calendar.current.date(from: c)!
for id in ["de_DE", "it_IT"] {
    let f = DateFormatter()
    f.locale = Locale(identifier: id); f.dateStyle = .long; f.timeStyle = .none
    print(id, "->", f.string(from: d))
}
'''], capture_output=True, text=True).stdout)
EOF
```

Expected roughly: `de_DE -> 9. Juli 2026` and `it_IT -> 9 luglio 2026`. If `swift -e` is unavailable, skip this step and let Step 2's test discover the values — assert on the month name only (which is stable) rather than the full string.

- [ ] **Step 2: Add the test**

In `DocumentScanner/DocumentScannerTests/DateStampFormatTests.swift`, insert after `test_longFormat_usesLocaleMonthNameAndParticles` (line 54):

```swift
    func test_longFormat_germanAndItalian() {
        let d = date(2026, 7, 9)
        let de = DateStampFormat.long.string(for: d, locale: Locale(identifier: "de_DE"))
        XCTAssertTrue(de.localizedCaseInsensitiveContains("Juli"),
                      "de long format should use the German month, got \(de)")
        XCTAssertTrue(de.contains("2026"),
                      "de long format should include the year, got \(de)")
        let it = DateStampFormat.long.string(for: d, locale: Locale(identifier: "it_IT"))
        XCTAssertTrue(it.localizedCaseInsensitiveContains("luglio"),
                      "it long format should use the Italian month, got \(it)")
        XCTAssertTrue(it.contains("2026"),
                      "it long format should include the year, got \(it)")
    }

    func test_isoAndNumeric_stayRegionNeutral_inGermanAndItalian() {
        let d = date(2026, 7, 9)
        XCTAssertEqual(DateStampFormat.iso.string(for: d, locale: Locale(identifier: "de_DE")),
                       "2026-07-09")
        XCTAssertEqual(DateStampFormat.numericUS.string(for: d, locale: Locale(identifier: "it_IT")),
                       "07/09/2026")
    }
```

Assert on the month name substring, not the full formatted string — CLDR occasionally adjusts separators between OS releases, and a substring assertion tests the thing that matters (correct localized month) without being brittle.

- [ ] **Step 3: Run the suite**

```bash
./scripts/test.sh
```

Expected: PASS, with the count **2 higher** than the Task 1 baseline. If either new test fails, read the assertion message — it prints the actual formatted string, which tells you whether the locale is being ignored or CLDR simply formats differently than expected.

- [ ] **Step 4: Commit**

```bash
git add DocumentScanner/DocumentScannerTests/DateStampFormatTests.swift
git commit -m "$(cat <<'EOF'
test: pin de + it long date-stamp formats

Characterization tests confirming DateStampFormat.long localizes month
names for German and Italian (it already routes through the caller's
Locale, so no production change was needed), and that the ISO/numeric
formats stay region-neutral in those locales.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Back-translation QA pass

The spec's core risk mitigation: there is no native reviewer, so accuracy is established by independently translating the German and Italian **back** to English and diffing against the source. Peter receives a short list of genuinely low-confidence strings — not all 300.

**Files:**
- Create: `docs/superpowers/qa/2026-07-29-de-it-back-translation.md`

**Interfaces:**
- Consumes: completed `de` + `it` localizations from Tasks 2–4.
- Produces: a flag list. Task 7 applies any string changes Peter's review triggers.

- [ ] **Step 1: Extract every de/it string paired with its English source**

```bash
python3 - <<'EOF' > /private/tmp/claude-501/-Users-pjones-Desktop-PocketScanner/54fe95e3-e798-4975-8cf4-98720c0f9268/scratchpad/de-it-pairs.tsv
import json
for p in ["DocumentScanner/DocumentScanner/Localizable.xcstrings",
          "DocumentScanner/DocumentScanner/InfoPlist.xcstrings"]:
    d = json.load(open(p))
    for key, entry in sorted(d["strings"].items()):
        locs = entry.get("localizations", {})
        for lang in ("de", "it"):
            loc = locs.get(lang)
            if not loc:
                continue
            if "variations" in loc:
                for form, node in loc["variations"]["plural"].items():
                    print(f"{lang}\t{key} [{form}]\t{node['stringUnit']['value']}")
            else:
                print(f"{lang}\t{key}\t{loc['stringUnit']['value']}")
EOF
wc -l /private/tmp/claude-501/-Users-pjones-Desktop-PocketScanner/54fe95e3-e798-4975-8cf4-98720c0f9268/scratchpad/de-it-pairs.tsv
```

Expected: 304 lines (150 keys × 2 languages, +2 extra rows per language for the plural `one`/`other` split on two keys, +2 InfoPlist keys × 2 languages).

- [ ] **Step 2: Back-translate**

Working from the TSV, translate each German and Italian value **back into English without looking at the original English key**, then compare to the key. Flag a row when:
- the back-translation changes the meaning (not just the wording),
- the register slips to formal (`Sie`/`Lei`) — this is a hard failure, not a flag,
- a format specifier (`%@`, `%lld`) is missing, added, or reordered in a way that breaks the call site,
- Italian gender/number agreement looks wrong,
- a German compound noun looks invented rather than idiomatic,
- a glossary term was not used consistently.

Format-specifier drift is mechanically checkable — do that separately rather than by eye:

```bash
python3 - <<'EOF'
import json, re
SPEC = re.compile(r'%(?:lld|@|\d+\$[a-z@]+)')
for p in ["DocumentScanner/DocumentScanner/Localizable.xcstrings",
          "DocumentScanner/DocumentScanner/InfoPlist.xcstrings"]:
    d = json.load(open(p))
    for key, entry in d["strings"].items():
        want = sorted(SPEC.findall(key))
        for lang in ("de", "it"):
            loc = entry.get("localizations", {}).get(lang)
            if not loc or "variations" in loc:
                continue
            got = sorted(SPEC.findall(loc["stringUnit"]["value"]))
            if got != want:
                print(f"[{lang}] SPECIFIER MISMATCH {key!r}: want {want}, got {got}")
print("specifier check done")
EOF
```

Expected: `specifier check done` with no mismatch lines. Any mismatch is a bug — fix it in the catalog before continuing.

- [ ] **Step 3: Write the QA record**

Create `docs/superpowers/qa/2026-07-29-de-it-back-translation.md` with:
- a one-paragraph method statement (what was checked, and that no native reviewer was involved — this is the honest record of an accepted risk),
- the specifier-check result,
- a **"Flagged for Peter"** section: only genuinely low-confidence strings, each as a table row of *key · translation · back-translation · why it's flagged · suggested alternative*. Aim for under 15 rows across both languages; if it runs much longer, the translation quality is the problem, not the review.
- a **"Corrected during QA"** section listing anything already fixed, so the fix is on the record.

- [ ] **Step 4: Apply any corrections found**

If Step 2 or 3 surfaced outright errors (not judgment calls), fix them in the catalog now and re-run:

```bash
python3 scripts/verify-localization.py && ./scripts/test.sh
```

Expected: PASS on both.

- [ ] **Step 5: Commit**

```bash
git add docs/superpowers/qa/2026-07-29-de-it-back-translation.md \
        DocumentScanner/DocumentScanner/Localizable.xcstrings \
        DocumentScanner/DocumentScanner/InfoPlist.xcstrings
git commit -m "$(cat <<'EOF'
qa: back-translation review of de + it strings

Independent back-translation of every German and Italian string, diffed
against the English source. Format-specifier parity verified mechanically.
Records the flagged low-confidence strings for Peter and the corrections
already applied.

No native reviewer — this is the accepted-risk mitigation from the v3.2
design spec, and the record says so plainly.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 6: HUMAN GATE — hand Peter the flag list**

Present the "Flagged for Peter" table in chat. He does not read German or Italian, so frame each flag as a **decision he can actually make** — a meaning question ("should this say *delete* or *remove*?"), not a language question. Wait for his calls before Task 7.

---

## Task 7: German overflow visual pass and string shortening

The spec's named implementation-side risk. German compounds run long and can clip buttons and labels. Peter can catch this **without reading German** — truncation is visual.

**Files:**
- Modify: `DocumentScanner/DocumentScanner/Localizable.xcstrings` (shortened German values)
- Modify: assorted `.swift` files — **only** if a layout fix is genuinely better than a shorter string

**Interfaces:**
- Consumes: German localizations from Task 2; Peter's decisions from Task 6 Step 6.
- Produces: a German UI with no clipped text. Task 9's captions reuse any shortened wording.

- [ ] **Step 1: Build and launch in forced German**

In Xcode: Edit Scheme ▸ Run ▸ Options ▸ **App Language → German**. Build and run on the simulator.

Alternatively from the command line, launch an already-installed build with the language override:

```bash
xcrun simctl launch booted ca.peter-jones.DocumentScanner.dev -AppleLanguages '(de)' -AppleLocale de_DE
```

- [ ] **Step 2: HUMAN GATE — Peter walks every screen looking for clipped text**

Screens to cover, in order — these are where v3.0's es/fr overflow actually appeared:
1. Library root (empty state, list view, grid view)
2. Library with folders + sub-folders; swipe actions
3. Select-Multiple mode (the `%lld selected` toolbar)
4. Document viewer — bottom bar (Sign · Date · Share · ⋯), the ⋯ overflow menu, find-in-page bar
5. Edit Pages mode
6. Add Signature / Choose a Signature sheets
7. Add Date sheet — the four format presets
8. Settings — every row label, especially Default Filter and Show Folders
9. Tips screen
10. Every alert: delete document, delete folder, merge, discard markup, camera denied, iCloud recommended

He is looking for **clipped text, "…" truncation, or a label wrapping to an ugly third line** — not for translation quality. A screenshot of each offender is the most useful output.

- [ ] **Step 3: Shorten the offending strings**

For each reported overflow, prefer a shorter German string over a layout change — the layout is shared with four other languages that currently fit, and changing it risks regressing them.

This is exactly what v3.0 did for es/fr: `Escala de grises`→`Grises`, `Documentos escaneados`→`Escaneos`, `Niveaux de gris`→`Gris`. The German equivalents most likely to need it:

| Key | Likely German | Shortened if it overflows |
|---|---|---|
| `Greyscale` | `Graustufen` | `Grau` |
| `Scanned Documents` | `Gescannte Dokumente` | `Scans` |
| `Save as New Document` | `Als neues Dokument sichern` | `Als neues sichern` |
| `New Sub-folder` | `Neuer Unterordner` | `Unterordner` |
| `Select Multiple` | `Mehrere auswählen` | `Auswählen` |

Treat this table as the likely candidates, not the answer — shorten what Peter actually reports, and leave the rest alone.

- [ ] **Step 4: Re-verify and re-check**

```bash
python3 scripts/verify-localization.py
./scripts/test.sh
```

Expected: PASS on both. Then relaunch in German and confirm the reported screens are clean.

- [ ] **Step 5: Quick Italian pass**

Repeat Steps 1–2 with `-AppleLanguages '(it)' -AppleLocale it_IT`. Italian runs closer to English in length, so expect few or no findings — but check the same 10 screens rather than assuming.

- [ ] **Step 6: Commit**

```bash
git add DocumentScanner/DocumentScanner/Localizable.xcstrings
git commit -m "$(cat <<'EOF'
localization: shorten German strings that overflowed the layout

Forced-locale visual pass on de (and it) across the library, viewer,
sheets, Settings, Tips, and every alert. Shortened the German strings
that clipped rather than changing shared layout — the same approach v3.0
took for es/fr, and it keeps the four existing locales untouched.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: App Store metadata for German and Italian, and refreshed What's New for all seven locales

Adding two localizations means **every** localization on the v3.2 version needs a What's New — not just the new ones. That is 7 locales: `en`, `es`, `es-MX`, `fr`, `fr-CA`, `de`, `it`.

**Files:**
- Create: `scripts/verify-metadata.py`
- Create: `marketing/app-store-metadata/de/{subtitle,keywords,description,promotional_text,whats_new}.txt`
- Create: `marketing/app-store-metadata/it/{subtitle,keywords,description,promotional_text,whats_new}.txt`
- Modify: `marketing/app-store-metadata/{en,es,es-MX,fr,fr-CA}/whats_new.txt`

**Interfaces:**
- Consumes: the glossary; the final shortened German wording from Task 7.
- Produces: `scripts/verify-metadata.py`, run as `python3 scripts/verify-metadata.py`, exit 0/1. Task 9's captions should echo this copy.

- [ ] **Step 1: Write the character-limit verifier**

Create `scripts/verify-metadata.py`:

```python
#!/usr/bin/env python3
"""Verify App Store metadata files exist and fit ASC's character limits.

Usage:  python3 scripts/verify-metadata.py
Exit 0 = pass, 1 = failures found.
"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
META = ROOT / "marketing/app-store-metadata"
LOCALES = ["en", "es", "es-MX", "fr", "fr-CA", "de", "it"]
LIMITS = {
    "subtitle.txt": 30,
    "promotional_text.txt": 170,
    "keywords.txt": 100,
    "description.txt": 4000,
    "whats_new.txt": 4000,
}


def main():
    failures = []
    for locale in LOCALES:
        d = META / locale
        if not d.is_dir():
            failures.append(f"{locale}: directory missing")
            continue
        for name, limit in LIMITS.items():
            f = d / name
            if not f.exists():
                failures.append(f"{locale}/{name}: missing")
                continue
            # ASC counts the visible text; ignore one trailing newline.
            n = len(f.read_text().rstrip("\n"))
            if n == 0:
                failures.append(f"{locale}/{name}: empty")
            elif n > limit:
                failures.append(
                    f"{locale}/{name}: {n} chars, limit {limit} "
                    f"(over by {n - limit})")
            else:
                print(f"  ok  {locale}/{name}: {n}/{limit}")
    if failures:
        print(f"\nFAIL — {len(failures)} problem(s):")
        for f in failures:
            print("  " + f)
        return 1
    print(f"\nPASS — {len(LOCALES)} locales within ASC limits")
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 2: Run it to see the current gaps**

```bash
python3 scripts/verify-metadata.py
```

Expected — verified against the working tree on 2026-07-29 — exactly this:

```
  ok  en/subtitle.txt: 29/30
  ...25 ok lines across en, es, es-MX, fr, fr-CA...

FAIL — 2 problem(s):
  de: directory missing
  it: directory missing
```

Two problems, not twelve — the script reports the missing directory and moves to the next locale rather than also listing its five files.

All five existing locales currently pass, with `fr/promotional_text.txt` the tightest at **168/170**. If any existing locale reports over-limit, stop and fix that first — it means something shipped over the line.

- [ ] **Step 3: Write the German metadata**

Create the five files under `marketing/app-store-metadata/de/`.

- `subtitle.txt` — **≤30 chars, the tightest constraint in this release.** German words are long; count before writing prose. Target the same promise as English ("Scan, sign, search — offline"). Something like `Scannen, signieren, suchen` (26) works; verify the count, don't estimate it.
- `keywords.txt` — ≤100 chars, comma-separated, **no spaces after commas** (spaces waste the budget). Use in-market German search terms, not literal translations: `scanner,dokument,pdf,scan,unterschrift,signatur,ocr,texterkennung,büro`. Search-driven, not purity-driven.
- `description.txt` — full translation of `en/description.txt`, in the `du` register. Keep the structure (opening promise, feature list, the no-subscription/no-ads/no-tracking close). **The privacy-policy URL must be `https://peterajones.github.io/PocketScanner/privacy-policy`** — the old `mobileDocumentScanner` path 404s and was fixed in v3.1; do not reintroduce it.
- `promotional_text.txt` — ≤170. This field is editable without an app release, so it is the safest place for the most idiomatic copy.
- `whats_new.txt` — leads with the German launch, e.g. *"Pocket Scanner spricht jetzt Deutsch und Italienisch…"*, then the no-subscriptions/no-ads/no-tracking line.

- [ ] **Step 4: Write the Italian metadata**

Same five files under `marketing/app-store-metadata/it/`, `tu` register. Italian subtitles fit more comfortably than German, but still verify. Keywords in in-market Italian: `scanner,documenti,pdf,scansione,firma,ocr,ufficio`. Same privacy URL rule.

- [ ] **Step 5: Refresh What's New for the five existing locales**

Rewrite `whats_new.txt` for `en`, `es`, `es-MX`, `fr`, `fr-CA` to describe v3.2. The v3.1 files currently carry a generic maintenance note — replace it.

English, as the source the others translate:

```
Pocket Scanner now speaks German and Italian, joining Spanish and French. Every button, label, and message is fully localized, and dates format naturally for your language.

As always: no subscriptions, no ads, no tracking. Your documents stay on your device and in your iCloud.
```

Then translate that for `es`, `fr`, `de`, `it`. `es-MX` takes the `es` text verbatim (established in v3.1 — the Spanish copy is already region-neutral). `fr-CA` takes the `fr` text with the Quebec terminology pass: **numériser** not *scanner*, **application** not *app*, **courriel** not *e-mail*.

- [ ] **Step 6: Verify all seven locales**

```bash
python3 scripts/verify-metadata.py
```

Expected: `PASS — 7 locales within ASC limits`, with every file's count printed. Read the `subtitle.txt` counts specifically — German is the one at risk.

- [ ] **Step 7: Verify the privacy URL in every description**

```bash
grep -rn "mobileDocumentScanner" marketing/app-store-metadata/ && echo "FOUND DEAD URL — fix it" || echo "ok: no dead privacy URLs"
grep -rlc "peterajones.github.io/PocketScanner/privacy-policy" marketing/app-store-metadata/*/description.txt
```

Expected: `ok: no dead privacy URLs`, and all 7 description files listed by the second grep.

- [ ] **Step 8: Commit**

```bash
git add scripts/verify-metadata.py marketing/app-store-metadata/
git commit -m "$(cat <<'EOF'
marketing: German + Italian App Store metadata, v3.2 What's New for all 7 locales

Adds de/it subtitle, keywords, description, promotional text, and What's
New; refreshes What's New across en/es/es-MX/fr/fr-CA for the v3.2
launch (every localization on a version needs one). es-MX mirrors es;
fr-CA keeps the Quebec numériser/application terminology.

Adds scripts/verify-metadata.py — the 170-char promotional-text limit has
caught this project twice by eye, so it is now checked mechanically.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: Localized screenshots — restore the renderer, author captions, render the v3.2 set

**Files:**
- Create: `marketing/app-preview/render-captions.py` (restored from `335da59^` and retargeted)
- Create: `marketing/app-preview/captions/{de,it}.tsv`
- Create: `marketing/app-preview/v3.2/Stills/{de,it}/1.png … 8.png`
- Modify: `marketing/app-preview/demo-library-recipe.md` (§F status note)

**Interfaces:**
- Consumes: `marketing/app-preview/caption.sh` (unchanged; signature `caption.sh <in> <out> <line1> <line2> [top_px] [fs1] [fs2] [band] [color]`).
- Produces: the two 8-shot captioned sets for ASC upload in Task 10.

- [ ] **Step 1: Restore the retired renderer**

```bash
git show 335da59^:marketing/app-preview/render-captions.py > marketing/app-preview/render-captions.py
chmod +x marketing/app-preview/render-captions.py
git show 335da59^:marketing/app-preview/captions/en.tsv > /dev/null && echo "en.tsv recoverable"
```

- [ ] **Step 2: Retarget it at the v3.2 flat layout**

The restored script hardcodes `V3 = "marketing/app-preview/v3.0/Stills"`, writes to a `captioned/` subdirectory that no longer exists in the current layout, and expects base files named `<lang><shot>*.png`. Update it:

Replace:

```python
V3 = f"{APP}/v3.0/Stills"
```

with:

```python
V32 = f"{APP}/v3.2/Stills"
BASES = f"{APP}/v3.2/Base"
```

Replace `base_for` with a version that reads from a per-language base directory:

```python
def base_for(lang, shot):
    """Shot #4 (live scan) has no simulator camera — every non-en language
    reuses the shared uncaptioned 2a frame, which carries almost no app text."""
    if shot == 4:
        return SCAN2A
    hits = sorted(glob.glob(f"{BASES}/{lang}/{shot}.png"))
    return hits[0] if hits else None
```

Replace the output directory line:

```python
    outdir = f"{V3}/{lang}/captioned"
```

with:

```python
    outdir = f"{V32}/{lang}"
```

Drop the now-unused `BASE_LANG` dict — v3.2 adds two *full* languages with their own captures, not regional variants riding a parent's screenshots. Keep the `restval=""` on the `csv.DictReader`; it exists because a hand-authored TSV that omits the trailing `band`/`color` columns otherwise yields `None`, which `caption.sh` cannot take as an argument. That bug already cost a debugging cycle in v3.1.

- [ ] **Step 3: HUMAN GATE — Peter captures the base screenshots**

Per `marketing/app-preview/demo-library-recipe.md` §F. For each of German and Italian:
- Release build, simulator, status bar forced to 9:41
- Xcode ▸ Edit Scheme ▸ Run ▸ Options ▸ App Language → German (then Italian)
- Capture the same 8 scenes as es/fr, saved as `marketing/app-preview/v3.2/Base/<lang>/1.png … 8.png` (skip `4.png` — shot #4 reuses the shared 2a frame)
- All must be **1290×2796** (the 6.9″ slot)

Shots #7 and #8 need the library scrolled so the caption has room below the large title — the same adjustment made for es/fr.

Verify the captures before rendering:

```bash
for lang in de it; do
  for f in marketing/app-preview/v3.2/Base/$lang/*.png; do
    printf "%-50s %s\n" "$f" "$(sips -g pixelWidth -g pixelHeight "$f" | tr '\n' ' ')"
  done
done
```

Expected: every file `pixelWidth: 1290  pixelHeight: 2796`.

- [ ] **Step 4: Author the caption manifests**

Create `marketing/app-preview/captions/de.tsv`. Tab-separated, with this exact header, and keep the per-shot geometry from the en/es manifests (it is tuned to the app's layout and must not drift):

```
shot	line1	line2	top	fs1	fs2	band	color
1	Unterschreiben und datieren	direkt auf dem iPhone	508	64	56		
2	Schon ein PDF?	Mit einem Tippen importieren	2060	64	56		
3	Vertrag per E-Mail?	Unterschreiben — ohne Drucker	515	62	54		
4	Kein Drucker? Kein Problem.	Direkt vom Bildschirm scannen	165	62	54	rgba(0,0,0,0.82)	#ffffff
5	Unterschrift sichern	mit einem Tippen signieren	430	66	58		
6	Datum hinzufügen	in jedem Format	430	70	60		
7	Ordnung halten	mit Ordnern	600	74	62		
8	Ordner in Ordnern	alles sortiert	600	64	56		
```

German font sizes start smaller than English's 78/66 because German captions are longer — es used 70/60 for the same reason. Tune per row after rendering.

Create `marketing/app-preview/captions/it.tsv` the same way; Italian sits between English and German in length, so start at 70/60:

```
shot	line1	line2	top	fs1	fs2	band	color
1	Firma e data i documenti	direttamente da iPhone	508	70	60		
2	Hai già un PDF?	Importalo con un tocco	2060	70	60		
3	Contratto via email?	Firmalo e datalo, senza stampante	515	66	56		
4	Niente stampante? Nessun problema.	Scansiona dallo schermo	165	62	54	rgba(0,0,0,0.82)	#ffffff
5	Salva la tua firma	firma con un tocco	430	70	60		
6	Aggiungi la data	nel formato che preferisci	430	70	60		
7	Tieni tutto in ordine	con le cartelle	600	74	62		
8	Cartelle dentro le cartelle	tutto ordinato	600	64	56		
```

Both manifests must use the Task 8 glossary and match the metadata's wording — a caption saying `scannen` while the description says something else reads as sloppy.

- [ ] **Step 5: Render**

```bash
python3 marketing/app-preview/render-captions.py de it
```

Expected: two `== de ==` / `== it ==` blocks, each listing shots #1–#8 with the base filename used, and no `NO BASE (skipped)` lines.

- [ ] **Step 6: Verify the output**

```bash
for lang in de it; do
  echo "== $lang =="
  ls marketing/app-preview/v3.2/Stills/$lang/
  for f in marketing/app-preview/v3.2/Stills/$lang/*.png; do
    sips -g pixelWidth -g pixelHeight "$f" | tr '\n' ' '; echo " $f"
  done
done
```

Expected: `1.png … 8.png` in each directory, every one 1290×2796.

- [ ] **Step 7: HUMAN GATE — Peter eyeballs all 16 for caption overflow**

He is checking that no caption runs past the 1290px width or collides with app chrome — language-independent, exactly like the Task 7 overflow pass. Where a caption overflows, lower that row's `fs1`/`fs2` in the TSV and re-run Step 5 for that language.

- [ ] **Step 8: Update the pipeline status note**

In `marketing/app-preview/demo-library-recipe.md`, replace the "Pipeline status (post-v3.1)" block at the top of §F with a post-v3.2 note: the renderer is **restored and live** at `render-captions.py`, it reads bases from `v<version>/Base/<lang>/` and writes captioned sets to `v<version>/Stills/<lang>/`, and `captions/{de,it}.tsv` are the current manifests. Say plainly that the v3.0/v3.1 sets predate this layout so their historical paths differ.

- [ ] **Step 9: Commit**

```bash
git add marketing/app-preview/render-captions.py \
        marketing/app-preview/captions/ \
        marketing/app-preview/v3.2/ \
        marketing/app-preview/demo-library-recipe.md
git commit -m "$(cat <<'EOF'
marketing: German + Italian captioned screenshot sets for v3.2

Restores render-captions.py (retired after v3.1) and retargets it at the
flat per-version layout: bases in v3.2/Base/<lang>/, captioned output in
v3.2/Stills/<lang>/. Drops the BASE_LANG regional-variant mapping — de and
it are full languages with their own captures, not fallback variants.

German caption font sizes start below English's to absorb the extra
length, same adjustment es needed in v3.0. Recipe §F updated to describe
the live pipeline rather than the retired one.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 10: Version bump, final verification, and release handoff

**Files:**
- Modify: `DocumentScanner/DocumentScanner.xcodeproj/project.pbxproj` (`MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`)
- Modify: `docs/FutureEnhancements.md`

**Interfaces:**
- Consumes: everything above.
- Produces: a repo ready for Peter to archive and submit.

- [ ] **Step 1: Confirm the current version values**

```bash
grep -n "MARKETING_VERSION\|CURRENT_PROJECT_VERSION" DocumentScanner/DocumentScanner.xcodeproj/project.pbxproj
```

Expected: **two** app-target lines at `MARKETING_VERSION = 3.1;` and two at `CURRENT_PROJECT_VERSION = 30;`, plus test-target lines at `1.0` / `1`. Identify which lines belong to the app target before editing — the test targets must not change.

- [ ] **Step 2: Bump to 3.2 / 31**

Edit only the app-target occurrences: `MARKETING_VERSION = 3.1;` → `= 3.2;` (2 lines), `CURRENT_PROJECT_VERSION = 30;` → `= 31;` (2 lines).

- [ ] **Step 3: Verify the bump landed and nothing else moved**

```bash
plutil -lint DocumentScanner/DocumentScanner.xcodeproj/project.pbxproj
grep -n "MARKETING_VERSION\|CURRENT_PROJECT_VERSION" DocumentScanner/DocumentScanner.xcodeproj/project.pbxproj
git diff --stat DocumentScanner/DocumentScanner.xcodeproj/project.pbxproj
```

Expected: lint OK; two `3.2` lines, two `31` lines, test targets still `1.0` / `1`; the diff touches exactly 4 lines.

This check exists because v2.9 was nearly archived without its bump — verify the pbxproj *before* archiving, every time.

- [ ] **Step 4: Full green run**

```bash
python3 scripts/verify-localization.py
python3 scripts/verify-metadata.py
./scripts/test.sh
```

Expected: PASS on all three. The suite count should be the Task 1 baseline **+2** (from Task 5). State the actual number rather than "all pass".

- [ ] **Step 5: Update the roadmap doc**

In `docs/FutureEnhancements.md`, change the Internationalization bullet from "v3.2 (planned): German (de) + Italian (it)…" to record it as shipped in v3.2 alongside the es/fr line, keeping the pointer to the design spec. Leave the "localized App Preview videos" item open — it is deferred again, not done.

- [ ] **Step 6: Commit**

```bash
git add DocumentScanner/DocumentScanner.xcodeproj/project.pbxproj docs/FutureEnhancements.md
git commit -m "$(cat <<'EOF'
release: bump version to 3.2 (31)

App target only; the test targets stay at 1.0/1. Records German + Italian
as shipped in docs/FutureEnhancements.md.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 7: Hand off to Peter with the submission checklist**

Do **not** push, archive, or touch App Store Connect. Present this checklist:

1. **Push** `main`.
2. **Archive** — Release config, run destination **"Any iOS Device (arm64)"** (this must be set manually; the Release config is automatic). Upload.
3. **In ASC, on the v3.2 version:** add **German** and **Italian** via the version's language dropdown. Do **not** change the primary language — that would demand screenshots for every past version.
4. Paste metadata for all 7 locales from `marketing/app-store-metadata/<locale>/`, **including the refreshed What's New for the 5 existing locales.**
5. Upload `marketing/app-preview/v3.2/Stills/{de,it}/1–8.png` to each new locale's **6.9″** slot (not 6.5″ — that slot wants 1242×2688 and will reject these as "wrong size").
6. Reuse the existing English App Preview video across the new wells.
7. **Watch the language-selector reset.** The ASC selector reverts on every page navigation (Subtitle→App Information, screenshots→Media Manager, the rest→version page). Confirm the language indicator on *each page* before editing — this has caused wrong-language uploads twice.
8. **"Ready for Review" is not submitted.** Hit **Submit to App Review** to reach "Waiting for Review."

---

## Self-Review

**Spec coverage** — every section of `2026-07-24-localization-de-it-design.md` maps to a task:

| Spec section | Task |
|---|---|
| In-app UI, ~150 keys, de + it | 2, 3 |
| Model-derived strings via `String(localized:)` | Covered — already converted in v3.0; the keys are in the catalog, so Tasks 2–3 translate them with everything else. No new plumbing, as the spec predicted. |
| Plurals (`%lld selected`, `%lld pages`) | 2, 3 (explicit `one`/`other` shapes given) |
| `InfoPlist.xcstrings` | 4 |
| Harvest gotcha (Xcode ⌘B needed for *new* keys) | N/A — verified no new keys are introduced; the plan only adds languages to existing ones. Called out here so nobody goes looking for a missing step. |
| Register (du / tu) | Global Constraints; enforced in 2, 3, 6 |
| Terminology anchoring | Global Constraints glossary, empirically verified in 2.1 / 3.1 |
| German overflow pass | 7 |
| Back-translation QA + flag list | 6 |
| App Store metadata, German subtitle constraint | 8 |
| Screenshots, restored renderer, v3.2/Stills | 9 |
| Testing (suite green, forced-locale smoke) | 1, 2, 3, 4, 5, 7, 10 |
| Release mechanics (3.2/31, ASC steps, selector footgun) | 10 |
| Deferred: App Preview videos, regional variants | Explicitly out of scope; Task 10 Step 5 keeps the video item open |

**Gaps found in the spec and added to this plan:**
1. **`knownRegions`** — `de`/`it` were missing from the pbxproj and the spec never mentioned it. Now Task 1, and it gates everything.
2. **What's New for the 5 existing locales** — adding localizations means all 7 need one. Now Task 8 Step 5.
3. **Date-stamp long format** — already locale-driven, so it needed no code change, but nothing pinned that for de/it. Now Task 5, framed honestly as a characterization test.
4. **Renderer retargeting** — the restored `render-captions.py` points at `v3.0/Stills` and a `captioned/` subdir that no longer exists. Task 9 Step 2 gives the exact edits.

**Placeholder scan:** no "TBD", no "similar to Task N", no "add error handling". The one deliberate non-inline is the 300 translated strings, which is generative content bounded by the glossary, worked examples, and two verification scripts — flagged explicitly under File Structure.

**Type consistency:** `scripts/verify-localization.py` is created in Task 2 and reused unchanged in Tasks 3, 4, 6, 7, 10. `scripts/verify-metadata.py` is created in Task 8 and reused in 10. `caption.sh`'s 9-argument signature is quoted from the live file. `DateStampFormat.long.string(for:locale:)` matches `DateStampFormat.swift:31`. Base/output paths (`v3.2/Base/<lang>/`, `v3.2/Stills/<lang>/`) are used identically in Task 9 Steps 2, 3, 5, 6 and Task 10 Step 7.
