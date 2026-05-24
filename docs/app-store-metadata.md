# App Store metadata — Mobile Scanner

Draft copy for App Store Connect. Field-by-field, ready to paste in. Character counts are Apple's hard limits.

---

## App name (30 chars max)

**Recommendation:** `Mobile Scanner` (14 chars)

Alternates if `Mobile Scanner` is taken in your locale's store:

- `Plain Scanner` — leans into no-frills
- `Page Scanner` — descriptive
- `Honest Scanner` — leans into anti-subscription
- `Receipts & Notes Scanner` (23 chars) — descriptive + keywordy

Test availability by searching the App Store from your phone before settling.

---

## Subtitle (30 chars max)

**Recommendation:** `Scan to PDF. No subscription.` (29 chars)

Alternates:

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

Mobile Scanner is a no-nonsense document scanner for iPhone. Scan a receipt, a contract, a recipe, a page of notes — and it lands in your library as a searchable PDF, synced to all your devices through your own iCloud account.

That's it. No subscription. No ads. No account to sign up for. No upsells. Pay once, scan forever.

WHAT IT DOES

• Capture pages with Apple's document scanner — automatic edge detection, perspective correction, multi-page in one shot
• On-device OCR — every scan is a fully searchable PDF, no internet required
• iCloud Drive sync — your scans appear on every device signed into your iCloud account, and stay in your own storage where you can see and manage them
• Per-page editor — adjust the crop, rotate, apply a clean B&W or photo filter
• Search across all your scans by name or by text inside the document; matches highlight on the page
• Optional Face ID lock for the library
• App-switcher privacy blur so document thumbnails don't appear in the iOS task switcher

WHAT IT DOESN'T DO

• Doesn't collect any data about you. None. No analytics, no telemetry, no behavioural tracking.
• Doesn't have a "Pro" tier. Every feature is included.
• Doesn't store anything on our servers. Your documents go from your camera to your iCloud account, full stop.
• Doesn't show ads.

PRIVACY

Mobile Scanner doesn't have a server. Your scans never leave your device except to sync to your own iCloud account (Apple's storage you already pay for, or the free tier). The OCR that makes your documents searchable runs entirely on your iPhone using Apple's Vision framework. We don't see your documents, your names, your filenames, your search queries, or your usage patterns.

Full privacy policy: [your URL here]

REQUIREMENTS

• iOS 17.6 or later
• iCloud Drive recommended (works in local-only mode if you prefer)

ABOUT

Built solo by an indie developer who got tired of every scanner app demanding a subscription. If you like the app, leave a review — it's the single most valuable thing you can do to help.
```

(~1900 chars — well under the 4000 limit)

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

Run through the questionnaire honestly. Expected outcome: **4+** (no objectionable content of any kind). Mobile Scanner is purely a utility — there's no user-generated content, no chat, no web browsing.

---

## URLs

- **Privacy policy URL** — REQUIRED. Host `docs/privacy-policy.md` (rendered as HTML) on your domain or GitHub Pages. Examples:
  - `https://peter-jones.ca/mobile-scanner/privacy`
  - `https://pjones.github.io/mobile-scanner/privacy`
- **Support URL** — REQUIRED. Can be your own contact page or a `mailto:` redirect through your site. Common pattern:
  - `https://peter-jones.ca/mobile-scanner/support` — same page can have an email link
- **Marketing URL** — optional. If you build a landing page, link it here. Skip if you don't have one — the privacy/support pages are fine for v1.

---

## Screenshots

Apple requires screenshots for the largest iPhone size you support; the next-largest is recommended. Take all of them in the simulator.

Required device sizes (as of iOS 26):

- **6.9" Display** (iPhone 17 Pro Max) — 1320 × 2868
- **6.7" Display** (iPhone 17 / iPhone Air) — 1290 × 2796 — also covers iPhone 14/15 Pro Max

In Xcode: Cmd+R to launch the simulator at the right device size, then in the **Simulator** app menu: **File → Save Screen…** (or Cmd+S) saves a properly-sized PNG.

### Suggested screenshot sequence (5 frames)

1. **The library** showing 5-6 sample scans with realistic names (Lease Agreement, Costco Receipt, Vet Invoice). Caption overlay: *"Your scans, your iCloud."*

2. **Capture moment** — the VisionKit scanner with a document outlined. Caption: *"Auto edge detection. Multi-page in one go."*

3. **A scanned PDF open in the viewer** with selected text showing the searchable layer working. Caption: *"Every scan is searchable, OCR'd on your phone."*

4. **The per-page editor** with the crop quad visible and the filter picker showing B&W selected. Caption: *"Crop, rotate, filter — per page."*

5. **Settings screen** with App Lock toggle. Caption: *"No accounts. No ads. No subscription."*

Captions can be overlaid in any image editor (Figma, Sketch, Photoshop, or even Keynote). Keep them readable at thumbnail size — large, bold, high-contrast text near the top or bottom.

### Sample content for the screenshots

The library row names should look real but generic (no personal info). Use names like:

- Lease Agreement
- Costco Receipt
- Vet Invoice — Maple
- Recipe — Banana Bread
- Tax Return 2025
- Passport Page

Fill the simulator's iCloud Drive with sample PDFs ahead of time so the screenshots show a populated library, not the empty state.

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
