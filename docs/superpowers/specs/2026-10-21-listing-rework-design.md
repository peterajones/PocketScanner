# Listing Rework + Featuring Nomination — Design

**Status:** Draft 2026-10-21, from a brainstorm with Peter. Project 3 of the 2026-10-20 strategy
session (`docs/FutureEnhancements.md`); ships with **v4.0 (39)**, the Instant Scan release.

## Why

Analytics for Jul 22 – Oct 19: 1.33K impressions → 55 page views → 3 downloads. Search is almost the
only way strangers arrive (48 of 55 page views). The app is **invisible, not unconvincing**. Of the
few people who see the page, about 1 in 18 buys.

Two levers fix visibility:

1. **Search.** The page has to match the words people actually type.
2. **A Featuring Nomination.** This is the only route to new users that doesn't depend on search. Apple
   needs **at least 3 weeks' notice** (Peter, 2026-10-21; the metadata doc says 2 weeks and
   must be corrected).

## What Peter told us (the source material)

- **How he sells it in person** (about 3 minutes of attention): first, how fast it is to scan *anything*.
  Second, how he organizes scans in nested folders. Third, signing a document. Last, Settings.
- **What people react to in Settings:** the Face ID lock, iCloud on or off, and the filter options. The reaction
  is "appreciation for the thought behind the app", even from people who will never use these.
- **How a stranger searches:** "I need to scan something fast to take with me". They search for **the
  thing**: a tax form, an ID, a prescription, a handwritten note, medical instructions, "the girl who
  gives you her phone number". That last one becomes the napkin line in the description.
- **Name:** he wants "Scan Anything Fast" in it.
- **Anti-goal (what would make him wince):** "Anything that looks like a subscription app full of hype."

## Goals

- The default product page follows Peter's demo order: **fast → organized → sign → yours**.
- The name, subtitle and keywords match **thing-words** ("scan ID", "receipt", "prescription").
- The Featuring Nomination for v4.0 is filed **this week**.
- After v4.0 is approved, **Custom Product Pages** catch use-case searches.

## Non-goals

- **Product Page Optimization** (A/B tests). At about 55 page views a quarter a test can't
  reach a result. Revisit when traffic grows.
- New app features. The only code change is demo content in the DEBUG-only `DemoSeeder`.
- A new App Preview video, unless the builder finds the current one contradicts the new order (see
  "Left to the builder").
- Changing the price or the business model.

## Anti-goals: the "no hype" rules

Every piece of copy and every image is checked against these rules:

- No exclamation marks. No superlatives ("best", "#1", "ultimate", "powerful"). No urgency ("now",
  "limited", "today only").
- No badges, star ratings, awards, "as seen in", or emoji decoration.
- Captions say plainly what the app does, over **real app screens**.
- Quiet visuals that match the app's own look.
- It reads as if Peter wrote it, because he signs off on it.

## Timeline

| When | What |
|---|---|
| This week (by Fri 23 Oct) | File the Featuring Nomination. Release date **Wed 11 Nov 2026** (3 weeks out) |
| Before about 4 Nov | v4.0 (39) submitted with the new listing in all 8 store locales. Use **manual release**, approved and held |
| Wed 11 Nov | Release v4.0 |
| After approval | Custom Product Pages built and submitted (no build needed) |

If v4.0 is approved early, it waits for 11 Nov, because the nomination named that date. If the listing work slips,
v4.0 can ship with the old screenshots and the new name, subtitle and keywords. The **keywords must
be in v4.0** whatever happens, because Custom Product Pages can only use keywords from the latest approved version.

**Order of work** *(Claude's call)*:

1. The nomination text.
2. The short fields (name, subtitle, keywords) in English, then in all locales, including their QA.
3. The description, promotional text and What's New.
4. Screenshots last.

Small fields first means the deadline-critical part is finished early. A locale whose new copy isn't
reviewed by submission keeps its current copy, and it catches up in the next version (v4.0.1). Version
metadata is locked only per version, not forever.

**Build status:** Instant Scan is merged and device-verified (D1–D8). The only remaining build work is the 4.0 (39)
bump in both targets and the DEBUG-only `DemoSeeder` additions. Past reviews cleared in under a day, so
4 Nov leaves a week of slack.

## 1. Featuring Nomination

Filed in App Store Connect for v4.0. The form's exact fields are whatever ASC shows on the day.
This design supplies the story they draw on:

- **What's new:** Instant Scan. One press of the Action button, a Control Center or lock-screen
  control, or "Scan with Pocket Scanner" to Siri, and the camera is open. The scan saves itself, OCR'd and
  searchable, into the library. With the Face ID lock on, the camera comes first and Face ID comes before
  anything is shown.
- **Built on Apple's technology:** App Intents (`OpenIntent`, App Shortcuts), WidgetKit Controls,
  VisionKit's document camera, Vision OCR, and Face ID. Apple is actively promoting App Intents.
- **The story:** a solo indie developer in Canada. No subscription, no ads, no account, no server.
  Everything happens on-device or in the user's own iCloud.
- **The moment:** an optometrist leaves a prescription on the table. You scan it in seconds
  and walk out.
- **Localized** in en, es, fr, de, it, zh-Hans.
- **Release date:** Wed 11 Nov 2026.

Peter reviews the final text before it is filed. Filing is his action in ASC. *(Claude's call)* The
nomination is text plus a date. It does not wait for the new screenshots or listing. If the form asks for a
link or an image, use the live product page and the existing stills.

## 2. v4.0 default listing, English first

Source of truth for the copy stays `marketing/app-store-metadata/<locale>/*.txt`.
`scripts/verify-metadata.py` counts characters.

### Name

`Pocket Scanner: Scan Anything` (29/30). Peter's "Pocket Scanner: Scan Anything Fast!" is 35 characters,
so "fast" moves to the subtitle, and the "!" goes because of the no-hype rule.

**Risk:** a reviewer could call "Anything" an unverifiable claim under 2.3.7. If so, **contest first**
(the v3.2 lesson in `docs/app-store-metadata.md`). The fallback is `Pocket Scanner: Scan It Fast` (28).

**Localized names:** each locale gets the same pattern ("Pocket Scanner: " plus a translation of "Scan Anything")
within 30 characters. FR/ES are reviewed by Peter. de/it/zh-Hans go through back-translation QA.

### Subtitle

It carries speed, not the business model. That also retires the line rejected under 2.3.7 in v3.2.
Starting point: `One press. Any paper. Yours.` (28). Final wording is Peter's call. It must pass the no-hype
rules, and words in it don't need repeating in keywords. A fallback with no claim in it, in case a reviewer
objects to "Any paper" under 2.3.7: `Scan, sign, organize, search` (29) *(Claude's call)*.

### Keywords

Keywords are **thing-words** for what people scan. Words already in the name or subtitle (`pocket`, `scanner`, `scan`,
`anything`) are dropped. `no subscription` is **kept**: it is the strongest differentiator search
and was settled on 2026-08-28. It has passed review in every version from v3.3 to v3.9. Starting set,
to be fitted to 100 characters. `card` is added for the ID page; `folder` or `handwriting` is dropped first if
the set runs over.

`id,card,receipt,tax,form,prescription,medical,note,handwriting,lab,contract,license,pdf,ocr,sign,folder,no subscription`

Each use-case Custom Product Page (section 4) needs its words in this list.

### Description

Rewritten in demo order:

1. scans anything fast (now with one press)
2. folders inside folders
3. sign
4. yours: Face ID lock, iCloud optional, filters

Then everything else. The napkin goes in ("…or the number someone wrote on a napkin"). The existing "WHAT IT DOESN'T DO" and
"PRIVACY" sections stay. They are where the no-subscription and no-ads message lives safely (2.3.7 covers names,
subtitles, screenshots and previews, not the description).

### Promotional text and What's New

- **Promotional text:** leads with Instant Scan.
- **What's New:** v4.0 is Instant Scan, plus how to set it up: Settings ▸ Action Button ▸ Controls ▸
  Scan Document; Control Center; and the lock screen, where an existing button must be removed first. Also the one-time Siri
  "turn on shortcuts" consent. These are the lessons from D1–D8 in the Instant Scan spec.

### Screenshots (6.9" slot, 1290×2796, framed, via `render-captions.py`)

The order follows the demo. Captions are short and plain. Wording is drafted by the builder and approved by Peter.

| # | Shows | Caption idea |
|---|---|---|
| 1 | The scan frame over a stack of real-world things: ID (SPECIMEN), prescription, napkin note, tax form | "Scan anything" / "IDs, prescriptions, receipts, notes" |
| 2 | One press: Action button / Control Center control → camera | "One press to the camera" |
| 3 | Nested folders, e.g. Medical ▸ Lab Results | "Folders inside folders" |
| 4 | Signing a document | Keep the current "Emailed a contract? Sign and date it, no printer" |
| 5 | Settings: Face ID lock, iCloud on or off, filters | "Your documents, your rules" |
| 6 | Search inside scans | Keep the current |
| 7 | Import a PDF | Keep the current |

The App Preview video stays in slot 1, as today.

### Demo content

All of it is **obviously fake**. A realistic ID or prescription in a store screenshot is a review and ethics problem.

- Props for screenshot 1 are made by Peter in **PhotoCraft** (ArtCraft's open-source Photoshop alternative,
  replacing Krita). Keep a PNG master of each. Props: a sample ID marked **SPECIMEN** with an invented
  name, a prescription from an invented clinic, a napkin with a made-up phone number (555-style or
  otherwise non-routable), and a blank-ish tax form that is not a real government form.
- `DemoSeeder` (DEBUG only) gains a **Medical ▸ Lab Results** nested folder and the new documents, so
  screenshots 3 and 6 come from the seeded simulator as before.

## 3. Other locales

Once Peter approves the English set:

- Translate the captions TSVs, the name, subtitle, keywords, description, promotional text and What's New for es,
  es-MX, fr, fr-CA, de, it and zh-Hans.
- Render with the existing scripts.
- FR/ES are reviewed by Peter and final. de/it/zh-Hans get a back-translation file under
  `docs/superpowers/qa/`.

The keywords for each locale are thing-words in that language, not translations word for word.

## 4. Custom Product Pages (after v4.0 approval)

Facts from Apple's help page:

- An app can have up to 70 custom product pages.
- A page can be shown in search by assigning keywords **from the latest approved version's keyword list**.
  Searchers using those keywords see that page instead of the default one.
- Screenshots live in the Asset Library and can be reviewed without an app update.

Start with **three English pages**:

| Page | Keywords | First screenshot |
|---|---|---|
| ID & cards | id, license, card | ID (SPECIMEN) scan |
| Medical | prescription, medical, lab | Medical ▸ Lab Results folder |
| Receipts & tax | receipt, tax, form | Receipts / Tax folders |

Each page reuses the default set with its own first one or two shots and its own promotional text. Assign each keyword to only one page.
Add more pages, and pages in other locales, if the first three show downloads in App Analytics ▸
Acquisition. Apple reports page data only after at least 5 first-time downloads.

## Doc housekeeping (part of this work)

- `docs/app-store-metadata.md`: nomination notice from 2 → 3 weeks. Name, subtitle and keywords
  sections updated. Krita references point to `render-captions.py` / PhotoCraft.
- `marketing/templates/README.md`: Krita is no longer the tool.

## Constraints

- Guideline 2.3.7 applies to the name, subtitle, screenshots and keywords: no prices or terms in name, subtitle or screenshots,
  no competitor names, and no unverifiable claims. Contest before rewording.
- The privacy promise is unchanged, and all copy must stay true to it.
- 8 store locales: en, es, es-MX, fr, fr-CA, de, it, zh-Hans.
- Version metadata (name, subtitle, keywords, description, What's New) is locked once v4.0 is live.
  Promotional text and Asset Library screenshots are not.
- Never open Xcode's General tab (FB24809836). The version bump to 4.0 (39) goes in **both** targets.

## Left to the builder

- Final caption wording within the no-hype rules (Peter approves).
- How screenshot 2 ("one press") is captured. The simulator has no Action button and no camera. Options include
  a device capture from Peter's iPhone with personal content hidden, or Control Center in the simulator plus
  `shared/scan-frame.png`.
- Whether the current App Preview video still fits the new order. Flag it if it doesn't; don't remake it unasked.
- Exact keyword packing to 100 characters for each locale.
