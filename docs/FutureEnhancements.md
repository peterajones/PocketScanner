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

### Business / pricing

- **Tip jar IAP** — one-time "Buy the developer a coffee" tiers ($1.99 / $4.99 / $9.99) in Settings. Some users like to support indie devs they like.

### Internationalization

- **Localizable strings** — currently all UI is English. Likely targets: French, Spanish, German.
- **OCR language detection** — Vision supports many languages but defaults to device locale. Surface a language picker in Settings for users who scan multilingual documents.
