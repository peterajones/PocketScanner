# Simplified Chinese (zh-Hans) — Back-Translation QA Record

**Date:** 2026-09-25
**Scope:** the full in-app string set in Simplified Chinese — 177 `Localizable.xcstrings`
keys plus the 2 user-facing `InfoPlist.xcstrings` usage descriptions. In-app only: no App
Store metadata, no screenshots, no new territory.
**Precedent:** `2026-07-29-de-it-back-translation.md` (the v3.2 full-catalogue pass) and the
short-label records that followed it.

---

## Method, and an honest statement of the risk

Same method as the German and Italian passes: every value independently translated back to
English and compared against the source, then mechanically checked for the failure modes a
machine can catch.

**The residual risk here is higher than for any language shipped so far, and it is worth being
blunt about why.** Spanish and French were reviewed by Peter himself. German and Italian shipped
with no native reviewer, an accepted and recorded risk, but they are close to English in sentence
shape and share vocabulary roots, so a back-translation that reads correctly is decent evidence.
Chinese shares neither. Register, measure words, and the choice between near-synonyms are exactly
where a machine translation goes subtly wrong, and back-translation is weakest at surfacing that.
**Nobody on this project can read the shipped text.** That is a different situation from de/it,
not merely more of the same.

**What makes it acceptable for now:** the app ships in-app only, with no Chinese App Store
listing, so this text reaches only users who have deliberately set their device to Chinese. The
mechanical risks that would break the app rather than read poorly — lost format specifiers,
mismatched control names — are fully checkable, and were checked.

---

## Mechanical check results

| Check | Result |
|---|---|
| Coverage, all five languages, both catalogues | **PASS** — `verify-localization.py` exit 0 |
| Format-specifier parity (`%@`, `%lld`, `%lld°`) across all 177 values | **PASS** — 0 mismatches |
| Traditional-character leakage | **PASS** — none |
| Brand name preserved as Latin "Pocket Scanner" | **PASS** — all 4 keys that contain it |
| Em dashes in new copy | **PASS** — none |
| Cross-reference: text that NAMES a control uses that control's exact term | **PASS** — 22/22 |
| Plural forms compiled correctly (`other` only, no fake singular) | **PASS** — verified in the built `zh-Hans.lproj/Localizable.stringsdict` |
| `zh-Hans.lproj` present in the Release build | **PASS** — 174 strings + stringsdict |
| Unit suite | **PASS** — 322 passed, 0 failed, 0 skipped |
| On-device rendering | **PASS** — launched on an iOS 27 simulator forced to `zh-Hans`; no truncation, correct full-width punctuation |

**The cross-reference check is again the one that matters most.** Several tips instruct the user
to look for a control by name: the Page Size tip must say 页面尺寸 because that is what the
Settings row says, and 自动 because that is what the picker says. A translator working from
English alone would naturally render those as descriptions, and the tip would then explain a
control the user cannot find. Verified for 页面尺寸, 自动, 显示文件夹, 设置, 签名, 存储为新文档
and 主资料库.

**The plural check is new for this language.** Chinese has no singular/plural distinction; CLDR
gives it only `other`, and Xcode's catalogue editor offers no `one` slot for zh-Hans. The
verifier previously demanded both forms for every language, which would have forced a fake
singular into the catalogue purely to satisfy the checker. It now carries a per-language plural
map (`PLURAL_FORMS`), and the built `.stringsdict` confirms Chinese ships `other` alone.

---

## Back-translation, selected

The three longest tips carry the most idiom risk, so they get the closest reading.

**Signature tip** → *"Scan your signature once in Settings, then tap Sign to place it on any
page; you can move it or resize it to fit. For the cleanest cut-out, sign on a blank sheet with a
thick pen; if the camera cannot find the paper's edges up close, take a photo instead and crop
it."* Accurate. 抠图 is the standard term for a cut-out, and 轻点 is Apple's own verb for "tap".

**Markup tip** → *"Select text in a scan, then choose a highlight colour or strikethrough from
the menu that appears. Marks snap to the text Pocket Scanner detects: on printed pages this is
precise; on handwriting or rougher scans, detection is looser, so a highlight may sit a little
high or not line up exactly. Tap a mark to remove it. The scan itself is never altered."*
Accurate, including the concessive structure of the original.

**Page-size footer** → *"New scans will use this filter. You can still change it for any scan.
'Page Size' sets the paper size of the PDF. 'Auto' keeps the shape the scanner found; US Letter
and A4 produce exactly that size, adding margins when the scan is a different shape."* Accurate.
纸张尺寸 is the standard term for paper size.

**Terminology following Apple's own Simplified Chinese:** 存储 for Save (not 保存), 面容 ID for
Face ID, iCloud 云盘 for iCloud Drive, 好 for OK, 轻点 for tap, 资料库 for Library, 石墨色 for
Graphite.

---

## Flagged for Peter

**One judgment call, and it needs your decision only if you disagree.**

### 1. `Color` is one key serving two different screens

`Color` labels both the no-filter scan option and the accent-tint row in Settings — the same
collision already recorded in the localization pipeline notes. English gets away with it.
Chinese does not have one word that is idiomatic in both places:

- 彩色 ("in colour") is the natural name for a scan filter sitting beside 黑白 and 灰度.
- 颜色 ("colour") is the natural label for the Settings row that picks the accent tint.

I chose **颜色**, because it is merely slightly less idiomatic in the filter list, whereas 彩色
would read as plainly wrong on the Settings row. Splitting the key would fix both, but that means
a new catalogue key, an Xcode harvest, and translations in all five languages — disproportionate
for one word. **No action needed unless you want the split.**

### 2. Recorded, not flagged: the signature headers collapse

`Signature`, `Signatures` and `No Signatures` are three keys distinguished in English by
grammatical number. Chinese has no plural, so the first two are both 签名 and the third is
没有签名. This is correct Chinese, not an untranslated string, and the checker's
identical-to-English rule does not apply.

### 3. Recorded, not flagged: `US Letter` and `A4` stay in Latin script

Same reasoning as the other four languages, and they are allowlisted in the verifier. A4 is
written A4 in Chinese; Letter is the name of the US paper size rather than a word to translate.

---

## Still open

**The unreviewable-text problem does not go away by shipping.** If a Chinese-speaking user ever
does send feedback, their wording is worth more than another machine pass.

**If a Chinese App Store listing is ever added**, the keyword field is the part that most needs a
native speaker, and it is the part least amenable to this method. That is a strong argument for
keeping this in-app only until there is a reason to do otherwise.

These strings ship **inside the binary**, so they reach users with the next release, not before.
