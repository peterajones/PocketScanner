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

**Shipped:** `No subscriptions or ads ever!` (29 chars)

Alternates considered:

- `Scan to PDF. No subscription.` (29)
- `Scan documents. No ads.` (23)
- `Private document scanner` (24)
- `One-time price. No accounts.` (28)

The subtitle is the second-most-read piece of copy after the icon — make it about the differentiator, not the feature.

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

**Recommendation:**

```
scanner,pdf,document,ocr,scan,receipts,searchable,icloud,paperless,notes,nosubscription,scanner pro
```

(99 chars including commas)

App Store keyword strategy:

- Words already in the app name + subtitle don't count — don't waste characters on `mobile` or `scanner`.
- Singular forms generally cover plural (`receipt` covers `receipts`) but Apple's ranking is imperfect — when in doubt, use the more common one.
- Avoid competitor names that you don't own (don't use `camscanner`, `adobescan`, etc. — possible rejection).
- Include `nosubscription` as one word — Apple matches on substrings.

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

In Xcode:

1. **Bundle identifier:** `ca.peter-jones.DocumentScanner` ✓ (already set)
2. **Version:** `1.0` (in the General tab)
3. **Build number:** `1` (increment on every subsequent upload)
4. **Marketing version:** `1.0`
5. **Deployment target:** iOS 17.6 ✓
6. **Scheme:** switch to **Release** for archive (`Product → Scheme → Edit Scheme → Archive` should already be Release by default)
7. **Encryption:** Add `ITSAppUsesNonExemptEncryption` = `NO` to Info.plist. We use only Apple's standard cryptography (HTTPS, iCloud), which is exempt. Skipping this triggers an annoying export-compliance prompt on every upload.

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
