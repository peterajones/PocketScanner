# v3.3 Tips de/it — Back-Translation QA Record

**Date:** 2026-08-28
**Scope:** the 5 new/rewritten tip strings in `Localizable.xcstrings` — 2 titles, 3 bodies — plus the 2 markup-menu titles the pass uncovered as untranslated (F-1). 7 keys × 4 languages = 28 translated values. German and Italian back-translated; Spanish and French await Peter's own QA.
**Precedent:** `docs/superpowers/qa/2026-07-29-de-it-back-translation.md`, `docs/superpowers/qa/2026-08-28-de-it-whats-new-back-translation.md`

---

## Method

Same as the two prior records, and run because `docs/FutureEnhancements.md` now records this as a standing per-release obligation rather than a one-off. Every German and Italian value was independently translated back to English and compared against the source, then mechanically checked.

**Register note:** tips are in-app copy, so the same informal register the app uses applies — `du` in German, `tu` in Italian. That differs from the App Store description, which is not in scope here.

---

## Mechanical check results

| Check | Result |
|---|---|
| Coverage — all 5 keys, all 4 languages | **PASS** (`verify-localization.py`, exit 0) |
| `Tip.swift` keys all resolve in the catalog | **PASS** — 16/16 |
| Tip ids unique, `highlights` still present | **PASS** — 8 ids, `TipTests` green |
| Semantic diff of the catalog | **PASS** — 3 keys removed, 5 added, **0 modified in place** |
| Unit suite | **PASS** — 240/240, 0 failed, 0 skipped (from the xcresult bundle, not `test.sh`'s count) |
| Cross-reference — quoted UI actions match their own translations | **1 FAILURE** — see IT-2 (fixed) |

The cross-reference check is the one that earned its keep. `Move to…` / `Merge into…` / `Rename` all matched correctly in both languages (`Bewegen nach…` / `Zusammenführen` / `Umbenennen`; `Sposta in…` / `Unisci in…` / `Rinomina`). The word for an annotation did not — see below.

---

## Corrected during QA

Four applied directly. Each asserted its expected current value before writing, so a drifted string would have aborted rather than been overwritten.

| # | Lang | Was | Now | Why |
|---|---|---|---|---|
| DE-1 | de | Tippen und halten für **mehr** | …für **mehr Optionen** | "für mehr" is elliptical in German in a way "for more" is not in English — it reads as an unfinished phrase. |
| DE-2 | de | **Markiere Text** in einem Scan… | **Wähle in einem Scan Text aus**… | *Markieren* is German for *to select text*, but *Markierung* is the word the same sentence uses for the resulting highlight. The tip read as "mark text… marks align…" — a collision the English doesn't have. |
| IT-1 | it | **Senza,** tutto resta… | **Se non è attivo,** tutto resta… | Bare *Senza* as a sentence opener is clipped. |
| IT-2 | it | Le **marcature** si allineano… Tocca una **marcatura**… | Le **annotazioni**… Tocca **un'annotazione**… | **Cross-reference failure.** The app's own alert is `Rimuovere questa annotazione?` — itself a v3.2 QA correction. The tip was teaching users a word the app never shows them. |

IT-2 is the substantive one, and it is the exact failure mode the v3.2 record flagged: copy that quotes the interface drifting away from what the interface actually says.

---

## Flagged for Peter — and his ruling

**F-1. The tips describe two menu items that appear in English regardless of language.**

`Highlight` and `Strikethrough` are built as plain UIKit string literals in `MarkupPDFView.buildMenu(with:)` (`DocumentViewerView.swift:696`, `:700`) rather than `String(localized:)`, so they are **not in the string catalog and are not translated**. Their four colour children *are* localized (`AnnotationColor.displayName` → `Gelb` / `Grün` / `Rosa` / `Blau`). A German user opens an English `Highlight` menu containing German colour names.

This is pre-existing and shipped in v3.0, v3.1 and v3.2 — not introduced by this work. It was found only because writing the tip required checking what the buttons are called.

It leaves the new tip in an awkward spot. The English copy was already written around it — it says "pick a highlight color or strikethrough" rather than naming the buttons, precisely so it stays true whichever way the bug goes. But the German and Italian translations still use native words (*Highlight-Farbe* / *Durchstreichen*, *colore di evidenziazione* / *la barratura*) for controls the user will see in English.

**The right wording depends on a decision that isn't mine:**

- **If the menu gets localized** (two `String(localized:)` calls, 8 translated values, needs an Xcode harvest), the current translations become correct as written and nothing else changes.
- **If it stays English**, the translations should arguably name the English labels so users can find them — which reads badly but navigates correctly.

**Recommendation: fix the menu.** It is two lines, it is a genuine localization defect in its own right, and it is exactly the shape of a clean-up release. The tip wording then needs no further change.

### F-1 resolved — Peter chose to fix the menu (2026-08-28)

Both titles are now `String(localized:)` with a comment, and both keys carry all four translations.

| Key | de | es | fr | it |
|---|---|---|---|---|
| `Highlight` | Hervorheben | Resaltar | Surligner | Evidenzia |
| `Strikethrough` | Durchstreichen | Tachar | Barrer | Barrato |

**One deliberate divergence, in Italian.** The app's other action strings are imperative (`Rinomina`, `Sposta in…`, `Unisci in…`), so register consistency argues for `Barra`. It shipped as **`Barrato`** instead — the term iOS itself uses in its text-formatting controls, and therefore the word an Italian user is actually hunting for. Recognition beats register when the whole point of the menu is discoverability. This follows the same Apple-convention-wins precedent already recorded for `About → Info` and the untranslated `Privacy`. The other three languages take the infinitive and stay consistent with their own existing strings (`Hervorheben`, `Resaltar`, `Surligner`).

**Follow-through on the tip copy.** The German tip body said *eine **Highlight-Farbe*** — worded to mirror the English menu title back when it was untranslated. With the menu now reading `Hervorheben`, that quotation was stale on arrival, so it became *eine **Farbe zum Hervorheben** oder auf Durchstreichen*, which matches both localized labels. Italian needed no change: *colore di evidenziazione* / *barratura* are the natural nouns beside `Evidenzia` / `Barrato`.

**Verified after the fix:** clean build, unit suite **240/240, 0 failed, 0 skipped** (xcresult bundle); `verify-localization.py` passes; catalog at 155 keys. The only compiler diagnostics are two benign `appintentsmetadataprocessor` notes about a missing `AppIntents.framework` dependency, unrelated to this change.

---

## Still open

**Nothing.** F-1 is resolved; the four QA corrections are applied.

The standing residual risk is unchanged and does not close: no native-speaker review, and back-translation catches idiom poorly. Note that DE-1 and DE-2 both back-translated *cleanly* and were caught on other grounds — DE-1 because the phrase looked unfinished, DE-2 because two words in the same sentence collided. That is the third consecutive pass where the most useful finds came from something other than the back-translation itself, which is worth weighing when deciding how much this method is buying.

Unlike the App Store metadata passes, **these strings ship inside the binary** — a correction here needs a new build and a submission, not a metadata edit. That raised the cost of getting F-1 wrong relative to the What's New pass, and is why it was settled now rather than left for after v3.3 is archived.

**No Xcode harvest is needed for any of this.** All seven keys were written into the catalog directly, so the `String(localized:)` calls resolve without the ⌘B round-trip that command-line `xcodebuild` cannot perform. A later harvest in Xcode will find them already present and leave them alone.
