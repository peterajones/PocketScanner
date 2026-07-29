# v3.2 de/it Back-Translation QA Record

**Date:** 2026-07-29
**Scope:** all German and Italian strings in `Localizable.xcstrings` (150 keys) and `InfoPlist.xcstrings` (2 keys) — 308 translated values total.
**Plan:** Task 6 of `docs/superpowers/plans/2026-07-29-localization-de-it.md`

---

## Method, stated plainly

**There was no native-speaker review.** Peter is fluent in Spanish and reads French, but does not read German or Italian. This is the accepted, deliberate trade-off recorded in the v3.2 design spec — "a $4.99 app, not a flawless international product." This document is the honest record of what *was* checked, so nobody later mistakes it for native QA.

What was done:

1. **Back-translation.** Every German and Italian value was independently translated back to English and compared against the source key, looking for meaning drift, register slips, and awkward construction.
2. **Mechanical checks** (below) for the failure modes that can be caught by machine rather than by judgment.
3. **Flagging.** Genuinely low-confidence strings are listed for Peter as *meaning* questions he can answer without reading either language.

What this does **not** establish: that the German and Italian read naturally to a native speaker. Back-translation catches meaning errors well and idiom errors poorly — a stilted-but-accurate string back-translates cleanly. The residual risk is that some strings are correct but wooden.

**Why the residual risk is acceptable:** the in-app strings are overwhelmingly short functional labels (Scan, Sign, Settings, folder actions), where the space for idiom error is small. The higher-idiom copy is the App Store **description**, which is a store-listing field editable at any time without an app release.

---

## Mechanical check results

| Check | Result |
|---|---|
| Coverage — every key, both languages, both catalogs | **PASS** (`scripts/verify-localization.py`, exit 0) |
| Format-specifier parity (type-normalised) | **PASS** — 0 mismatches across 308 values |
| Positional form (`%1$@`) on all keys with 2+ specifiers | **PASS** — all 4 such keys, both languages |
| German formal-register leakage (`Sie`/`Ihre`/`Ihnen`) | **PASS** — 0 hits |
| Italian formal-register leakage (`Lei`/`Vi`) | **PASS** — 0 hits |
| Italian plural gender agreement | **PASS** — `pagina/pagine`, `selezionata/selezionate`, feminine to agree with *pagine* |
| Cross-reference integrity — quoted button labels inside longer strings match that button's actual translation | **PASS** — all 3 such references, both languages |

That last check is worth calling out: three strings quote a button by name (*Save as New*, *Show Folders*, *Sign*). If the button label and the quotation drifted apart, the instruction would tell the user to tap something that doesn't exist. Both languages are internally consistent.

---

## Flagged for Peter

Nine items. None is an outright error — they are judgment calls where a different choice is defensible. Each is phrased as a decision about **meaning or priority**, answerable without reading German or Italian.

### German

**1. `Save as New` → "Als neues sichern" (and `Save page as new` → "Seite als neues sichern")**
German handles this ellipsis worse than English does. "Als neues sichern" is literally "Save as new —" with the noun dropped, which reads incomplete. The unambiguous form is "Als neues **Dokument** sichern", but that's much longer and this is a button.
**Question:** is this button tight on space? If it has room, use the longer explicit form. If not, "Neu sichern" ("Save anew") is short and reads properly.

**2. `Sign` → "Unterschreiben" — 14 characters, in the bottom toolbar**
Confirmed at `DocumentViewerView.swift:569`: `Sign` and `Date` sit in the same bottom `ToolbarItemGroup` alongside Share and ⋯. English "Sign" is 4 characters; German is 14.
**Question:** none needed — this is the single most likely overflow in the app, so just watch it specifically in Task 7. If it clips, "Signieren" (9) is the drop-in alternative. It's slightly more technical and less warm, but it's understood and it fits.

**3. `Sign with your signature` → "Mit deiner Unterschrift unterschreiben"**
This is a **Tip title** (`Tip.swift:27`), so it's a visible heading, not a hidden label. German repeats the same root twice (*Unterschrift* / *unterschreiben*), which is clumsier than the English repetition.
**Question:** may I reword this tip's heading rather than translate it literally? "Dokumente unterschreiben" ("Sign documents") says the same thing cleanly. Same issue in Italian — see #8.

**4. `Couldn't read that` → "Konnte nicht gelesen werden"**
This is the `ContentUnavailableView` title shown when a signature scan fails (`SignatureCaptureView.swift:36`) — a large, prominent empty-state heading. The German is subjectless passive ("Could not be read"), which is stilted at that size.
**Question:** would you prefer the German say something more specific, like "Unterschrift nicht erkannt" ("Signature not recognised")? It's clearer in context, but it diverges from the English wording.

**5. `Tap the layout button…` → "Darstellungstaste"**
A compound I formed rather than one I can attest Apple uses. It's grammatically well-formed and comprehensible, but it may read slightly invented — exactly the "questionable German compound" risk the design spec named.
**Question:** low stakes, Tips-screen body text. Fine to leave; flagging it for the record. Safer alternative: "die Taste für die Darstellung".

**6. `Give this signature a name so you can tell it apart…` → "…unterscheiden kannst"**
Understandable, but the idiomatic German for "tell apart" is *auseinanderhalten*, not *unterscheiden*.
**Recommendation:** change to "auseinanderhalten". Pure improvement, no downside, no length problem. Say the word and I'll apply it.

**7. `Swipe left on any document or folder to remove it.` → "…um es zu entfernen."**
Minor grammar: the pronoun *es* is neuter and agrees with *Dokument*, but *Ordner* is masculine, so strictly it only covers half the sentence's subject. German has no clean neutral pronoun here.
**Recommendation:** restructure to "…um den Eintrag zu entfernen" ("to remove the entry"), which sidesteps gender entirely. Small, safe.

### Italian

**8. `Sign with your signature` → "Firma con la tua firma"**
Same problem as #3 and worse — Italian uses the identical word *firma* for both the verb and the noun, so the tip title reads "Sign with your sign".
**Question:** same as #3 — may I reword to "Firma i tuoi documenti" ("Sign your documents")?

**9. Inconsistent rendering of *markup* / *mark***
`Discard this page's markup?` → "le **annotazioni**", but `Remove this mark?` → "questo **segno**". English uses two related words; Italian currently uses two unrelated ones. German is consistent here (*Markierungen* / *Markierung*).
**Question:** should Italian be consistent too? "Rimuovere questa annotazione?" would align them. I lean yes — the two strings appear in the same feature.

---

## Corrected during QA

**Nothing.** No outright errors were found, so I made no unilateral changes to the translations. Every item above is a judgment call and is waiting on Peter's answer rather than being silently "fixed".

Items #6 and #7 are pure improvements with no trade-off; I'd apply those on a one-word go-ahead. The rest genuinely change tone or wording and are Peter's call.

---

## Deliberate divergences from literal translation (not flagged, recorded for traceability)

These were chosen knowingly and need no decision:

- **`About` → "Info" (it)** — Apple's Italian convention for the Settings *About* row. German uses "Über", also Apple's convention. The two languages differ because Apple's own localizations differ.
- **`Greyscale` → "Grau" (de) / "Grigio" (it)** — shortened from the literal *Graustufen* / *Scala di grigi*. That filter control demonstrably overflowed in both es and fr during v3.0 and was shortened there too.
- **`Scanned Documents` → "Scans" (de) / "Scansioni" (it)** — same reasoning; es shipped as "Escaneos".
- **`Couldn't Import` / `Couldn't Save` / `Couldn't merge` → "Import fehlgeschlagen" / "Sichern fehlgeschlagen" / "Zusammenführen fehlgeschlagen"** — German error titles are conventionally nominal and neutral rather than casual-contracted. Meaning preserved, tone shifted to match platform norms.
- **`Privacy` → "Privacy" (it)** — Apple uses the English word in Italian. Allowlisted in `verify-localization.py`.
