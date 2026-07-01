# Future Enhancements

A running list of ideas for future versions of Pocket Scanner, organized by intended release. Items here are *candidates*, not commitments — we may drop, defer, or reshape any of them.

Versions earlier than the current shipping release are deleted from this doc as they ship; the history is in git.

---

## Enhancements v1.3 and beyond

Lower priority. Some of these may never ship. The list exists to capture what we considered.

### Documents

- ~~**Copy text from a scan**~~ — **Dropped 2026-06-23: already delivered by iOS.** The viewer's invisible OCR text layer is selectable, and `MarkupPDFView.buildMenu` calls `super.buildMenu` (keeping the system edit menu) and only *appends* Highlight/Strikethrough. So the OS already provides **Copy** for a text selection, **Select All → Copy** for the whole document (PDFView selects across all pages), plus Look Up / Translate. Both real cases — grab specific facts (select snippet) and grab everything (Select All) — work today. The only gap is one-tap **"Copy current page"**, which is marginal (you can drag-select a page, and the common cases are covered) and not worth the added menu item. (The earlier "may suppress native Copy" worry was wrong — it doesn't.)
- ~~**Merge two documents (v2.2)**~~ — **Shipped 2026-06-25.** Long-press a document → **Merge into…** → pick a target; the source's pages append to the end of the target (lossless — OCR text + annotations preserved), the target keeps its name/location, and the source is deleted (confirmed first). Pure `MergeCandidates` (targets = all other non-corrupt docs) + `DocumentMerge` orchestration (append → save target in place → delete source, in that safe order) + `MergeIntoMenu`; wired into both `LibraryView` and `FolderContentsView` via a shared `MergeAlerts` modifier. Spec: `docs/superpowers/specs/2026-06-25-merge-documents-design.md`.
- **Scan to a chosen folder** — today a new scan always lands in the main library root; the user then has to Move it into a folder. Let the Save flow pick a destination folder (and create a new one inline) so scans file themselves. Rough shape: the Save sheet (`NameDocumentSheet`) gains a destination picker defaulting to the current context (root, or the folder you're already inside), listing existing folders + a "New Folder…" option; the chosen folder scopes where `DocumentStorage` writes (folders are already real subfolders — see the Merge work that self-scopes storage to the target's folder, and the existing Move-to-folder plumbing from v1.3). Open questions: remember the last-used destination vs. always default to current context; whether folder creation belongs in the scan flow or should reuse a single "New Folder" affordance in the library. iCloud-friendly since folders already sync as subfolders.

### Editing

- ~~**Preserve annotations across page edits**~~ — **Decided 2026-06-19: warn, don't preserve.** Editing a page (crop / rotate / filter) still rebuilds it via `DocumentMutations.replacePage`, dropping that page's highlights/strikethroughs — geometry-remapping was rejected (rare flow; hard/non-affine for crop & perspective; semantically dubious when the marked region is cropped away). Instead the editor now **confirms before discarding marks** (single Apply, plus a note in the Apply-to-all dialog) so the loss is never silent. Shipped in v1.12. (The lossless strip quick-rotate already preserves marks.)
- ~~**Annotation rectangle-drag fallback**~~ — **Superseded 2026-06-22 by Signing.** Free-form (non-text-anchored) placement now exists via the signature stamp (`ImageStampAnnotation` placed at arbitrary page coords). If a generic drag-a-rectangle *highlight* is still wanted later, it would reuse the same placement plumbing.

### Signing

- **Sign a document (v2.0)** — scan your signature on paper → auto-clean to a transparent cut-out (`SignatureProcessor`: B&W → key white→alpha → largest-ink-band crop) → save a reusable signature (`SignatureStore`, Settings ▸ Signature) → **Sign** in the viewer drops it as a drag/resize stamp on the page you're viewing; persists as an editable annotation you can **Move** or **Remove**. Built subagent-driven; a front-loaded spike proved image stamp annotations persist *and render* across save→reload (so no flatten needed).
- **Multiple signatures (v2.x)** — `SignatureStore` is now a collection (`<uuid>.png` files, newest-first; legacy single `signature.png` auto-migrated); Settings shows a thumbnail list with swipe-to-delete + Add; **Sign** shows a picker when 2+ exist (places directly for one); the placed annotation carries its signature id in PDF `contents` so **Move** re-places the *same* signature (picker fallback if it was deleted). Local, thumbnail-only (no names). Storage kept iCloud-ready.
- ~~**Single-shot signature capture (v2.1)**~~ — **Shipped 2026-06-25** (merged to `main`; ships with the next archive as v2.1). "Add Signature" now opens a single-photo `UIImagePickerController(.camera)` (`Capture/SingleShotCameraScanner.swift`) instead of the multi-page `VNDocumentCameraViewController`, killing the auto-fire multi-capture; document scanning is unchanged. Crop restored via the native **Move & Scale** (`allowsEditing`, fixed-square frame). Three `SignatureProcessor` fixes the raw-photo path exposed (all latent behind VNDocumentCamera's enhancement): honor `imageOrientation` (portrait `.right` capture saved rotated); **flat-field correction** (divide by a blurred illumination estimate) to cancel the lighting vignette that left a halo; and an `inkBounds` ~2% perimeter-margin skip to drop the faint edge rim that inflated the crop. Spec: `docs/superpowers/specs/2026-06-24-single-shot-signature-capture-design.md`.
- **Signature names/labels + reordering (v2.3)** — round out the signatures story: give each stored signature a name/label (currently thumbnail-only) and let the list be reordered, so a multi-signature user can tell them apart and control order. `SignatureStore` is already a keyed collection; this is a naming field + persisted order + Settings-list UI (rename, drag-to-reorder). Not started — brainstorm/plan when v2.3 kicks off.
- **Other Signing follow-ups (unscheduled):** **iCloud sync** the signatures across devices (storage is sync-ready); typed / on-screen-drawn signatures; initials / date / text stamps; auto-detect the signature line; sign multiple pages at once.

### Error handling

- ~~**Corrupt PDF "Try to recover"**~~ — **Dropped 2026-06-19.** All real document saves are atomic + file-coordinated (`DocumentStorage` writes with `data.write(to:options: .atomic)` inside an `NSFileCoordinator`), so an interrupted or failed save never leaves a half-written file — the user keeps the complete file or the previous one, never a corrupt one. The only remaining ways an app-created PDF could be unreadable are genuine hardware/filesystem corruption (not reliably recoverable, and bigger problems exist) or a manually sideloaded corrupt PDF (out of scope). The existing 🚫 row + confirmed Delete is a sufficient safety net. (Also: PDFKit has no lenient/repair reader, so the original "lenient reader" premise wasn't implementable.) Only adjacent value, if ever: a clear "storage full" save-error message — minor.

### Business / pricing

- ~~**Launch sale**~~ — **Run 2026-06-20** (well after launch, so reframed as a plain limited-time sale). A 1-week **Temporary Price Change** to **$2.99** (from $4.99), **Jun 21–28**, broad territories (CA / US / UK + all EU) — auto-reverts on the end date. Paired with sale **Promotional Text** (blurb A) set on **both** the live and the in-review version (promo text is per-version, so it must be on each, and reverted manually when the sale ends — the price reverts itself). Repeatable anytime: Pricing → *Temporary Price Change* for the price, Promotional Text (no review) for the message.
- **Tip jar IAP** — one-time "Buy the developer a coffee" tiers ($1.99 / $4.99 / $9.99) in Settings. Some users like to support indie devs they like.

### Internationalization

- **Localizable strings** — currently all UI is English. Likely targets: French, Spanish, German.
- **OCR language detection** — Vision supports many languages but defaults to device locale. Surface a language picker in Settings for users who scan multilingual documents.
