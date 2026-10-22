# What's New in v4.0

A running log of everything that ships in **Pocket Scanner 4.0**. Started 2026-10-22.

- **Version / build:** 4.0 (39), uploaded 2026-10-22 and tested from TestFlight.
- **Submit by:** about 2026-11-04. **Release:** manual, Wednesday 2026-11-11, the date in the
  Featuring Nomination (`docs/featuring/2026-10-21-v4.0-nomination.md`).
- **Previous release:** 3.9 (38), git tag `build-38`. `git log build-38..HEAD` lists every commit
  since then.

**Keeping it up to date until submission:** add every change that lands before ~Nov 4 under
"Added before submission" with its date, commit and build. Say whether the App Store What's New
text mentions it. That text is already entered in App Store Connect in all 8 locales, so changing
it means updating `marketing/app-store-metadata/<locale>/whats_new.txt` and ASC for each locale.
Any change after 39 goes in a new 4.0 build (40, 41, …) with `CURRENT_PROJECT_VERSION` bumped in
both targets (app and Controls). Once 4.0 is released, further changes need 4.0.1 or 4.1.

---

## App Store What's New (as entered in ASC)

Source of truth: `marketing/app-store-metadata/en/whats_new.txt`, translated in the other 7
locales next to it. English, as entered:

> Instant Scan: one press opens the camera, from anywhere on your iPhone. The scan is saved, made
> searchable and opened for you. Rename it later if you like.
>
> Ways to use it:
>
> - Action button: Settings > Action Button > Controls > Scan Document
> - Control Center: tap + and add Scan Document
> - Lock Screen: remove one of the two bottom buttons, then add Scan Document
> - Siri or Spotlight: "Scan with Pocket Scanner" (the first time, Siri asks to turn on the app's
>   shortcuts)
>
> With App Lock on, the camera opens first and Face ID comes before anything in your library is
> shown.
>
> As always: no subscriptions, no ads, no tracking, nothing stored on our servers. Pay once, scan
> forever. Thanks for scanning with Pocket Scanner.

---

## Features

| Feature | What the user gets | In store What's New | Landed |
|---|---|---|---|
| **Instant Scan** | One `OpenIntent` from the Action button, a Control (Control Center and Lock Screen, iOS 18+) and Siri/Spotlight ("Scan with Pocket Scanner", iOS 17.6+). Opens straight into the camera, then OCRs, auto-names, saves to Main Library and opens the document. With App Lock on, the camera comes first and Face ID before any library content. A one-time tip explains the setup, in six languages. | Yes, the whole text | 2026-10-20, merged before 39. Design and plan: `docs/superpowers/specs/2026-10-20-instant-scan-design.md`, `docs/superpowers/plans/2026-10-20-instant-scan.md` |
| **Searchable imports** | A PDF that is really a camera scan (no text layer) is OCR'd on import, page by page, with "Processing page X of Y". Pages that already have text are untouched. Works from Import PDF and from "Open in Pocket Scanner". | No | 2026-10-22, `6b832d3`, build 39. Device PASS (Dev build and TestFlight 39) |
| **Instant delete on iCloud** | A deleted document or folder disappears as soon as the delete is confirmed, instead of lingering about 5 s until iCloud catches up. | No | 2026-10-22, `3178ae6`, build 39. TestFlight 39 PASS |

## Fixes and hardening

| Change | Why | Landed |
|---|---|---|
| OCR render capped at 2,800 px (`b67988a`) | A PDF can declare a 14,400 pt page; importing one could allocate ~830 MB and get the app killed. Found by the automated security review. | 2026-10-22, build 39 |
| Page editor render ceiling of 5,600 px (`cbc600c`) | Same oversized-page risk when such a page is opened in the editor. | 2026-10-22, build 39 |
| German tip says "Aktionstaste" (`ce6ec75`) | Apple's German name for the Action button; matches the listing. | 2026-10-21, build 39 |
| Italian tip says "tasto Azione" (`2bc1c4e`) | Apple's Italian name for the Action button. | Before 39 |
| Controls extension named "Pocket Scanner" / "Pocket Scanner Dev" (`88ba016`) | The name shown when adding the Control. | Before 39 |

## Listing and marketing (App Store Connect, not in the binary)

- **Name:** "Pocket Scanner: Scan Anything" (zh-Hans keeps its v3.9 name). **Subtitle:** "One press.
  Any paper. Yours." New keywords, promotional text and description, all 8 locales. Design:
  `docs/superpowers/specs/2026-10-21-listing-rework-design.md`.
- **Screenshots:** 7 per locale, in demo order: scan anything, one press, folders, sign, settings,
  search, import. Uploaded at 1206 × 2622 from `marketing/app-preview/v4.0/Stills-1206x2622/`.
  The 1290 × 2796 originals are in `Stills/`. App previews (videos) removed.
- **Featuring Nomination:** submitted 2026-10-21 for 2026-11-11 (App Enhancements).

## Internal only (not user-facing)

- The DEBUG Developer section moved to the bottom of Settings (`52ab683`). Release builds don't
  include it.

---

## Added before submission

Add one line per change, newest last:
`YYYY-MM-DD — what — commit — build — in store What's New: yes/no`

- 2026-10-22 — Searchable imports — `6b832d3` — 39 — no
- 2026-10-22 — Oversized-page caps (import and editor) — `b67988a`, `cbc600c` — 39 — no
- 2026-10-22 — Instant delete on iCloud — `3178ae6` — 39 — no
