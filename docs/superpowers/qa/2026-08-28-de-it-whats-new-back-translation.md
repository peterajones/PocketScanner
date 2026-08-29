# v3.3 de/it What's New — Back-Translation QA Record

**Date:** 2026-08-28
**Scope:** the German and Italian v3.3 release notes — `marketing/app-store-metadata/{de,it}/whats_new.txt`, 4 paragraphs each.
**Precedent:** `docs/superpowers/qa/2026-07-29-de-it-back-translation.md` (v3.2 in-app strings)

---

## Method, stated plainly

Same method as the v3.2 record, same accepted trade-off: **no native-speaker review.** Every German and Italian sentence was independently translated back to English and compared against the English source, then mechanically checked for the failure modes a machine can catch.

**The residual risk is higher here than it was for v3.2's in-app strings, and the reason is worth stating.** That pass covered 308 values that were overwhelmingly short functional labels — *Scan*, *Settings*, folder actions — where the space for idiom error is small. Release notes are the opposite: continuous marketing prose, the highest-idiom copy the app ships apart from the description. Back-translation catches meaning errors well and idiom errors poorly, and idiom is most of the risk in this particular text.

**Why it is still acceptable:** What's New is store-listing metadata, editable at any time without an app release. A wooden sentence here is fixable in minutes, unlike a wooden button label frozen into a binary.

**Not in scope:** the closing sign-off paragraph in each language is carried over verbatim from v3.2, which shipped and was approved. It was not re-reviewed. One consequence of that shows up in flag #1 below.

---

## Mechanical check results

| Check | Result |
|---|---|
| Character limits, all 7 locales | **PASS** (`scripts/verify-metadata.py`, exit 0) — de 723, it 769 of 4000 |
| German formal-register leakage (`Sie`/`Ihre`/`Ihren`/`Ihnen`/`Ihrer`) | **PASS** — 0 hits; informal `du` present, matching the app |
| Italian formal-register leakage (`Lei`/`Vi`/`Suo`/`Sua`) | **PASS** — 0 hits; informal `sai`/`tuoi` present, matching the app |
| Quoted prompts match `Localizable.xcstrings` exactly | **PASS** — all 6 (`Dieses Dokument löschen?`, `Diese Markierung entfernen?`, `Abbrechen`; `Eliminare questo documento?`, `Rimuovere questa annotazione?`, `Annulla`) |
| Sign-off paragraph unchanged from approved v3.2 text | **PASS** — byte-identical per locale |
| Vocabulary collision within the same text | **FAIL — see flag #1** (fixed; re-checked below) |

The quoted-prompt check is the one that matters most here. Release notes that quote a dialog by name are telling users to look for exact words on screen; if the quotation and the actual button drift apart, the notes describe an app the user doesn't have. Both languages are internally consistent, and the Italian `Rimuovere questa annotazione?` is itself a v3.2 QA correction (flag #5 of the previous record) — so the notes inherit the fixed wording, not the shipped-then-changed wording.

---

## Flagged for Peter

Seven items. One is a genuine error; the rest are judgment calls. Each is phrased as a decision about **meaning or tone**, answerable without reading German or Italian.

### Italian

**1. `tracciamento` collides with the privacy promise — recommend changing (it)**

The fourth paragraph says *"una correzione interna al **tracciamento** delle pagine"* ("an internal fix to page tracking"). Two lines later the sign-off says *"nessun **tracciamento**"* — **no tracking**, the privacy claim.

In Italian, *tracciamento* carries the surveillance sense much more strongly than English "tracking" does. The notes therefore read as announcing a tracking improvement and then promising no tracking, in the same short text. English is safe from this because "page tracking" and "no tracking" sit far enough apart in register; Italian is not.

This is my error, from translating the English phrase literally without checking it against the sign-off I was carrying over unreviewed.

**Recommendation:** drop the mechanism entirely — *"C'è anche una correzione interna nel visualizzatore di documenti."* ("There is also an internal fix in the document viewer.") The English is deliberately vague on this point anyway, since the underlying fix has no user-visible symptom, so nothing is lost by being vaguer still. **Strong recommend, no downside.**

**2. `versione di pulizia` reads as physical cleaning (it)**

Opening line. *Pulizia* is cleaning in the scrubbing sense; there is no established Italian idiom matching English "clean-up release."

**Question:** may I use *"Una versione di manutenzione"* ("a maintenance release")? It is the conventional Italian phrasing and unambiguous. It is slightly more formal and less friendly than your "sort of clean-up release" framing — that's the trade.

**3. `facendo sembrare una domanda normale una strada senza ritorno` is hard to parse (it)**

Two consecutive unmarked nouns after *far sembrare* make an Italian reader work out which is the subject and which the predicate. It is grammatical but clumsy, and it is the weakest sentence in either language. Separately, the settled Italian idiom is *punto di non ritorno*, not *strada senza ritorno*.

**Recommendation:** split the clause — *"...mostravano solo l'opzione di eliminazione: una domanda normale sembrava così un punto di non ritorno."* Cleaner and idiomatic. Say the word.

**4. `richieste` is vague for a dialog (it)**

*"Annulla è tornato in due richieste"* — *richiesta* alone means "request", not specifically a confirmation prompt.

**Recommendation:** *"in due richieste di conferma"*. Minor, safe, two words.

### German

**5. `Aufräum-Version` is a compound I formed, not one I can attest (de)**

Opening line. Grammatically well-formed and comprehensible, but likely to read invented — the same risk category as *Darstellungstaste* in the v3.2 record, which you chose to leave.

**Question:** the natural German move is a verb rather than a noun — *"Diese Version räumt auf – vor allem bei den Rückfragen, die vor dem Löschen erscheinen."* ("This version tidies up — above all in the prompts that appear before deleting.") That restructures the sentence rather than translating it. May I?

**6. `zählt die Seiten mit` says the wrong thing (de), and the English invites it**

*Mitzählen* means to keep a running tally, which is not what the prompt does — it states a number, once.

But the drift starts in the English: **"The confirmation counts the pages"** is loose there too. It reads fine as English idiom and translates badly into every language.

**Recommendation:** fix the source, then all seven follow. English → *"The confirmation tells you how many pages, so you always know exactly what is about to go."* German → *"Die Rückfrage nennt die Anzahl der Seiten"*. Italian has the identical problem (*"La conferma conta le pagine"*) → *"La conferma indica quante pagine"*. Spanish and French should be checked for the same construction if you take this one.

**7. `Seitenverfolgung` — same invented-compound risk (de)**

*Verfolgung* is pursuit; the compound is comprehensible but technical-sounding. If flag #1's fix is taken for Italian, the symmetric fix here is to drop the mechanism too: *"Dazu kommt eine interne Korrektur in der Dokumentanzeige."*

**Note:** German has no *tracciamento* collision — *Tracking* in the sign-off is the English loanword and does not overlap with *Verfolgung*. So this is tone only, not a contradiction, and it can be left if you'd rather keep the two languages parallel in detail.

---

## Corrected during QA

**Peter ruled "apply all of them" on 2026-08-28.** All seven applied in a single pass.

| Flag | Lang | Was | Now |
|---|---|---|---|
| #1 | it | …correzione interna al **tracciamento delle pagine** nel visualizzatore… | C'è anche una correzione interna nel visualizzatore di documenti. |
| #2 | it | Una versione di **pulizia** | Una versione di **manutenzione** |
| #3 | it | …facendo sembrare una domanda normale una **strada** senza ritorno. | …**: una domanda normale sembrava così un punto di non ritorno.** |
| #4 | it | in due **richieste** in cui era sparito | in due **richieste di conferma** in cui era sparito |
| #5 | de | Eine **Aufräum-Version**, ganz auf die Momente… ausgerichtet. | **Diese Version räumt auf** – vor allem bei den Rückfragen, die vor dem Löschen erscheinen. |
| #6 | de | Die Rückfrage **zählt die Seiten mit** | Die Rückfrage **nennt die Anzahl der Seiten** |
| #7 | de | eine interne Korrektur **der Seitenverfolgung** in der Dokumentanzeige | eine interne Korrektur in der Dokumentanzeige |

**Flag #6 also changed the English source and propagated to all seven locales:**

| Locale | Was | Now |
|---|---|---|
| en | The confirmation **counts the pages** | The confirmation **tells you how many pages** |
| es, es-MX | La confirmación **cuenta las páginas** | La confirmación **te dice cuántas páginas son** |
| fr, fr-CA | La confirmation **compte les pages** | La confirmation **indique le nombre de pages** |
| de | (see #6 above) | |
| it | La conferma **conta le pagine** | La conferma **indica il numero di pagine** |

**One refinement on the Italian half of #6.** The flag proposed *"La conferma indica quante pagine"*, which is elliptical — it needs a verb to close. Applied as *"indica il numero di pagine"* instead, which is complete and parallel to the French *"indique le nombre de pages"*. Same meaning, better Italian.

### Verification after applying

| Check | Result |
|---|---|
| Character limits, all 7 locales | **PASS** — `verify-metadata.py`, exit 0; en 690, de 719, it 762 |
| `tracciamento` in the Italian notes | **PASS** — 1 occurrence, the sign-off's privacy claim only. The collision is gone. |
| German formal-register leakage | **PASS** — 0 hits |
| Italian formal-register leakage | **PASS** — 0 hits |
| All 6 quoted prompts still match `Localizable.xcstrings` | **PASS** |
| Sign-off paragraph still byte-identical to approved v3.2 text | **PASS** — all 7 locales |

## Addendum — 2026-08-29: the markup-menu line

After this record was written, the markup menu's `Highlight` / `Strikethrough` titles were localized (see `2026-08-28-de-it-tips-back-translation.md`, F-1). That is user-visible in four languages, so one sentence was added to the release notes.

**English was deliberately left untouched.** The bug never affected English users — they always saw correct English labels — so an English note would describe something the reader never experienced. What's New is per-locale metadata; there is no requirement that the seven read alike, and Apple's own notes routinely diverge.

| Locale | Added paragraph |
|---|---|
| de | Die Befehle zum Hervorheben und Durchstreichen erscheinen jetzt auf Deutsch – bisher waren sie als Einzige englisch geblieben. |
| it | I comandi Evidenzia e Barrato ora compaiono in italiano: erano rimasti gli unici in inglese. |
| es, es-MX | Las opciones Resaltar y Tachar ahora aparecen en español: eran las únicas que seguían en inglés. |
| fr, fr-CA | Les commandes Surligner et Barrer s'affichent désormais en français : elles étaient les seules restées en anglais. |

Back-translation of the de line: *"The commands for highlighting and striking through now appear in German — until now they were the only ones that had stayed English."* Italian: *"The Evidenzia and Barrato commands now appear in Italian: they were the only ones left in English."* Both are one sentence and mildly self-deprecating, which is the honest framing for a bug fix and reads better than dressing it as a feature.

**Checks:**

| Check | Result |
|---|---|
| Cross-reference — every quoted label matches its shipped catalog value | **PASS** — 12/12 across the 6 locales |
| Character limits | **PASS** — de 847, it 856, fr-CA 912 of 4000 |
| Apostrophe convention | **PASS** — see below |

**Apostrophe note, worth recording.** The insertion aborted on the first attempt for `fr`: the anchor paragraph did not match because the draft used a curly apostrophe (`’`) where these files use straight (`'`) throughout — fr had 5 straight and 0 curly before the edit. Had the script matched loosely instead of asserting the anchor, it would have written the set's only mixed-convention file. Note this differs from `Localizable.xcstrings`, where the tip bodies legitimately use curly apostrophes; the convention is per-file, not global.

---

## Still open

**Nothing.** All seven flags applied and verified, and the 2026-08-29 addendum is complete.

The residual risk stated under *Method* is unchanged and does not close: these notes have had no native-speaker review, and back-translation catches idiom poorly. Flags #2 and #5 in particular replaced constructions that back-translated *cleanly* — they were caught because the compounds looked invented, not because the meaning was wrong. There may be others of that kind still in the text. What's New is editable without an app release, which is why that risk is acceptable rather than blocking.
