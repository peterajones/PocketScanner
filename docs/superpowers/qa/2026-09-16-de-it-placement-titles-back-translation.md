# Placement Titles + Main Library de/it — Back-Translation QA Record

**Date:** 2026-09-16
**Scope:** three in-app labels that shipped untranslated in every language and are now localized:
`Place Signature`, `Place Date` (navigation titles of the placement screen) and `Main Library`
(the top-level destination in the Save and Move menus).
**Precedent:** `2026-09-01-de-it-paper-size-back-translation.md` and earlier records in this folder

---

## Why these strings existed untranslated

All three were stored in a plain `String` and displayed later — `.navigationTitle(title)`,
`Button(dest.name)`, `Text(tree.main.name)`. SwiftUI shows a `String` **variable** verbatim;
only a string *literal* written directly in a view is treated as a localization key. So the text
never went through localization and Xcode never harvested it into the catalog.

`verify-localization.py` could not see them either. Check 5 finds keys by matching
`String(localized: "…")` in the source; text that never passes through that call is invisible to
it. The check passed with these three shipping in English to every language. They were found by
grepping for English literals assigned to `String`-typed UI properties, not by tooling.

`Place Signature` came in with signing (`ad0ad58`), `Place Date` with the date stamp (`8152b21`),
and all three are present in the shipped `build-36` (v3.7).

---

## What needed a pass

| String | es | fr | de | it |
|---|---|---|---|---|
| `Place Signature` | Colocar firma | Placer la signature | Unterschrift platzieren | Posiziona firma |
| `Place Date` | Colocar fecha | Placer la date | Datum platzieren | Posiziona data |
| `Main Library` | Biblioteca principal | Bibliothèque principale | Hauptbibliothek | Libreria principale |

Spanish and French were reviewed by Peter (approved 2026-09-16). German and Italian follow the
standing method below.

---

## Back-translation

**`Unterschrift platzieren` / `Datum platzieren`** → *"Place signature" / "Place date"*. The
nouns are the app's existing terms (`Unterschrift`, `Datum`); *platzieren* is the verb the
shipped signing tip already uses for this action (*"um sie auf einer beliebigen Seite zu
platzieren"*), so the title and the tip agree.

**`Posiziona firma` / `Posiziona data`** → *"Position signature" / "Position date"*. Imperative,
matching the existing Italian label style (`Aggiungi firma`, `Scegli una firma`).

**`Hauptbibliothek`** → *"Main library"*. **`Libreria principale`** → *"Main library"*. Both are
the exact terms the shipped empty-folder hint already uses (*"…move existing ones in from the main
library"*), so the menu entry and the hint that refers to it now name the same thing.

---

## Mechanical check results

| Check | Result |
|---|---|
| Coverage, all languages, both catalogs | **PASS** — `verify-localization.py` exit 0 |
| Check 5 actually covers the new keys (not just passes) | **PASS** — both placement keys and `Main Library` found by its regex; removing one from the catalog would fail |
| Cross-reference: `Main Library` term matches the existing empty-folder hint | **PASS** — 4/4 languages |
| Cross-reference: placement verb matches the signing tip | **PASS** de/es/fr; **it differs, deliberately** — see below |
| Catalog written by script changes nothing else | **PASS** — additions only, zero deleted lines; the file round-trips byte-identical |
| Em dashes in new copy | **PASS** — none |
| Formal register (`Sie`/`Ihr`, `Lei`/`Suo`) | **PASS** — none; the labels address no one |
| Unit suite | recorded in the commit |

---

## Flagged for Peter

**Nothing that needs a decision.**

**Recorded, not flagged:** the Italian signing tip says *"per inserirla su qualsiasi pagina"*
("to insert it on any page"), while the title uses *Posiziona* ("position"). The tip is
descriptive prose and does not quote the title, so the cross-reference rule (a text that
**names** a control must match it verbatim) does not apply. *Posiziona* describes what the screen
actually asks for, dragging and resizing into place, better than *Inserisci*.

---

## Still open

**The blind spot is not closed, only these instances.** Any future UI text held in a `String`
and displayed later bypasses both Xcode's harvest and check 5. A grep of the current source for
English literals assigned to `String`-typed UI properties found no further user-visible cases
(`DemoSeeder` names are Debug-only demo content; a folder's own name correctly stays verbatim).

These strings ship **inside the binary**, so they reach users with the next build, not before.
