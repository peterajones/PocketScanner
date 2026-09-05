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
| v3.2 (31) | 2026-07-31 | **Rejected 2026-08-07**; contested, withdrawn, Ready for Distribution 2026-08-11 | 7 to rejection, 11 total |
| v3.3 (32) | 2026-08-29 | **Approved + LIVE 2026-08-31** | 2 |
| v3.4 (33) | 2026-08-31 | **Approved + LIVE 2026-08-31** | same day |
| v3.5 (34) | 2026-09-01 | **Approved + LIVE 2026-09-01, 22:51** | same day |
| v3.6 (35) | 2026-09-04 | **Approved + LIVE 2026-09-05, 07:03** | overnight |
| v3.7 (36) | 2026-09-05 | *Waiting for Review* | — |

### Release cadence — ship freely for now, batch later

Five submissions in eight days (v3.3 → v3.7, 2026-08-29 to 09-05). **This is fine, and the
current policy is to keep shipping small releases as they are ready.**

**Apple does not appear to mind.** No published rate limit, none reported by developers, and
four of the five cleared in under a day — including v3.6, the largest code change of the run.
If frequency counted against a submission, slower reviews would be the signal; the opposite
happened. Review looks at what is in the binary, not at how recently you last submitted.

**The real cost is to users, not to Apple.** Someone with auto-updates off sees five badges in
eight days for an app they open occasionally. At **one paying user** that cost is negligible and
the benefit — a tight fix-verify-ship loop while the work is fresh — is real.

**The tripwire is users, not release count.** Batch small fixes once there is an install base to
inconvenience; a traffic push that takes the app from 1 to a few hundred installs is the moment
this flips. Until then, ship.

A related tell: v3.7's note reads "Cosmetic improvements to the app", which is honest but says
nothing a user can act on. **A release whose notes have nothing to say is the kind that is worth
bundling into the next one** — once bundling has a cost worth paying.

**Turnaround has collapsed: 7, 7, 2, 0, 0, overnight.** Do not plan submission windows around any of
these numbers — the spread across five consecutive releases is a week to a few hours, with no
change in what was submitted to explain it. Treat a week as the pessimistic case and same-day as
possible, rather than assuming either. **Four** consecutive same-or-next-day approvals (v3.3,
v3.4, v3.5, v3.6) make the fast path look normal; it is not a guarantee, and the two 7-day
reviews were only weeks earlier. v3.6 was the largest code change of the run — the crop overhaul,
a new Settings section and an app-wide colour change — and still cleared overnight, so review
duration does not appear to track submission size.

**v3.4 carried the most new metadata of any recent release** — seven replaced screenshots in
seven locales — and 2.3.7 explicitly covers screenshots alongside names and subtitles. It passed
without comment, as did the subtitle that was rejected under 2.3.7 in v3.2 and contested. That is
now **two consecutive clean passes for that subtitle**.

Still not precedent. Apple conceded nothing when they withdrew the v3.2 rejection and explained
nothing, so a different reviewer can raise it again on any future submission. The contest playbook
above stands unchanged — it is just no longer the expected case.

The v3.1 turnaround is corroborated by App Review status inquiry case `20000124075803`, filed 2026-07-30 because the review was dragging; it approved the next day. **Two consecutive 7-day reviews — treat a week as the current normal when planning submission windows**, not the 1–4 days v2.8–v3.0 saw.

Do **not** put the v3.1 approval date in a Resolution Center reply — it can't be substantiated from ASC. Use "it is the live subtitle on the App Store today" instead, which is present-tense and verifiable on Apple's side.

**The subtitle was unchanged since v1.0 and passed review on every release through v3.1 — it is the live subtitle on the App Store right now.** This is reviewer-to-reviewer variance, not a rule change. That present-tense inconsistency is the only argument with real weight, and it's what the Resolution Center reply leans on: it asks them to name the specific offending token rather than guessing at a rewrite.

**Reply sent 2026-08-07. OUTCOME: rejection withdrawn 2026-08-11.** App Review responded:

> Thank you for providing this information. We will continue the review, and we will notify you if there are any further issues.

**v3.2 (31) then went to Ready for Distribution the same day, 2026-08-11 — APPROVED with the subtitle unchanged.** No token was ever named, no metadata edit, no new build, no version bump. Total cost of the dispute: one Resolution Center reply and four days.

Note what this is *not*: **precedent**. Apple conceded nothing and explained nothing, so a different reviewer can raise the identical objection on v3.3. Expect it to recur rather than treating the subtitle as cleared.

### LESSON — contest a metadata rejection before rewording

When the flagged metadata was **previously approved and unchanged**, contesting is the correct first move:

- It is **reversible and forecloses nothing**. If they hold, you reword and resubmit, arriving where you'd have been anyway — days later, having risked nothing.
- Rewording immediately **concedes copy you may not have had to give up**, and there's no undo once the field is changed and approved.
- The winning argument is **present-tense inconsistency** ("this is the live subtitle on the App Store today"), not semantics. Never argue "no price appears in the string" — 2.3.7 says "prices, **terms**," and they will quote it back.
- Asking them to **name the specific offending token** gives a reviewer something concrete to either produce or drop. Here they dropped it.
- Never include a date you cannot substantiate from ASC.

The initial instinct in-session was to reword for speed; Peter overruled it and contested. That was right. Default to contesting.

### Keywords decision (2026-08-11)

**Deliberately left unchanged** for this submission. Changing keywords mid-dispute would have muddied what was being argued, and the subtitle came through untouched. The exposure below is still open and should be decided before the *next* submission, not carried forward unexamined.

**Record submitted/approved dates in this file at release time.** ASC does not surface an approval date after the fact, so turnaround claims become unverifiable within days of the event. The table above is the place for them.

Subtitle is version metadata — this is an edit-and-resubmit on build 31, no new build and no version bump, whichever way it lands.

**What's clean and doesn't need touching:** the description (2.3.7 lists only names, subtitles, screenshots, previews — business-model copy is fine there), the promotional text, and the screenshot captions in `marketing/app-preview/captions/`. **Keywords** were settled separately on 2026-08-28 — see the Keywords section below.

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

### 2026-08-28 — resolved: competitor name removed, pricing terms kept

Two separate 2.3.7 exposures were sitting in keywords. They were settled differently.

**Removed — `scanner pro` (en only).** That is Readdle's app name, and using a competitor's name you don't own is a straightforward rejection risk with no defence available. Replaced with `ocr,signature`, both of which every *other* locale already carried and en was missing. en went 90 → 92 chars.

```text
- scanner,pdf,document,scan,receipts,searchable,icloud,paperless,no subscription,scanner pro
+ scanner,pdf,document,scan,receipts,searchable,icloud,paperless,no subscription,ocr,signature
```

**Kept — the pricing terms, all 7 locales.** 2.3.7's keyword clause is qualified by "just to game the system," and these terms accurately describe the app's business model rather than gaming anything. It is also the app's strongest differentiator keyword — people hunting a one-time-purchase scanner search exactly this phrase. And v3.2 established that a metadata rejection here is contestable and winnable.

| Locale | Term | Field length |
|---|---|---|
| en | `no subscription` | 92 |
| es, es-MX | `sin suscripción` | 89 |
| fr, fr-CA | `sans abonnement` | 92 |
| de | `ohne abo` | 86 |
| it | `senza abbonamento` | 83 |

Ships with **v3.3**. Keywords are version metadata and are locked once a version is live, so this cannot be pushed to the store on its own — it goes in when v3.3's version record is created in ASC, and must be typed in by hand for the affected locale. There is no fastlane/deliver setup in this repo; these `.txt` files are the source of truth for humans, nothing uploads them.

⚠️ **Count characters, not bytes.** `wc -c` overstates the accented locales (`escáner`, `numériser`, `reçus`). ASC counts characters — use `scripts/verify-metadata.py`, which does too.

App Store keyword strategy:

- Words already in the app name + subtitle don't count — don't waste characters on `mobile` or `scanner`.
- Singular forms generally cover plural (`receipt` covers `receipts`) but Apple's ranking is imperfect — when in doubt, use the more common one.
- Avoid competitor names that you don't own (don't use `camscanner`, `adobescan`, etc. — possible rejection). The v1.0 recommendation violated this with `scanner pro` and it shipped that way until 2026-08-28.

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
