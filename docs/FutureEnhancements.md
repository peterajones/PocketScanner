# Future Enhancements

A running list of ideas for future versions of Pocket Scanner. Items here are *candidates*, not commitments — we may drop, defer, or reshape any of them.

Shipped and dropped items are deleted from this doc as they resolve; the history is in git, and the release log lives in the project-status memory.

---

## Candidates (nothing committed)

Lower priority. Some of these may never ship. The list exists to capture what we've considered.

### Import a PDF (bring in an emailed document)

Today Pocket Scanner is **camera-only** — no `CFBundleDocumentTypes`, no Share
extension, no "Open in Pocket Scanner," no file picker. So the only way to get an
emailed PDF in (to sign/date it) is to open it on another screen and scan it with
the camera — which can't work when the PDF is already on the phone. A **Share-sheet
/ document import** (Share → Pocket Scanner, or a Files picker) would let a received
PDF drop straight in → sign → date, closing the "no printer" loop completely. Pairs
naturally with the v2.7–v2.8 sign+date work, and would make the "handle an emailed
contract" story seamless instead of a screen-scan workaround. (Surfaced 2026-07-10
while shooting the App Store media.)

### Signing follow-ups

The core signing project is complete — sign a document, multiple signatures, single-shot capture, signature names, and iCloud sync all shipped through v2.7.

- ~~**Date stamp**~~ — **Built (branch `feature/date-stamp`).** Viewer "Date" button → sheet with a date picker (defaults to today) + 5 fixed format presets (`2026-07-09` · `07/09/2026` · `09/07/2026` · `July 9, 2026` · `9 July 2026`, `en_US_POSIX`), previewed live and last-used remembered (`@AppStorage("dateStampFormat")`). The chosen date renders to a transparent image (`DateStampRenderer`) and is placed via the existing signature machinery (`SignaturePlacementView` drag/resize → `ImageStampAnnotation` tagged `dateStampAnnotationName`, rendered date string in `contents` so Move re-renders it across save→reload). Initials dropped (scannable via multi-signatures); free text excluded (editor-ish). Built inline (222 unit tests pass; the Add-Date sheet + Date alert live in a `dateStampContent` helper to stay under the SwiftUI type-checker budget). Spec/plan under `docs/superpowers/` dated 2026-07-09.

**Maybe (parked — genuine value, but meaningful error/UX risk):**

- **Auto-detect the signature line** — find the "X_____" line and offer to place there. Too much room for error, especially on long/multi-page documents.
- **Sign multiple pages at once** — apply a placed signature across a page range. Same error/UX concern as auto-detect.

**Dropped:** typed / finger-drawn signatures — typed text can't be placed cleanly (stamps are the better path), and finger-drawn signatures always look bad.

### Business / pricing

- **Tip jar IAP** — one-time "Buy the developer a coffee" tiers ($1.99 / $4.99 / $9.99) in Settings. Some users like to support indie devs they like.

### Internationalization

- **Localizable strings** — currently all UI is English. Likely targets: French, Spanish, German.
- **OCR language detection** — Vision supports many languages but defaults to device locale. Surface a language picker in Settings for users who scan multilingual documents.
