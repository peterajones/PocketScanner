# v3.4 Screenshot Captions de/it — Back-Translation QA Record

**Date:** 2026-08-31
**Scope:** the German and Italian caption copy in `marketing/app-preview/captions/{de,it}.tsv`
for the v3.4 gallery.
**Precedent:** `docs/superpowers/qa/2026-07-29-de-it-back-translation.md`,
`…/2026-08-28-de-it-whats-new-back-translation.md`,
`…/2026-08-28-de-it-tips-back-translation.md`

---

## What actually needed a pass

Smaller than the seven-shot gallery suggests. Of the four captions per language:

| Shot | Copy | Needs QA? |
|---|---|---|
| 1 | new for v3.4 | **yes — 2 lines × 2 languages** |
| 2 | verbatim from `Localizable.xcstrings` | no — covered by the 2026-07-29 pass |
| 3, 4 | unchanged from what shipped in v3.0–v3.2 | no — already shipped and reviewed |

**Shot 2 is worth calling out as a pattern, not just an exemption.** Its caption is the app's
own tip title, copied character-for-character rather than translated afresh:

| | caption | app string |
|---|---|---|
| de | `In deinen Scans suchen` | `In deinen Scans suchen` |
| it | `Cerca nelle tue scansioni` | `Cerca nelle tue scansioni` |

Verified equal by script. That means the screenshot and the app say the same words, not two
translations of one idea — and it inherits QA already done instead of creating new risk. Worth
reaching for again: **when a caption describes a feature the app already names, take the app's
string.**

So this pass covers **four values**: two German lines and two Italian lines.

---

## Back-translation

### German — shot 1

> `Jedes Dokument scannen:` / `Belege, Verträge, alles`

Back-translates as *"Scan every document: receipts, contracts, everything."* Source is
*"Scan any document: receipts, contracts, anything."*

*Jedes* is literally "every" rather than "any", which in this construction carries the same
sense — the alternative, *beliebige Dokumente*, is stiffer and longer for no gain. The infinitive
(*scannen*) matches how German captions already read in this set (`Unterschreiben ohne Drucker`,
and the retired `Direkt vom Bildschirm scannen`), and matches the register the app itself uses.

Note the capitalisation difference from English is **correct, not a slip**: English line 2 runs on
in lower case after the colon, German cannot, because *Belege* and *Verträge* are nouns. *alles*
stays lower case as a pronoun. The visual parallel between the two languages breaks slightly and
should not be "fixed".

### Italian — shot 1

> `Scansiona qualsiasi documento:` / `scontrini, contratti, tutto`

Back-translates as *"Scan any document: receipts, contracts, everything."* — an exact match for
the source. *Scansiona* is the informal imperative, consistent with the existing Italian captions
(`Scansiona dallo schermo`) and with the app's informal *tu*. Lower-case line 2 is correct in
Italian.

---

## Mechanical check results

| Check | Result |
|---|---|
| Register — de infinitive, it informal imperative | **PASS** — matches both the app and the retired captions |
| Shot 2 caption identical to the app's own string | **PASS** — verified by script, both languages |
| **Cross-reference: caption nouns vs the folder names visible on screen** | **PASS** — see below |
| Em dashes in de/it caption copy | **PASS** — none |
| Overflow at the chosen font sizes | **PASS** — inspected rendered output; it is the tightest and clears the bezel |
| Rendered dimensions | **PASS** — all 49 stills 1290×2796 |

**The cross-reference check is the one that earned its place here.** Shot 1's line 2 lists
document *types*, and shot 4 in the same gallery shows the demo library's actual folders. If those
disagreed, the gallery would name a thing in one image and call it something else two images
later:

| caption word | folder on screen in shot 4 |
|---|---|
| de `Belege` | `Belege` |
| de `Verträge` | `Arbeit/Verträge` |
| it `scontrini` | `Scontrini` |
| it `contratti` | `Lavoro/Contratti` |

All four match. This is the same class of failure as the Italian tip that said *marcature* where
the app says *annotazione* — caught there after the fact, checked here before shipping.

---

## Flagged for Peter

**Nothing.** No item in this pass reached the threshold of a judgment call worth his ruling.

That is a first across four passes, and the reason is structural rather than luck: three of the
four captions per language were **not newly translated at all** — two were carried forward from
shipped copy and one was lifted from the string catalog. The only genuinely new copy was six words
per language.

---

## Addendum — the v3.4 release notes

Written after this record, so covered here rather than in a separate one. One new sentence per
language, ahead of the sign-off paragraph which is carried over byte-identical from v3.3.

| | new line | back-translation |
|---|---|---|
| de | Ein kleines Wartungsupdate mit internen Verbesserungen. | *A small maintenance update with internal improvements.* |
| it | Un piccolo aggiornamento di manutenzione con migliorie interne. | *A small maintenance update with internal improvements.* |

Both are exact. *Wartungsupdate* and *aggiornamento di manutenzione* are the conventional terms
in each language rather than literal renderings of "maintenance release". No flags.

**Checks:** character limits pass in all 7 locales (207–251 of 4000); the sign-off is
byte-identical to the shipped v3.3 text in every locale; no em dashes anywhere in the set.

**Worth recording about the copy itself, not its translation:** v3.4's only user-visible change
is the App Store gallery, and release notes cannot refer to the store listing. So these notes
honestly describe a release that reads as a nothing-release to anyone who opens them. That is the
accepted cost of shipping the gallery fix now — including removing a real bank's trademark from
the live listing — rather than a copywriting problem to solve.

---

## Still open

**Nothing in this pass.**

The standing residual risk is unchanged: no native-speaker review, and back-translation catches
idiom poorly. It is worth noting that it did not catch anything here either — the useful checks
were the cross-reference against on-screen folder names and the equality check against the app's
own string, both mechanical. That is now the fourth consecutive pass where the mechanical checks
found more than the back-translation did, which is worth weighing when deciding what this ritual
should actually consist of next time.

Unlike the What's New copy, **these strings are baked into PNGs**. Correcting one means
re-rendering and re-uploading that locale's screenshot in App Store Connect, not editing a text
field — so the cost of a late fix sits between the metadata passes and the in-binary tip strings.
