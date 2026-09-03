# Future Enhancements

A running list of ideas for future versions of Pocket Scanner. Items here are *candidates*, not commitments — we may drop, defer, or reshape any of them.

Shipped and dropped items are deleted from this doc as they resolve; the history is in git, and the release log lives in the project-status memory.

---

## Candidates (nothing committed)

Lower priority. Some of these may never ship. The list exists to capture what we've considered.

### ~~Import a PDF (bring in an emailed document)~~ — **Built (branch `feature/import-pdf`)**

Both entry points shipped, closing the "no printer" loop for emailed PDFs:
**(1) Document handler** — `CFBundleDocumentTypes` (PDF, Editor, rank Alternate) +
`LSSupportsOpeningDocumentsInPlace`, so "Open in Pocket Scanner" appears in Mail /
Files / Safari; `.onOpenURL` routes to `handleIncomingPDF`. **(2) In-app picker** —
an "Import PDF" item in the `+` menu on both the library root and folder screens,
backed by `.fileImporter` (`UTType.pdf`). Both paths funnel through a shared
`PDFImporter.importPDF(from:using:)` that reads the PDF over a security-scoped URL
and copies it in via the existing `DocumentStorage.write` (name sanitized,
collisions de-duped, atomic coordinated write); unreadable files throw and surface a
"Couldn't Import" alert. iCloud-agnostic — rides `DocumentStorage`, so it works
signed-out into local storage. The picker's `fileImporter` + error alert live in a
shared `ImportPDFModifier` (also keeps both views under the SwiftUI type-check
ceiling). Spec/plan under `docs/superpowers/` dated 2026-07-12. (Surfaced 2026-07-10
while shooting the App Store media.)

  - **Follow-up (still open): OCR image-only imported PDFs.** v1 import deliberately does NO OCR —
    born-digital PDFs (the emailed-contract case) are already searchable via
    `pdf.string`, but an *image-only* PDF (someone's camera scan) imports and is fully
    usable yet **not text-searchable**. A later pass could detect a missing text layer
    and OCR each page (render → Vision → rebuild with an invisible text layer, reusing
    the scan pipeline) to make any imported PDF searchable. Deferred to keep v1 small.

### Signing follow-ups

The core signing project is complete — sign a document, multiple signatures, single-shot capture, signature names, and iCloud sync all shipped through v2.7.

- ~~**Date stamp**~~ — **Built (branch `feature/date-stamp`).** Viewer "Date" button → sheet with a date picker (defaults to today) + 5 fixed format presets (`2026-07-09` · `07/09/2026` · `09/07/2026` · `July 9, 2026` · `9 July 2026`, `en_US_POSIX`), previewed live and last-used remembered (`@AppStorage("dateStampFormat")`). The chosen date renders to a transparent image (`DateStampRenderer`) and is placed via the existing signature machinery (`SignaturePlacementView` drag/resize → `ImageStampAnnotation` tagged `dateStampAnnotationName`, rendered date string in `contents` so Move re-renders it across save→reload). Initials dropped (scannable via multi-signatures); free text excluded (editor-ish). Built inline (222 unit tests pass; the Add-Date sheet + Date alert live in a `dateStampContent` helper to stay under the SwiftUI type-checker budget). Spec/plan under `docs/superpowers/` dated 2026-07-09.

**Maybe (parked — genuine value, but meaningful error/UX risk):**

**Dropped:** — find the "X_____" line and offer to place there. Too much room for error, especially on long/multi-page documents.

**Dropped:** — apply a placed signature across a page range. Same error/UX concern as auto-detect.

**Dropped:** typed / finger-drawn signatures — typed text can't be placed cleanly (stamps are the better path), and finger-drawn signatures always look bad.

### Library / iCloud responsiveness

- **Optimistic delete (and other mutations) on the iCloud build** — on the Release/iCloud build (`MetadataQueryLibraryStore`) a deleted document lingers in the list for ~5s until `NSMetadataQuery` notices the change and fires its update; the Debug build (`InMemoryLibraryStore`, synchronous `refresh()`) is instant. This lag is pre-existing (present in shipped v2.9; confirmed against the App Store build during the 2026-07-16 external-audit smoke test), not a regression. Fix: after the user confirms in the existing **delete confirmation dialog**, optimistically remove the doc from `summaries` immediately (don't wait for the query), then let the `NSMetadataQuery` update reconcile. Same optimistic pattern could extend to import/rename. Keep it gated on the confirmation dialogs so nothing disappears without an explicit confirm. Minor, cosmetic-only (correctness is unaffected — the file is deleted immediately either way).

- **iCloud Drive folder shows "Document Scanner", not "Pocket Scanner"** — the app's iCloud Drive folder (and the container path) display the app's *original* name instead of the brand "Pocket Scanner", which could confuse users. `Info.plist` correctly sets `NSUbiquitousContainerName = "Pocket Scanner"`, but **iCloud caches a container's display name from first creation and does not reliably re-read it** for existing containers — a well-known, undocumented Apple limitation. Status: cosmetic, pre-existing (not from any recent work; not touched by v3.0 localization). Workarounds, all imperfect: (1) **new users** who create a fresh container should pick up "Pocket Scanner" automatically, so it self-corrects for new installs; (2) for **existing users** the cached name persists and there is no public API to force a refresh; (3) reportedly a delete-app + reinstall (or toggling iCloud Drive off/on) *sometimes* refreshes it per-device, but it's unreliable; (4) the only guaranteed fix is changing the iCloud **container identifier**, which creates a brand-new empty container and **orphans all existing user data** — not viable. Recommendation: leave it; revisit only if it generates real support complaints. If ever addressed, do it as a deliberate migration, not a silent container swap.

### Release tooling

- **Push App Store metadata via the App Store Connect API instead of by hand.** Every release,
  every localization's subtitle, keywords, description, promotional text and What's New has to be
  retyped into ASC. At seven locales that's ~35 fields per submission, across a UI whose language
  selector silently resets on every page navigation — which has already caused one shipped mistake
  (the EN/ES subtitles swapped in v3.0). We already keep the canonical copy in
  `marketing/app-store-metadata/<locale>/`, so those files can be the input: a script authenticates
  with an ASC API key and PATCHes `appStoreVersionLocalizations` for all locales in one command.
  `scripts/verify-metadata.py` already validates the character limits, so the push would be the
  only missing piece. Worth noting the API is *not* worth it for reading review status — it returns
  exactly what the web UI shows — but writing metadata is the opposite case: real, repeated,
  error-prone work removed. Raised 2026-07-31 after hand-entering seven locales for v3.2.

- ~~**Prune the old per-release media folders**~~ — **DONE 2026-09-03.** 227MB → 58MB, freeing
  169MB of working tree. Sixteen folders (`v1.7`–`v3.2`) removed; the live gallery's folder stays.

  **The rule going forward: keep the LIVE gallery's folder, prune the rest.** That is not the same
  as "the newest release" — v3.5 shipped no screenshots, so v3.4's gallery is the live one.

  The ordering constraint was real. `render-captions.py` hardcoded the shared scan frame to
  `v2.8/Stills/`, so deleting that folder would have broken slot 1 in all seven locales at once.
  It now lives at `marketing/app-preview/shared/scan-frame.png` — an asset shared by every release
  AND every language does not belong inside a release folder. Verified by re-rendering all 49
  stills after the move: byte-identical.

  Also corrected two docs that would have misled the next shoot: the recipe claimed v3.0/v3.1 left
  folder names in English (the shipped v3.0 French screenshots show `Personnel / Recettes /
  Travail`), and its step-by-step block still invoked `caption-all.sh`, which no longer exists.
  `seed-simulator.sh` now derives the version from `project.pbxproj` instead of naming v3.4.

  As predicted this shrank the working tree only — `.git` is unchanged, since deleted blobs stay
  in history. Nothing is lost: `git show build-32:<path>` recovers anything.

### Test suite

- **Split `test_editMode_addAndDeletePage` into its constituent behaviours.** The UI suite is two
  tests of roughly 190 seconds each, and each covers a long arc — this one does scan → save → enter
  edit mode → add a page → delete a page → confirm the deletion. When it fails you get a wall of
  UI-automation output and no indication of *which* behaviour broke; you're reduced to reading the
  log and guessing. Xcode compounds this by reporting `Executed 1 test, with N failures`, where N
  counts assertion failures rather than tests, so a run that exercised six behaviours and broke
  three of them still reads as "1 test". Splitting into focused tests (`test_addPage`,
  `test_deletePage_requiresConfirmation`, `test_deletePage_cancelKeepsPage`, …) would make a failure
  name the broken behaviour directly. Cost: UI tests are slow, so more of them means a longer suite
  — worth measuring before committing to it. Surfaced 2026-07-30 while verifying the v3.2
  delete-confirmation fix, where the single fat test was the only guard on a destructive path.

### App Store presence (ASO) — raised for v3.4, 2026-08-29

Both items below surfaced from an unsolicited email by an ASO consultant. His *first* email was
content-free — a withheld "common issue" used as a reply hook — and worth ignoring. His second,
after being asked to be specific, named these two. **Both were then verified independently against
this repo, and both are real.** Recording the provenance because the source does not make the
findings wrong, and the verification is what makes them actionable.

- **Screenshot order buries the core proposition.** From `marketing/app-preview/captions/*.tsv`,
  the eight shots run: 1 signing, 2 importing a PDF, 3 signing, 4 scanning *off a screen*,
  5 signing, 6 date stamp, 7–8 folders. **Five of eight are about signing, and scanning a paper
  document — the thing the app is named for — never appears at all.** Shot 4 is the niche
  scan-from-a-monitor case, not the core one. There is also **no shot for searchable PDFs or
  on-device OCR**, which is the actual technical differentiator, and none for the privacy/iCloud
  story. Someone landing cold sees a signing app. The first three shots are what render in search
  results, so they carry most of the weight. Proposed order: (1) scan a paper document,
  (2) searchable PDF via on-device OCR, (3) private, synced through iCloud — then signing,
  importing and organisation after. Cost is not trivial: re-shooting means new base captures per
  language plus a caption re-render through `render-captions.py`, across 5 languages. Screenshots
  are version metadata, so this ships with a release, not on its own.

- **No rating prompt exists — that is why there are no ratings.** Confirmed by grep: no
  `requestReview`, no `SKStoreReviewController`, no StoreKit import anywhere in the codebase. The
  app has never asked. For a paid app this is a real conversion drag, since social proof matters
  more when there is a price gate. Apple caps the prompt at **three per user per year** and may
  suppress it entirely, so *when* it fires is the whole design: after a **completed, successful**
  action (a scan saved, a document exported), never on launch, never after an error, and not on
  first run. Needs a small amount of state — don't ask again for N days, don't ask a user who has
  scanned once. Worth checking whether this conflicts with the "focused scanning utility"
  principle; it probably doesn't, but a badly-timed prompt is exactly the kind of thing that
  earns a one-star review from someone who was otherwise happy.

**Also raised and deliberately not logged as a task:** the subtitle spends all 29 characters on a
business-model claim with no category search intent. That analysis is already in
`docs/app-store-metadata.md` under the Subtitle section, with the 2.3.7 history that complicates
it — Peter contested a rejection over that exact line and won, so changing it now would be his
call, not Apple's. Any change belongs there, not here.

### Business / pricing

- **Tip jar IAP** — one-time "Buy the developer a coffee" tiers ($1.99 / $4.99 / $9.99) in Settings. Some users like to support indie devs they like.

- **Free download + lifetime IAP** — raised by the same ASO email and **explicitly withdrawn by him**
  once he saw the positioning; recorded so it is not re-proposed from scratch. The argument for:
  removes the price gate, more installs, better ranking momentum. Against: Apple's cut is identical
  either way so there is no revenue gain in the switch itself; it needs real StoreKit 2 work
  (purchase state, restore, Family Sharing, refunds, sandbox testing) with failure modes users
  report as "I paid and lost everything"; and it forces a product decision deliberately avoided so
  far — *what is free?* — which collides with the focused-utility principle. Correct sequencing if
  ever revisited: establish a baseline from impressions-vs-downloads first, and only test this if
  the listing gets impressions but the price appears to be the blocker.

### Internationalization

- ~~**Localizable strings**~~ — **Shipped: Spanish (es-ES) + French (fr-FR) in v3.0; German (de) + Italian (it) built for v3.2.** Full in-app localization (String Catalog), localized App Store metadata and captioned screenshots for each. The app now ships in five languages with seven App Store localizations. de/it used AI-only translation with back-translation QA and no native reviewer — an accepted, recorded risk. Spec: `docs/superpowers/specs/2026-07-24-localization-de-it-design.md`; plan: `docs/superpowers/plans/2026-07-29-localization-de-it.md`; QA record: `docs/superpowers/qa/2026-07-29-de-it-back-translation.md`.

  **This is a standing obligation, not a one-off.** Every release that writes new de/it copy needs its own back-translation pass, because no later stage will catch what it misses. The v3.3 release notes got one: `docs/superpowers/qa/2026-08-28-de-it-whats-new-back-translation.md`. It found a real error — the Italian described a fix to page *tracciamento* two lines above the sign-off's *nessun tracciamento* ("no tracking"), a word that carries the surveillance sense far more strongly in Italian than "tracking" does in English. Worth knowing about the method before relying on it: **the risk is higher for prose than for labels.** The v3.2 pass covered 308 short functional labels, where the space for idiom error is small; release notes and the description are continuous marketing copy, where idiom is most of the risk — and back-translation catches idiom poorly. Two of the seven v3.3 flags back-translated perfectly cleanly and were caught only because the compounds looked invented. Both fields are store metadata, editable without an app release, which is what makes the residual risk acceptable.
- ~~**Latin-American Spanish (es-MX) + Canadian French (fr-CA) App Store variants**~~ — **Shipped in v3.1** as metadata-only listings (iOS serves es-ES to es-MX and fr-FR to fr-CA via locale fallback, so no binary change was needed). es-MX reuses the es-ES copy verbatim; fr-CA got a Quebec terminology pass (*numériser*, *application*, *courriel*).
- **Localized App Preview videos** — still open, and deferred at every release since v3.0: all locales reuse the English-UI v2.9 video (accepted, mostly visual). A localized re-record per language (device capture → CapCut → conform) removes the last English tell. Cost scales with each language added — now five.
- **OCR language detection** — Vision supports many languages but defaults to device locale. Surface a language picker in Settings for users who scan multilingual documents.
