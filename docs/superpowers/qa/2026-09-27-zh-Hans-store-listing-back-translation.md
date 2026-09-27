# Simplified Chinese (zh-Hans) App Store Listing - Back-Translation QA Record

**Date:** 2026-09-27
**Scope:** the zh-Hans store listing for v3.9 (38): name, subtitle, keywords, promotional text,
What's New and description, in `marketing/app-store-metadata/zh-Hans/`.
**Precedent:** `2026-09-25-zh-Hans-back-translation.md` (the in-app catalogue). The same risk
applies and is larger here: **nobody on this project can read Chinese**, and this text is the
first thing a Chinese searcher sees.

---

## Why a store listing now

The 2026-09-25 decision kept Chinese in-app only because mainland China was believed closed
(ICP filing). That was wrong: the app is live in the China storefront at ¥38 and App Store
Connect shows the ICP Filing Number as optional. See `docs/FutureEnhancements.md`.

## Keyword research method

Terms come from **Apple's own China-storefront search autocomplete**
(`search.itunes.apple.com/WebObjects/MZSearchHints.woa/wa/hints`, header
`X-Apple-Store-Front: 143465-19,29`), queried 2026-09-27 with seed terms. A term Apple suggests
is a term people type; the endpoint gives no volumes, so this ranks nothing, it only filters out
terms nobody searches.

Findings that shaped the field:

- **扫描仪 (scanner), 文档扫描 (document scan), PDF扫描, 文件扫描, 扫描件 (scanned copy)** all
  autocomplete, and competitors' names are built from them.
- **买断 / 买断制 ("buy-out", one-time purchase)** autocompletes. **无订阅 (no subscription)
  returns nothing.** So the Chinese equivalent of the `no subscription` keyword is 买断, not a
  literal translation.
- **图片转文字 (image to text), 文字识别 (text recognition), OCR** are heavily searched and
  crowded.
- **电子签名 (e-signature), 合同 (contract), 收据 (receipt), 发票 (fapiao/invoice), 证件 (ID
  documents)** all autocomplete, several with scanning completions (合同扫描, 证件扫描,
  收据扫描仪).
- **Avoided: 扫描全能王 and 扫描王.** 扫描全能王 is CamScanner's Chinese name, and 扫描王 is its
  common short form. Same rule as `scanner pro` in English: no competitor names.
- **Avoided: 免费 (free).** Autocompletes everywhere, but the app is paid.
- **Note: an app called 口袋扫描王 ("Pocket Scan King") exists.** 口袋扫描 is the literal
  translation of "Pocket Scanner", which is one more reason the name keeps the Latin brand.

Separators: plain ASCII commas. RadASO's tests found Chinese full-width punctuation (`，`) does
NOT separate keywords, and that Chinese is indexed even without separators; commas are the safe
choice.

---

## Back-translations

| Field | Chinese | English back-translation |
|---|---|---|
| Name (28/30) | Pocket Scanner - 扫描仪 PDF文档扫描 | Pocket Scanner - Scanner, PDF Document Scanning |
| Subtitle (14/30) | 无订阅无广告，OCR文字识别 | No subscription, no ads, OCR text recognition |
| Promo (61/170) | 把纸质或屏幕上的文档扫描成可搜索的 PDF，全部在设备上完成。扫描、整理、搜索每一页的内容，现在还能直接在手机上签署文档。 | Scan paper or on-screen documents into searchable PDFs, all done on the device. Scan, organize, search the content of every page, and now you can also sign documents right on your phone. |

**Name.** The only locale with a name other than "Pocket Scanner". The name is the heaviest-weighted
search field and Chinese searchers type Chinese, so the Latin brand alone would index for nothing
they search. The Latin brand leads, matching the in-app text, which keeps "Pocket Scanner" in Latin
everywhere.

**Subtitle.** Carries the same claim as every other locale (no subscriptions, no ads) plus
"OCR text recognition", because Chinese subtitle characters are search-indexed and the claim alone
uses 6 of 30. Same 2.3.7 exposure as the other locales' subtitles, contested and won in v3.2.

**Keywords (89/100):**

| Term | Meaning | Term | Meaning |
|---|---|---|---|
| 文件 | file | 手机 | mobile phone |
| 扫描件 | scanned copy | 拍照 | take a photo |
| 图片转文字 | image to text | 转换 | convert |
| 电子签名 | e-signature | 提取 | extract |
| 签字 | sign (by hand) | 买断 | one-time purchase |
| 合同 | contract | 无纸化 | paperless |
| 收据 | receipt | icloud | iCloud |
| 发票 | fapiao / invoice | 云盘 | cloud drive (Apple's term in 'iCloud 云盘') |
| 证件 | ID documents | 笔记 | notes |
| 身份证 | national ID card | 标注 | markup / annotate |
| 票据 | bills / receipts | 离线 | offline |
| 试卷 | exam paper / worksheet | 隐私 | privacy |
| 书籍 | books | 搜索 | search |

Words already in the name or subtitle (扫描, 扫描仪, 文档, PDF, OCR, 文字识别) are not repeated.

**What's New:** "Pocket Scanner now supports Simplified Chinese. All the text in the app, and the
description on the App Store, now have a Simplified Chinese version. As always: no subscriptions,
no ads, no tracking, and nothing stored on our servers. Buy once, use forever. Thanks for using
Pocket Scanner."

**Description:** a faithful translation of `en/description.txt`, section for section and bullet
for bullet (17 bullets in each). Back-translation reads as the English source. Deliberate choices:

- Filter names are quoted exactly as the app shows them: “颜色”“灰度”“黑白”“照片”. The app's
  Color filter is 颜色 ("colour"), where 彩色 ("in colour") would be the more natural label.
  That is an in-app wording question, recorded here and not changed.
- Face ID is 面容 ID and iCloud Drive is iCloud 云盘, Apple's own Chinese names, matching the app.
- "Pay once, scan forever" becomes 一次购买，永久使用 ("buy once, use forever").

## Mechanical checks

| Check | Result |
|---|---|
| ASC limits, all 8 locales | **PASS** - `scripts/verify-metadata.py` |
| Em or en dashes | **PASS** - none |
| Brand kept in Latin | **PASS** |
| Description bullet parity with en | **PASS** - 17/17 |

---

## Screenshot captions (`marketing/app-preview/captions/zh-Hans.tsv`)

Seven framed shots in `marketing/app-preview/v3.9/Stills/zh-Hans/`, same content and order as
the live v3.4 set, captured 2026-09-27 on an iPhone 17 Pro simulator (iOS 26.2, Release build
3.9 (38), accent set to Blue to match the other locales' pre-brand-colour shots).

| # | Chinese | English back-translation | English source |
|---|---|---|---|
| 1 | 扫描任何文档：/ 收据、合同，统统搞定 | Scan any document: / receipts, contracts, all handled | Scan any document: / receipts, contracts, anything |
| 2 | 在扫描件中搜索 | Search in your scans | Search inside your scans |
| 3 | 收到电子合同？/ 签名加日期，无需打印机 | Received an electronic contract? / Signature plus date, no printer needed | Emailed a contract? / Sign and date it, no printer |
| 4 | 已有 PDF？/ 轻点一下即可导入 | Already have a PDF? / Import it with one tap | Already have a PDF? / Import it in a tap |
| 5 | 保存你的签名 / 轻点即可签署 | Save your signature / sign with a tap | Save your signature / sign in a tap |
| 6 | 添加日期 / 任选你需要的格式 | Add a date / pick any format you need | Date it / in any format you need |
| 7 | 井井有条 / 用文件夹整理一切 | Neat and orderly / organize everything with folders | Stay organized / with folders |

Caption 2 is the app's own tip title for the same feature. Shot 7's caption sits below the grid,
not under the title: the current app places the grid directly under the large title, leaving no
gap there. Demo library: `marketing/translations/Document Scanner ZH` (the 7 English PDFs,
byte-identical, with Chinese folder and file names).
