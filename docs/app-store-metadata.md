# App Store metadata — Pocket Scanner

Draft copy for App Store Connect. Field-by-field, ready to paste in. Character counts are Apple's hard limits.

---

## App name (30 chars max)

**Recommendation:** `Pocket Scanner` (14 chars)

Alternates if `Pocket Scanner` is taken in your locale's store:

- `Plain Scanner` — leans into no-frills
- `Page Scanner` — descriptive
- `Honest Scanner` — leans into anti-subscription
- `Receipts & Notes Scanner` (23 chars) — descriptive + keywordy

Test availability by searching the App Store from your phone before settling.

---

## Subtitle (30 chars max)

**Shipped through v3.1:** `No subscriptions or ads ever!` (29 chars) — **rejected in v3.2 review, see below.**

Live per-locale values are in `marketing/app-store-metadata/<locale>/subtitle.txt`, not here. All 7 carry the same claim: de `Keine Abos, keine Werbung`, es/es-MX `Sin suscripciones ni anuncios`, fr/fr-CA `Sans abonnement ni publicité`, it `Senza abbonamenti né annunci`.

Alternates considered:

- `Scan to PDF. No subscription.` (29) — ⚠️ same 2.3.7 exposure as the shipped line
- `Scan documents. No ads.` (23)
- `Private document scanner` (24)
- `One-time price. No accounts.` (28) — ⚠️ states a price term outright; don't reach for this
- `Scan, sign, search — offline` (28) — clean under 2.3.7; carries the privacy angle without commerce

The subtitle is the second-most-read piece of copy after the icon — make it about the differentiator, not the feature.

### 2026-08-07 — v3.2 (31) rejected on the subtitle

Rejection text: *"The app subtitle include references to the price of the app or the service it provides, which is not considered an appropriate part of these metadata items."*

Guideline 2.3.7, verbatim: *"Metadata such as app names, subtitles, screenshots, and previews should not include **prices, terms, or descriptions that are not specific to the metadata type**. […] App subtitles […] should not include inappropriate content, reference other apps, or **make unverifiable product claims**."*

The rejection letter says "price," but the guideline says "prices, **terms**" — subscription-vs-one-time is a term of sale, and that's the grip. Second grip in the same sentence: "or ads **ever**" is a forward-looking promise, i.e. an unverifiable product claim. Arguing "no price appears in the string" is a losing move; it invites them to quote "terms" back.

Timeline (submission dates from ASC; **approval dates are not recorded in ASC or git** — the v3.1 approval below comes from session notes taken the day it happened):

| Version | Submitted | Outcome | Days |
|---|---|---|---|
| v3.1 (30) | 2026-07-24 | Approved 2026-07-31 *(session notes, not confirmable in ASC)* | 7 |
| v3.2 (31) | 2026-07-31 | **Rejected 2026-08-07** | 7 |

The v3.1 turnaround is corroborated by App Review status inquiry case `20000124075803`, filed 2026-07-30 because the review was dragging; it approved the next day. **Two consecutive 7-day reviews — treat a week as the current normal when planning submission windows**, not the 1–4 days v2.8–v3.0 saw.

Do **not** put the v3.1 approval date in a Resolution Center reply — it can't be substantiated from ASC. Use "it is the live subtitle on the App Store today" instead, which is present-tense and verifiable on Apple's side.

**The subtitle was unchanged since v1.0 and passed review on every release through v3.1 — it is the live subtitle on the App Store right now.** This is reviewer-to-reviewer variance, not a rule change. That present-tense inconsistency is the only argument with real weight, and it's what the Resolution Center reply leans on: it asks them to name the specific offending token rather than guessing at a rewrite.

**Resolution Center reply sent 2026-08-07. Awaiting response.** Given two consecutive 7-day reviews, budget a week; if it goes quiet longer, an App Review status inquiry is the precedent (case `20000124075803` worked for v3.1 — approved the next day).

**Record submitted/approved dates in this file at release time.** ASC does not surface an approval date after the fact, so turnaround claims become unverifiable within days of the event. The table above is the place for them.

Subtitle is version metadata — this is an edit-and-resubmit on build 31, no new build and no version bump, whichever way it lands.

**What's clean and doesn't need touching:** the description (2.3.7 lists only names, subtitles, screenshots, previews — business-model copy is fine there), the promotional text, and the screenshot captions in `marketing/app-preview/captions/`. **What's still exposed:** keywords — see below.

---

## Promotional text (170 chars max)

> Scan documents straight into iCloud Drive. Searchable PDFs with on-device OCR. No subscription, no ads, no account — just one price, forever.

(143 chars)

Promotional text is the only metadata you can change *without* shipping a new build. Use it for seasonal copy, version-launch notes, or A/B testing positioning. Default to the line above until you have something better.

---

## Description (4000 chars max)

```text
Scan paper documents straight into iCloud Drive.

Pocket Scanner is a no-nonsense document scanner for iPhone. Scan a receipt, a contract, a recipe, a page of notes — and it lands in your library as a searchable PDF, synced to all your devices through your own iCloud account.

That's it. No subscription. No ads. No account to sign up for. No upsells. Pay once, scan forever.

WHAT IT DOES

• Capture pages with Apple's document scanner — automatic edge detection, perspective correction, multi-page in one shot
• Pick a look as you scan — Color, Greyscale, Black & White, or Photo
• On-device OCR — every scan becomes a fully searchable PDF, no internet required
• Search your whole library, including inside folders, by filename or by text in the document — matches highlight right on the page
• Stay organized — folders you can move documents between, sorting by date / name / page count, and a list or thumbnail-grid view
• Per-page editor — crop, rotate, and apply a clean filter; or rotate a page straight from the page strip
• Split out pages — pull selected pages into their own new document
• Mark up scans — highlight or strike through text directly on the page
• Swipe to delete documents and folders
• iCloud Drive sync — your scans appear on every device on your iCloud account, in your own storage where you can see and manage them
• Privacy built in — optional Face ID lock for the library, plus an app-switcher blur so thumbnails don't appear in the task switcher

WHAT IT DOESN'T DO

• Doesn't collect any data about you. None. No analytics, no telemetry, no behavioural tracking.
• Doesn't have a "Pro" tier. Every feature is included.
• Doesn't store anything on our servers. Your documents go from your camera to your iCloud account, full stop.
• Doesn't show ads.

PRIVACY

Pocket Scanner doesn't have a server. Your scans never leave your device except to sync to your own iCloud account (Apple's storage you already pay for, or the free tier). The OCR that makes your documents searchable runs entirely on your iPhone using Apple's Vision framework. We don't see your documents, your names, your filenames, your search queries, or your usage patterns.

Full privacy policy: [your URL here]

REQUIREMENTS

• iOS 17.6 or later
• iCloud Drive recommended (works in local-only mode if you prefer)

ABOUT

Built solo by an indie developer who got tired of every scanner app demanding a subscription. If you like the app, leave a review — it's the single most valuable thing you can do to help.
```

(~2,300 chars — comfortably under the 4,000 limit)

---

## Keywords (100 chars max, comma-separated, no spaces between)

**Source of truth is `marketing/app-store-metadata/<locale>/keywords.txt`, not this section.** The original v1.0 recommendation below has drifted from what ships (it proposed `nosubscription` as one word plus `ocr`/`notes`; shipped en is `no subscription` and drops those). Kept for the strategy notes only — read the files for current values.

Original v1.0 recommendation:

```
scanner,pdf,document,ocr,scan,receipts,searchable,icloud,paperless,notes,nosubscription,scanner pro
```

(99 chars including commas)

### ⚠️ Open 2.3.7 exposure in keywords (as of 2026-08-07)

**All 7 locales currently carry a pricing term in keywords**, and 2.3.7 names pricing information in keywords explicitly. This was *not* flagged in the v3.2 rejection — the reviewer only cited the subtitle — but it's the same class of claim sitting in a field they didn't look at:

| Locale | Term | Field length |
|---|---|---|
| en | `no subscription` | 90 |
| es, es-MX | `sin suscripción` | 89 |
| fr, fr-CA | `sans abonnement` | 92 |
| de | `ohne abo` | 86 |
| it | `senza abbonamento` | 83 |

Every locale has headroom under the 100-char cap, so dropping the term costs nothing but the search coverage itself. Decide deliberately: leaving it is a live risk if enforcement stays strict, removing it forfeits real search traffic from people hunting for exactly this.

App Store keyword strategy:

- Words already in the app name + subtitle don't count — don't waste characters on `mobile` or `scanner`.
- Singular forms generally cover plural (`receipt` covers `receipts`) but Apple's ranking is imperfect — when in doubt, use the more common one.
- Avoid competitor names that you don't own (don't use `camscanner`, `adobescan`, etc. — possible rejection).

---

## Category

- **Primary:** Productivity
- **Secondary:** Utilities

Productivity is more competitive but is what users browse for scanners. Utilities is the safe secondary.

---

## Age rating

Run through the questionnaire honestly. Expected outcome: **4+** (no objectionable content of any kind). Pocket Scanner is purely a utility — there's no user-generated content, no chat, no web browsing.

---

## URLs

- **Privacy policy URL** — REQUIRED. Host `docs/privacy-policy.md` (rendered as HTML) on your domain or GitHub Pages. Examples:
  - `https://peter-jones.ca/mobile-scanner/privacy`
  - `https://pjones.github.io/mobile-scanner/privacy`
- **Support URL** — REQUIRED. Can be your own contact page or a `mailto:` redirect through your site. Common pattern:
  - `https://peter-jones.ca/mobile-scanner/support` — same page can have an email link
- **Marketing URL** — optional. If you build a landing page, link it here. Skip if you don't have one — the privacy/support pages are fine for v1.

---

## Screenshots & App Preview

The gallery is now **framed in iPhone 17 device chrome**, led by an **App Preview video** in slot 1 followed by framed static shots — not the bare simulator screenshots the original v1.0 plan described.

**The production workflow is the single source of truth in `marketing/app-preview/README.md`** (capture → CapCut edit → ffmpeg chrome composite → downscale → verify → upload), including the two gotchas that bit us:

- The App Preview **video** is **886 × 1920** — NOT the screenshot pixel size — and must carry a **silent AAC audio track**, or App Store Connect rejects it.
- Static shots are framed via the Krita master `marketing/templates/PocketScannerAppPreview.kra`; per-release stills live under `marketing/app-preview/v1.x/Stills/`. See the README for exact dimensions and the device-size slot.

Current framed gallery (all at the canonical **9:41** status bar):

- **App Preview video** (slot 1) — short walkthrough.
- Stills: Main Library, Grid view, Folder added, Move to folder, Docs moved to folder, Search term, Search results, Settings, Tips.

### Demo content for the shots

Generated on launch by the **DEBUG-only** `-SeedDemoData` launch argument (`DemoSeeder`, compiled out of Release builds). It seeds folders **Receipts / Recipes / Tax 2025** plus realistic, generic documents — Lease Agreement, Travel Insurance Policy, Vacation Itinerary, the Costco / Whole Foods / Home Depot receipts, the Banana Bread / Pumpkin Pie recipes — with no personal info. See `docs/dev-build.md` and `DemoSeeder.swift` for the exact set.

---

## Build configuration before archive

A recurring per-release checklist. In Xcode (target build settings, or the General tab):

1. **Bundle identifier:** `ca.peter-jones.DocumentScanner` (production). The dev build uses `…DocumentScanner.dev` — a separate install with no iCloud entitlement; don't archive that one.
2. **Marketing version** (`MARKETING_VERSION`, shown as "Version" in General): bump for the release — e.g. `1.12`. This is the user-facing version on the Store.
3. **Build number** (`CURRENT_PROJECT_VERSION`): increment on **every** upload — must be unique and higher than the last build App Store Connect has seen (e.g. `1.12 (17)`). Commit the bump on its own as `chore: bump to vX.Y (N)`.
4. **Deployment target:** unchanged since launch (iOS 17.6).
5. **Configuration:** archive the **Release** configuration (`Product → Scheme → Edit Scheme → Archive` is Release by default). The dev `-SeedDemoData` seeding and the DEBUG-only Developer settings section are compiled out of Release, so the archive is clean. (If you flipped the *Run* config to Release for screenshots, flip it back to Debug afterward.)
6. **Encryption:** `ITSAppUsesNonExemptEncryption` = `NO` in Info.plist — we use only Apple's standard cryptography (HTTPS, iCloud), which is exempt. Skipping this triggers an export-compliance prompt on every upload.

Then **Product → Archive → Validate → Upload**. Note: App Store Connect allows only **one version in the review pipeline at a time** — you can't create the next version until the current one is approved and released, though you *can* upload the build anytime.

---

## After submission

1. **Status: Waiting for Review** — typically 24-48 hours these days, can be same-day.
2. **In Review** — usually < 24h.
3. **Pending Developer Release** — if you opted for manual release, this is your "go live" moment.
4. **Ready for Sale** — it's live.

If rejected, the rejection message in App Store Connect is usually specific and actionable. Reply through the Resolution Center; revisions usually get re-reviewed within a day.

---

## Post-launch checklist

- Test downloading your own app from the Store (different Apple ID if you have one).
- Ask 3-5 friends to leave honest reviews — Apple's review-count threshold matters for ranking.
- Post a "Show HN" thread, a /r/iosapps post, and a Mastodon/Twitter thread the same week. Don't dribble launches — one concentrated push performs better than three half-hearted ones.
- Watch for crash reports in App Store Connect → Crashes.
- Plan a 1.0.1 release within 2 weeks for any minor bugs found in the wild — keeps the app looking actively maintained for App Store ranking.
