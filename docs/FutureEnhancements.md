# Future Enhancements

A running list of ideas for future versions of Pocket Scanner, organized by intended release. Items here are *candidates*, not commitments — we may drop, defer, or reshape any of them.

Versions earlier than the current shipping release are deleted from this doc as they ship; the history is in git.

---

## Enhancements v1.3 and beyond

Lower priority. Some of these may never ship. The list exists to capture what we considered.

### Documents

- **Copy text from a scan** — the app has no `UIPasteboard` usage anywhere; you can *search* a scan's recognized text but can't *copy it out*. Add a **Copy Text** action (whole page and/or whole document) that puts the OCR text (`pdf.string` / per-page) on the clipboard — turns any scan into reusable text (a receipt total, an address, a recipe). Small effort, high everyday value, very on-brand for an OCR-first scanner. (The markup view's custom edit menu may suppress PDFView's native text-Copy, so a dedicated action is clearer regardless.)
- **Merge two documents** — combine two existing scans into one PDF. The engine already supports it (`DocumentMutations.append`); this just needs a "Merge into…" / "Combine" UI (e.g. a library multi-select, or a context-menu action that picks a target document). Useful when something was scanned across two sessions.

### Editing

- ~~**Preserve annotations across page edits**~~ — **Decided 2026-06-19: warn, don't preserve.** Editing a page (crop / rotate / filter) still rebuilds it via `DocumentMutations.replacePage`, dropping that page's highlights/strikethroughs — geometry-remapping was rejected (rare flow; hard/non-affine for crop & perspective; semantically dubious when the marked region is cropped away). Instead the editor now **confirms before discarding marks** (single Apply, plus a note in the Apply-to-all dialog) so the loss is never silent. Shipped in v1.12. (The lossless strip quick-rotate already preserves marks.)
- **Annotation rectangle-drag fallback** — annotation marks anchor to the OCR text selection, so on a poorly-recognised scan the drag-select can be imprecise. A drag-a-rectangle highlight mode would let users mark regions the OCR missed.

### Error handling

- ~~**Corrupt PDF "Try to recover"**~~ — **Dropped 2026-06-19.** All real document saves are atomic + file-coordinated (`DocumentStorage` writes with `data.write(to:options: .atomic)` inside an `NSFileCoordinator`), so an interrupted or failed save never leaves a half-written file — the user keeps the complete file or the previous one, never a corrupt one. The only remaining ways an app-created PDF could be unreadable are genuine hardware/filesystem corruption (not reliably recoverable, and bigger problems exist) or a manually sideloaded corrupt PDF (out of scope). The existing 🚫 row + confirmed Delete is a sufficient safety net. (Also: PDFKit has no lenient/repair reader, so the original "lenient reader" premise wasn't implementable.) Only adjacent value, if ever: a clear "storage full" save-error message — minor.

### Business / pricing

- ~~**Launch sale**~~ — **Run 2026-06-20** (well after launch, so reframed as a plain limited-time sale). A 1-week **Temporary Price Change** to **$2.99** (from $4.99), **Jun 21–28**, broad territories (CA / US / UK + all EU) — auto-reverts on the end date. Paired with sale **Promotional Text** (blurb A) set on **both** the live and the in-review version (promo text is per-version, so it must be on each, and reverted manually when the sale ends — the price reverts itself). Repeatable anytime: Pricing → *Temporary Price Change* for the price, Promotional Text (no review) for the message.
- **Tip jar IAP** — one-time "Buy the developer a coffee" tiers ($1.99 / $4.99 / $9.99) in Settings. Some users like to support indie devs they like.

### Internationalization

- **Localizable strings** — currently all UI is English. Likely targets: French, Spanish, German.
- **OCR language detection** — Vision supports many languages but defaults to device locale. Surface a language picker in Settings for users who scan multilingual documents.
