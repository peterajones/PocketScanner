# Future Enhancements

A running list of ideas for future versions of Pocket Scanner. Items here are *candidates*, not commitments — we may drop, defer, or reshape any of them.

Shipped and dropped items are deleted from this doc as they resolve; the history is in git, and the release log lives in the project-status memory.

---

## Candidates (nothing committed)

Lower priority. Some of these may never ship. The list exists to capture what we've considered.

### Signing follow-ups

The core signing project is complete — sign a document, multiple signatures, single-shot capture, signature names, and iCloud sync all shipped through v2.7.

- **Initials / date / text stamps** — quick reusable stamps beyond a signature (dating a document is a common real need alongside signing). **Currently exploring (2026-07-09).**

**Maybe (parked — genuine value, but meaningful error/UX risk):**

- **Auto-detect the signature line** — find the "X_____" line and offer to place there. Too much room for error, especially on long/multi-page documents.
- **Sign multiple pages at once** — apply a placed signature across a page range. Same error/UX concern as auto-detect.

**Dropped:** typed / finger-drawn signatures — typed text can't be placed cleanly (stamps are the better path), and finger-drawn signatures always look bad.

### Business / pricing

- **Tip jar IAP** — one-time "Buy the developer a coffee" tiers ($1.99 / $4.99 / $9.99) in Settings. Some users like to support indie devs they like.

### Internationalization

- **Localizable strings** — currently all UI is English. Likely targets: French, Spanish, German.
- **OCR language detection** — Vision supports many languages but defaults to device locale. Surface a language picker in Settings for users who scan multilingual documents.
