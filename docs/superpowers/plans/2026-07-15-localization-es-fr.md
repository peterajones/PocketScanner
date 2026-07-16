# v3.0 Localization (Spanish + French) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Localize Pocket Scanner into Spanish (es) and French (fr) — in-app UI plus App Store listing and screenshots — shipped as one bundled v3.0 release.

**Architecture:** Add a SwiftUI String Catalog (`Localizable.xcstrings`) that auto-harvests the ~200 `Text("literal")` strings; convert the handful of model-derived `Text(variable)` strings to `LocalizedStringResource` so they localize too; source-control App Store metadata and a per-language screenshot-caption manifest that drives the existing `caption.sh`. Claude drafts all es/fr copy; Peter QAs both languages.

**Tech Stack:** Xcode 26 String Catalogs (`.xcstrings`), SwiftUI `LocalizedStringKey` / `LocalizedStringResource` / `String(localized:)`, `InfoPlist.xcstrings`, bash + headless Chrome (`caption.sh`).

## Global Constraints

- **Languages this round:** Spanish (`es`) + French (`fr`) only. Pipeline may be built to scale but no other languages are added.
- **App name:** stays `Pocket Scanner` untranslated in every locale (brand).
- **Never localized (user data / dynamic):** document, folder, and signature names; version string; auth-error text; date-format *patterns*.
- **Translation source:** Claude drafts all es/fr; Peter QAs both. Flag any phrase Claude is <90% confident on.
- **Keywords field:** real in-market search terms per locale, not literal translations.
- **Screenshot size:** 1290×2796, no alpha, uploaded to the **6.9" slot** (never 6.5").
- **Ships as:** v3.0, build 29. Version bump is a separate, explicit step — verify before archiving.
- **Test baseline:** existing suite (225 unit / 227 with UI) must stay green throughout.
- **Dev/prod split:** DEBUG = `.dev` bundle (local store); RELEASE = prod bundle (real iCloud). Storage-touching smoke runs on the Release build.

---

### Task 1: Add String Catalog and auto-harvest UI strings

**Files:**
- Create: `DocumentScanner/DocumentScanner/Localizable.xcstrings`
- Modify: `DocumentScanner/DocumentScanner.xcodeproj/project.pbxproj` (register the catalog in the app target's Resources build phase; add `es`, `fr` to `knownRegions`)

**Interfaces:**
- Produces: a String Catalog registered in the app target, with `en` as source and `es`/`fr` as (initially empty) localizations. Later tasks fill values.

- [ ] **Step 1: Create an empty String Catalog**

In Xcode: File → New → File → **String Catalog**, name `Localizable`, target = the app (not tests). This writes `Localizable.xcstrings` and registers it. (Equivalent to a web i18n `en.json` that the compiler wires up automatically.)

- [ ] **Step 2: Add es and fr to the project's known regions**

In Xcode: Project → Info → Localizations → **＋** → add **Spanish** and **French**. Confirm `project.pbxproj` `knownRegions` now includes `es` and `fr`.

Run: `grep -A6 "knownRegions" DocumentScanner/DocumentScanner.xcodeproj/project.pbxproj`
Expected: list contains `en`, `es`, `fr`, `Base`.

- [ ] **Step 3: Build to auto-harvest string keys**

Run:
```bash
xcodebuild -project DocumentScanner/DocumentScanner.xcodeproj -scheme DocumentScanner -destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO | tail -5
```
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Verify the catalog harvested the literal strings**

Open `Localizable.xcstrings` in Xcode's catalog editor (or grep the JSON). Confirm familiar strings appear as keys (e.g. "Library", "Send Feedback", "Camera access needed").

Run: `grep -c '"' DocumentScanner/DocumentScanner/Localizable.xcstrings`
Expected: non-trivial count (dozens of keys present).

- [ ] **Step 5: Commit**

```bash
git add DocumentScanner/DocumentScanner/Localizable.xcstrings DocumentScanner/DocumentScanner.xcodeproj/project.pbxproj
git commit -m "i18n: add String Catalog, register es/fr, harvest UI strings"
```

---

### Task 2: Make model-derived strings localizable

Convert the plain-`String` display values rendered via `Text(variable)` (verbatim, non-localizing) into `LocalizedStringResource`, so the catalog reaches them. This is the one place English could silently ship into es/fr, so it gets a real test.

**Files:**
- Modify: filter display names (grep `displayName` under `DocumentScanner/DocumentScanner` — likely `ScanFilter`/pipeline enum)
- Modify: `DocumentScanner/DocumentScanner/Library/SortMenu.swift` (`key.title`)
- Modify: `DocumentScanner/DocumentScanner/Settings/Tip.swift` (`title`, `body`)
- Modify: `DocumentScanner/DocumentScanner/App/DocumentScannerApp.swift` (alert model `title`/`message`, `action.title`)
- Test: `DocumentScanner/DocumentScannerTests/LocalizationTests.swift` (create)

**Interfaces:**
- Produces: the enums/models above expose `LocalizedStringResource` display properties (e.g. `ScanFilter.displayName: LocalizedStringResource`). Rendering sites use `Text(resource)` (which IS localizing) instead of `Text(string)`.
- Consumes: nothing from prior tasks beyond Task 1's catalog existing.

- [ ] **Step 1: Write the failing test**

Confirm a representative model-derived string localizes. Create `LocalizationTests.swift`:
```swift
import XCTest
@testable import DocumentScanner

final class LocalizationTests: XCTestCase {
    func testFilterDisplayNameLocalizes() throws {
        // English source value renders through the localization system.
        let en = String(localized: ScanFilter.color.displayName, locale: Locale(identifier: "en"))
        XCTAssertEqual(en, "Color")
        // The resource resolves (does not crash / return empty) for es.
        let es = String(localized: ScanFilter.color.displayName, locale: Locale(identifier: "es"))
        XCTAssertFalse(es.isEmpty)
    }
}
```
(Adjust `ScanFilter.color` / `"Color"` to the actual enum case + English label found by grepping `displayName`.)

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
xcodebuild test -project DocumentScanner/DocumentScanner.xcodeproj -scheme DocumentScanner -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:DocumentScannerTests/LocalizationTests 2>&1 | tail -15
```
Expected: FAIL — `displayName` is currently a `String`, not a `LocalizedStringResource` (compile error or wrong type).

- [ ] **Step 3: Convert the display properties to LocalizedStringResource**

For each model, change the property type and use a string literal (the catalog harvests `LocalizedStringResource("…")` literals too). Example for the filter enum:
```swift
var displayName: LocalizedStringResource {
    switch self {
    case .color:      return "Color"
    case .grayscale:  return "Grayscale"
    case .blackWhite: return "Black & White"
    // …existing cases, same English text as before…
    }
}
```
Apply the same pattern to `SortKey.title`, `Tip.title`/`Tip.body`, and the alert model's `title`/`message`/`action.title`.

- [ ] **Step 4: Update the render sites to use the localizing initializer**

At each `Text(variable)` site for these values, `Text` accepts a `LocalizedStringResource` directly, so `Text(f.displayName)` now localizes with no further change. For any site that needs a plain `String` (e.g. building an `Alert` message from a model), use `String(localized: model.message)`. Verify no remaining `Text(<these vars>)` uses the verbatim `String` initializer.

- [ ] **Step 5: Run test + full suite to verify green**

Run:
```bash
xcodebuild test -project DocumentScanner/DocumentScanner.xcodeproj -scheme DocumentScanner -destination 'platform=iOS Simulator,name=iPhone 16 Pro' 2>&1 | tail -15
```
Expected: PASS, full suite green.

- [ ] **Step 6: Rebuild to harvest the new keys**

Run the Step-3 build command from Task 1. Confirm the new strings (filter names, sort titles, tips, alert copy) now appear in `Localizable.xcstrings`.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "i18n: make model-derived display strings LocalizedStringResource"
```

---

### Task 3: Draft and fill es/fr translations for all UI strings

**Files:**
- Modify: `DocumentScanner/DocumentScanner/Localizable.xcstrings`

**Interfaces:**
- Consumes: the full harvested key set from Tasks 1–2.
- Produces: every key has an `es` and `fr` value with catalog state `translated`.

- [ ] **Step 1: Enumerate untranslated keys**

Open the catalog in Xcode; filter each of es and fr by state `NEW`/needs-review. This is the work list.

- [ ] **Step 2: Draft translations key by key**

Claude fills each es and fr value directly in the catalog JSON (or via the Xcode editor). Rules: natural in-market phrasing, respect UI brevity (button labels stay short), keep `Pocket Scanner` verbatim where it appears mid-sentence, preserve any interpolation placeholders (`%@`, `%lld`) exactly. Flag <90%-confidence phrases inline in the PR/commit for Peter.

- [ ] **Step 3: Build to confirm no format-specifier or catalog errors**

Run the Task 1 Step-3 build command. Expected: `BUILD SUCCEEDED`, no "string catalog" warnings about mismatched specifiers.

- [ ] **Step 4: Peter QA gate (both languages)**

Peter reviews es + fr values (Xcode catalog editor is the easiest read). Deferred to the on-device pass in Task 6 for visual context; textual pass can happen here.

- [ ] **Step 5: Commit**

```bash
git add DocumentScanner/DocumentScanner/Localizable.xcstrings
git commit -m "i18n: Spanish + French translations for UI strings"
```

---

### Task 4: Handle plurals

**Files:**
- Modify: `DocumentScanner/DocumentScanner/Localizable.xcstrings`
- Modify: any source with a count-bearing string (grep results below)

**Interfaces:**
- Produces: count strings use catalog plural variations with correct en/es/fr rules (one/other).

- [ ] **Step 1: Find count-bearing strings**

Run:
```bash
grep -rniE "\\\\\(.*count\)|page[s]? |of %|%lld|%d" DocumentScanner/DocumentScanner --include="*.swift"
```
Expected: the page-count / find-bar `n/m` style strings. If there are genuinely none that grammatically inflect, note that and skip to Step 4.

- [ ] **Step 2: Convert each to a localizable format string**

Ensure the string is a format with the count as an argument, e.g. `String(localized: "\(n) pages")` so the catalog can offer plural variation.

- [ ] **Step 3: Add plural variations in the catalog**

In the Xcode catalog editor, right-click the key → **Vary by Plural**, then fill `one`/`other` for en, es, fr (e.g. en `1 page` / `%lld pages`; es `1 página` / `%lld páginas`; fr `1 page` / `%lld pages`).

- [ ] **Step 4: Build + run to verify**

Run the Task 1 Step-3 build. Manually confirm 1 vs 2 renders correctly in each locale during Task 6.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "i18n: plural rules for count strings (en/es/fr)"
```

---

### Task 5: Localize Info.plist permission strings

**Files:**
- Create: `DocumentScanner/DocumentScanner/InfoPlist.xcstrings`

**Interfaces:**
- Produces: localized `NSCameraUsageDescription` and `NSFaceIDUsageDescription`.

- [ ] **Step 1: Create the InfoPlist String Catalog**

Xcode: File → New → File → String Catalog, name **`InfoPlist`**, app target. Xcode auto-surfaces the usage-description keys.

- [ ] **Step 2: Fill es/fr for the two usage strings**

Camera + FaceID descriptions, translated. Keep them short and reassuring (App Review reads these).

- [ ] **Step 3: Build to verify**

Run the Task 1 Step-3 build. Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Commit**

```bash
git add DocumentScanner/DocumentScanner/InfoPlist.xcstrings
git commit -m "i18n: localize camera/FaceID usage strings (es/fr)"
```

---

### Task 6: Forced-locale QA and text-expansion fixes

**Files:**
- Modify: any SwiftUI view where es/fr text clips (as found)

**Interfaces:**
- Consumes: filled translations from Tasks 3–5.

- [ ] **Step 1: Run the app forced into Spanish**

In Xcode: Edit Scheme → Run → Options → App Language = **Spanish**. Launch on the iPhone 16 Pro simulator. Walk every screen: library, scan, viewer (esp. the tightened bottom toolbar), Sign/Date sheets, Settings, Tips, alerts, Import.

- [ ] **Step 2: Note and fix clipping/truncation**

For each overflow: prefer shortening the translation (Task 3 edit) over layout changes; only adjust layout (`.minimumScaleFactor`, `.lineLimit`, spacing) when the copy is already as short as it reads well. Keep changes minimal and consistent with existing view patterns.

- [ ] **Step 3: Repeat forced into French**

Same walk-through with App Language = **French**.

- [ ] **Step 4: Peter QA sign-off (both languages)**

Peter does the es + fr walk-through and confirms copy reads naturally and nothing clips.

- [ ] **Step 5: Run full suite**

Run the Task 2 Step-5 test command. Expected: green.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "i18n: fix text-expansion clipping for es/fr"
```

---

### Task 7: App Store metadata source files

**Files:**
- Create: `marketing/app-store-metadata/en/{name,subtitle,keywords,description,promotional_text,whats_new}.txt`
- Create: `marketing/app-store-metadata/es/…` (same six)
- Create: `marketing/app-store-metadata/fr/…` (same six)

**Interfaces:**
- Produces: source-controlled metadata for all three locales, ready to paste into ASC in Task 10.

- [ ] **Step 1: Capture current English metadata**

Copy the live ASC values into the `en/` files verbatim (name = `Pocket Scanner`). This baselines English under version control.

- [ ] **Step 2: Draft es + fr**

Translate subtitle, description, promotional text, and the v3.0 What's New. For **keywords**, research real in-market search terms per locale (e.g. es: `escáner, escanear documentos, PDF, firma, digitalizar`; fr: `scanner, numériser, PDF, signature, document`) — fit ≤100 chars, comma-separated, no spaces after commas to maximize the field. Name stays `Pocket Scanner` in all three.

- [ ] **Step 3: Length-check each field**

Run:
```bash
cd marketing/app-store-metadata
for l in en es fr; do echo "== $l =="; awk '{print length": "FILENAME}' $l/name.txt $l/subtitle.txt $l/keywords.txt; done
```
Expected: name ≤30, subtitle ≤30, keywords ≤100 for every locale. Trim any overflow.

- [ ] **Step 4: Peter QA gate**

Peter reads es + fr copy; adjust per feedback.

- [ ] **Step 5: Commit**

```bash
git add marketing/app-store-metadata
git commit -m "marketing: es/fr App Store metadata source files"
```

---

### Task 8: Localized screenshot caption pipeline

**Files:**
- Modify: `marketing/app-preview/caption.sh` (add optional font-size override)
- Create: `marketing/app-preview/captions/{en,es,fr}.tsv`
- Create: `marketing/app-preview/caption-all.sh`
- Create output: `marketing/app-preview/v3.0/Stills-{es,fr}/` (+ `Stills-en` baseline)

**Interfaces:**
- Consumes: the existing per-shot English caption text + `top_px` values (from the v2.9 stills / storyboard).
- Produces: en/es/fr captioned screenshot sets at 1290×2796.

- [ ] **Step 1: Add a font-size override to caption.sh**

Add optional args 6 and 7 so long es/fr lines fit:
```bash
IN="$1"; OUT="$2"; L1="$3"; L2="$4"; TOP="${5:-430}"; FS1="${6:-78}"; FS2="${7:-66}"
```
and reference them in the CSS:
```css
 .cap .l1{font-weight:700;font-size:${FS1}px;}
 .cap .l2{font-weight:600;font-size:${FS2}px;}
```

- [ ] **Step 2: Build the English caption manifest**

Create `captions/en.tsv` (tab-separated): `shot<TAB>src_png<TAB>line1<TAB>line2<TAB>top_px<TAB>fs1<TAB>fs2`, one row per the 8 shots, using the existing English caption text and each shot's known `top_px` (hero #1 = 508; find/menu band ≈ 2060 per the v2.9 notes; default 430 otherwise).

- [ ] **Step 3: Write caption-all.sh**

Reads a language manifest and renders the set:
```bash
#!/usr/bin/env bash
# Usage: caption-all.sh <lang>   e.g. caption-all.sh es
set -euo pipefail
LANG_CODE="$1"
DIR="$(cd "$(dirname "$0")" && pwd)"
OUT="$DIR/v3.0/Stills-$LANG_CODE"; mkdir -p "$OUT"
while IFS=$'\t' read -r shot src l1 l2 top fs1 fs2; do
  [ "$shot" = "shot" ] && continue   # header
  "$DIR/caption.sh" "$src" "$OUT/$shot.png" "$l1" "$l2" "$top" "$fs1" "$fs2"
done < "$DIR/captions/$LANG_CODE.tsv"
```

- [ ] **Step 4: Generate the English set and verify parity**

Run:
```bash
cd marketing/app-preview && chmod +x caption-all.sh && ./caption-all.sh en
sips -g pixelWidth -g pixelHeight v3.0/Stills-en/*.png | grep -E "pixelWidth|pixelHeight" | sort -u
```
Expected: all outputs 1290×2796; visually matches the current v2.9 captioned set.

- [ ] **Step 5: Draft es/fr caption manifests and generate**

Create `captions/es.tsv` and `captions/fr.tsv` with translated `line1`/`line2` (and reduced `fs1`/`fs2` where a line would overflow 1290px). Then:
```bash
./caption-all.sh es && ./caption-all.sh fr
```
Visually check no caption overflows the frame width; nudge font sizes in the manifest and re-run as needed.

- [ ] **Step 6: Peter QA gate**

Peter eyeballs es + fr screenshot captions for wording + fit.

- [ ] **Step 7: Commit**

```bash
git add marketing/app-preview/caption.sh marketing/app-preview/caption-all.sh marketing/app-preview/captions marketing/app-preview/v3.0/Stills-en marketing/app-preview/v3.0/Stills-es marketing/app-preview/v3.0/Stills-fr
git commit -m "marketing: es/fr localized screenshot pipeline + sets"
```

---

### Task 9: Version bump to 3.0 (29)

**Files:**
- Modify: `DocumentScanner/DocumentScanner.xcodeproj/project.pbxproj` (both app configs)

- [ ] **Step 1: Bump both app build configs**

Set `MARKETING_VERSION = 3.0` and `CURRENT_PROJECT_VERSION = 29` in the Debug/`.dev` and Release/prod app configs only (leave the four test-target `1`/`1.0` entries).

- [ ] **Step 2: Verify**

Run:
```bash
grep -nE "MARKETING_VERSION|CURRENT_PROJECT_VERSION" DocumentScanner/DocumentScanner.xcodeproj/project.pbxproj
```
Expected: two `3.0` and two `29` for the app; test targets still `1.0`/`1`.

- [ ] **Step 3: Commit + push**

```bash
git add DocumentScanner/DocumentScanner.xcodeproj/project.pbxproj
git commit -m "release: bump version to 3.0 (29)"
git push origin main
```

---

### Task 10: Release runbook (manual ASC + on-device smoke)

Not a code task — a checklist executed by Peter in Xcode + App Store Connect. No automated test; the "test" is a successful on-device smoke + submission.

- [ ] **Step 1: On-device Release/iCloud smoke**

Archive nothing yet — first run the Release build on a device, verify es + fr render correctly and iCloud storage still works (Files app "Pocket Scanner"). Localization shouldn't touch storage, but the discipline stands for any release.

- [ ] **Step 2: Archive + upload**

Run destination **Any iOS Device (arm64)**; Product → Archive; Organizer → Distribute → App Store Connect → Upload. Confirm the archive reads **3.0 (29)**.

- [ ] **Step 3: Add es/fr localizations in ASC**

App Store Connect → the 3.0 version → add **Spanish** and **French** localizations. Paste each field from `marketing/app-store-metadata/{es,fr}/`; update `en` if changed.

- [ ] **Step 4: Upload localized screenshots**

For each locale (en/es/fr), upload its 8-shot set from `marketing/app-preview/v3.0/Stills-<lang>/` into the **6.9" slot**. Add the App Preview video where applicable.

- [ ] **Step 5: Localized What's New + submit**

Paste each locale's `whats_new.txt`, select **Build 29**, then **Submit to App Review** (not just "Ready for Review").

---

## Self-Review

**Spec coverage:**
- In-app catalog + auto-harvest → Task 1 ✓
- Model-derived string conversion → Task 2 ✓
- es/fr UI translations → Task 3 ✓
- Plurals → Task 4 ✓
- Info.plist strings → Task 5 ✓
- Text-expansion QA → Task 6 ✓
- App Store metadata (name kept, keywords as search terms) → Task 7 ✓
- Localized screenshots (manifest + caption-all + font override) → Task 8 ✓
- Version bump 3.0/29 → Task 9 ✓
- ASC release mechanics + smoke → Task 10 ✓
- "Both languages QA" appears at Tasks 3, 6, 7, 8 ✓
- Guardrails (es/fr only, no fastlane, no safety check) honored ✓

**Placeholder scan:** No "TBD/handle edge cases" placeholders. Translation content is produced at execution (it is copy, not logic) with concrete method + examples given — not a vague instruction.

**Type consistency:** `LocalizedStringResource` display properties (Task 2) are consumed by `Text(resource)` render sites (Task 2 Step 4) and filled in the catalog (Task 3). `caption.sh` arg order `IN OUT L1 L2 TOP FS1 FS2` (Task 8 Step 1) matches `caption-all.sh`'s invocation (Task 8 Step 3). Consistent.
