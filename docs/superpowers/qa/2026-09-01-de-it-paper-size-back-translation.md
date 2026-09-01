# Paper Size de/it — Back-Translation QA Record

**Date:** 2026-09-01
**Scope:** the German and Italian strings added by the scan page-size setting — two picker
values, one row label, and one appended footer paragraph.
**Precedent:** `2026-07-29-de-it-back-translation.md`, `2026-08-28-de-it-whats-new-…`,
`2026-08-28-de-it-tips-…`, `2026-08-31-de-it-screenshot-captions-…`

---

## What needed a pass

| String | de | it |
|---|---|---|
| `Page Size` | Seitengröße | Formato pagina |
| `Auto` | Automatisch | Automatico |
| `US Letter` | *(unchanged)* | *(unchanged)* |
| `A4` | *(unchanged)* | *(unchanged)* |
| Scanning footer | first sentence reused, one paragraph appended | same |

`US Letter` and `A4` are **not translations**. They are international paper-size names,
written identically in every language this app ships, and Apple leaves them alone too. They are
allowlisted in `verify-localization.py`, which correctly refused them until told — the check
working, not failing.

**The footer's first sentence was not re-translated.** The new paragraph is *appended to each
shipped translation*, so existing copy cannot drift while adding to it. Verified byte-identical
as a prefix in all four languages.

---

## Back-translation

**`Automatisch` / `Automatico`** → *"Automatic"* in both, which is what Apple uses for an
"Auto" setting in each language rather than a literal four-letter *Auto*.

*(This entry was originally `Detected` / `Erkannt` / `Rilevato`. Peter renamed the option to
"Auto" after the pass; the strings were re-translated and the cross-reference check re-run —
see below.)*

**`Seitengröße`** → *"Page size"*. The correct German compound (*Seite* + *Größe*), not a coined
one.

**`Formato pagina`** → *"Page format"*. Italian uses *formato* for paper size, which is more
idiomatic here than a literal *dimensione*.

**German footer paragraph** — *"Page size sets the paper format of the PDF. Auto keeps the
shape that the scanner found; US Letter and A4 produce exactly this format and add margins if the
scan has a different shape."* Exact. *Papierformat* is the standard German term for paper size.

**Italian footer paragraph** — *"Page format sets the paper format of the PDF. Auto keeps the
shape found by the scanner; US Letter and A4 produce exactly that format and add margins if the
scan has a different shape."* Exact. *formato carta* is the standard term.

Neither footer addresses the user, so the informal register carried by the existing first
sentence (*Du kannst…*) is untouched.

---

## Mechanical check results

| Check | Result |
|---|---|
| Coverage, all languages, both catalogs | **PASS** — `verify-localization.py` exit 0 |
| **Cross-reference: picker labels appear verbatim in the footer that explains them** | **PASS** — 8/8, re-run after the Detected→Auto rename |
| Footer's shipped first sentence preserved byte-for-byte | **PASS** — all four languages |
| Em dashes in new copy | **PASS** — none |
| `String(localized:)` keys all resolve in the catalog | **PASS** |
| Unit suite | **PASS** — 283/283, 0 failed, 0 skipped |

**The cross-reference check is the one that matters here**, and it is a different shape from
previous passes. The footer *names the controls it explains*: it has to say `Seitengröße` and
`Automatisch` because that is what the picker above it says. A translator working from English alone
could easily render the footer's "Page Size" as a description rather than as the label — and the
setting would then explain a control the user cannot find. Verified verbatim in all four languages:

| | label | appears in footer |
|---|---|---|
| de | `Seitengröße`, `Automatisch` | yes |
| it | `Formato pagina`, `Automatico` | yes |
| es | `Tamaño de página`, `Automático` | yes |
| fr | `Format de page`, `Automatique` | yes |

---

## Flagged for Peter

**Nothing.** Second consecutive pass with no judgment calls to rule on.

---

## Still open

**Nothing in this pass.**

The standing residual risk is unchanged: no native-speaker review, and back-translation catches
idiom poorly. As in the previous three passes, the finding that would have mattered was
mechanical — here, whether the footer names the same words as the control it describes.

These strings ship **inside the binary**, so a correction needs a new build and a submission,
not a metadata edit.
