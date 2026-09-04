# Appearance Settings de/it — Back-Translation QA Record

**Date:** 2026-09-04
**Scope:** every string added by the two appearance branches — the App Appearance section, the
Theme picker (System / Light / Dark), its footer, and the four accent tint names.
**Precedent:** the five earlier de/it passes, most recently
`2026-09-01-de-it-paper-size-back-translation.md`

---

## What is different about this pass

**Peter found the defect before this pass ran.** He reported German and Italian showing English
for the colour row and Purple, which was correct — and the cause was not translation quality but
a script of mine that aborted partway through, leaving `Colour` and `Purple` in the catalog with
**no localizations at all**. Every language fell back to the English source.

`verify-localization.py` did not catch it, and that is worth recording: the check tests that a
localization is not *identical to the source*, but these keys had no localizations to compare.
An entry with an empty `localizations` dictionary passes every existing check.

**Recommendation for the verifier:** fail a key whose `localizations` is empty or missing a
required language outright, rather than only comparing values that exist. Logged rather than
done, since it is a change to shared tooling and belongs in its own commit.

---

## Back-translation

**`App-Erscheinungsbild` / `Aspetto dell'app`** → *"App appearance"* in both. Exact.
*Erscheinungsbild* is the word Apple uses in German iOS Settings for this concept.

**`Design` (de) / `Tema` (it)** for **Theme**. German does not use *Thema* here — that means a
topic or subject, not a visual theme. *Design* is what Apple uses in German iOS for the
light/dark control, so it is both correct and familiar. Italian *Tema* is direct.

**`Hell` / `Dunkel`** and **`Chiaro` / `Scuro`** → *"Light"* / *"Dark"*. Exact, and these are
Apple's own terms in both languages.

**`System`** is identical in German (*das System*) and is what Apple uses in the German Settings
app for the follow-the-system option. Allowlisted in `verify-localization.py` rather than
force-translated.

**Footer, German** — *"System follows the light/dark setting of your iPhone."* Exact, informal
*deines* matching the app's register.

**Footer, Italian** — *"System follows the light or dark setting of your iPhone."* Exact,
informal *tuo*.

### Tint names

**`Lila`** for Purple, **not** `Violett`. This was Peter's call and it is the right one. *Violett*
is more formal and denotes specifically the blue-violet end of the spectrum; *Lila* is the
everyday German word, and this is a UI label people scan, not a colour match. (Peter also raised
`Dunkelrot` — that is *dark red*, so it was not used.)

**`Graphit` / `Grafite`** → *"Graphite"*. Both are the standard word for the mineral and for the
finish Apple names on its own hardware.

**`Blau` / `Blu`** and **`Grün` / `Verde`** are **not new**. Those keys already existed as
highlight colour names with identical translations, and are reused rather than duplicated — two
keys for one word is two things to keep in sync forever. Their comments were widened to say they
serve both uses.

**`Farbe` / `Colore`** for the Color row is likewise the *existing* `Color` key, already
translated as the scan-filter name. The duplicate `Colour` key was removed.

---

## Mechanical check results

| Check | Result |
|---|---|
| Coverage, all languages, both catalogs | **PASS** — `verify-localization.py` exit 0 |
| Every `String(localized:)` key in Swift resolves in the catalog | **PASS** |
| **Cross-reference: the footer names the picker option as labelled** | **PASS** — 4/4 |
| No key has an empty `localizations` dictionary | **PASS** — checked explicitly after the defect |
| Em dashes in new strings | **PASS** — none |
| Unit suite | **PASS** — 322/322, 0 failed |

The cross-reference check again did the useful work. The footer says *"System follows your
iPhone's light or dark setting"* and therefore has to use the same word as the picker option
above it: a German footer saying "System" while the option said something else would describe a
control that is not there. Verified in all four languages.

---

## Flagged for Peter

**Nothing.** Fourth consecutive pass with no judgment calls — though this one is qualified: the
defect that mattered was found by Peter on a device *before* the pass, not by the pass.

---

## Still open

**One tooling improvement, not blocking:** `verify-localization.py` should fail a key with an
empty or partial `localizations` dictionary. It currently only compares values that exist, which
is why two entirely unlocalized strings shipped past it.

The standing residual risk is unchanged: no native-speaker review, and back-translation catches
idiom poorly. These strings ship **inside the binary**, so a correction needs a new build and a
submission.
