# Card scan prompts: back-translation QA (de, it, zh-Hans)

2026-11-01. FR/ES are reviewed by Peter and are not covered here. Six new strings in
`Localizable.xcstrings`, shown in two prompts after a wallet-card-shaped capture (v4.0 build 40).
Each row is the shipped text, then a literal English back-translation.

## Prompt 1: one card side captured

| Key | de | it | zh-Hans |
|---|---|---|---|
| Scan the other side? | Auch die Rückseite scannen? → *Also scan the back side?* | Scansionare anche il retro? → *Scan the back too?* | 也扫描背面吗？ → *Also scan the back?* |
| Scan Back | Rückseite scannen → *Scan back side* | Scansiona retro → *Scan back* | 扫描背面 → *Scan the back* |
| Continue | Weiter → *Next / Continue* | Continua → *Continue* | 继续 → *Continue* |

## Prompt 2: front and back captured together

| Key | de | it | zh-Hans |
|---|---|---|---|
| Combine as front and back? | Als Vorder- und Rückseite kombinieren? → *Combine as front and back side?* | Unire come fronte e retro? → *Join as front and back?* | 将正面和背面合并为一页？ → *Merge the front and back into one page?* |
| Combine | Kombinieren → *Combine* | Unisci → *Join / Merge* | 合并 → *Merge* |
| Keep as Two Pages | Als zwei Seiten behalten → *Keep as two pages* | Mantieni due pagine → *Keep two pages* | 保留为两页 → *Keep as two pages* |

## Findings

- **Changed: zh-Hans title.** Was 合并为正面和背面？ → *Merge into front and back?*, which reads as if
  one thing is being split. Now 将正面和背面合并为一页？ → *Merge the front and back into one page?*,
  natural word order and clearer than the English about what Combine does.
- **Kept: "Combine" collides with "Merge" in it and zh-Hans.** Unisci and 合并 are also the labels
  for merging two documents. The two never appear together, and in this prompt the alternative button
  (Mantieni due pagine / 保留为两页) makes the meaning plain. German keeps them apart already
  (Kombinieren vs Zusammenführen).
- **Kept: German "Seite" means both page and side.** "Als zwei Seiten behalten" could be read as
  *keep as two sides*; either reading means "don't combine", so it is not misleading. Same term the
  app uses for pages everywhere else.
- **Consistency:** Italian drops the article on buttons as the app already does ("Scansiona
  documento"); German uses no pronoun here, so the app's du-form is not in play.

`scripts/verify-localization.py` passes after the change.
