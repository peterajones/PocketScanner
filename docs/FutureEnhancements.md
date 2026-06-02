# Future Enhancements

A running list of ideas for future versions of Pocket Scanner, organized by intended release. Items here are *candidates*, not commitments — we may drop, defer, or reshape any of them.

Versions earlier than the current shipping release are deleted from this doc as they ship; the history is in git.

---

## Enhancements v1.2 and beyond

Lower priority. Some of these may never ship. The list exists to capture what we considered.

### Polish

- **Sample document on first launch** — pre-populate the library with a "Welcome.pdf" so the empty state has something to demonstrate features against. Removed on first user delete.
- **App Icon variants** — let users pick from a few styles (light, dark, minimal) via iOS 14.3+'s alternate icons API. Power-user feature.

### Filters

- **Make all filter presets more pronounced** — each filter currently looks almost identical to "Color" when you flip through them, which defeats the picker. Goal: when the user cycles through Color → Greyscale → B&W → Photo, each step looks visibly different even at thumbnail size. Concretely:
    - **B&W** — replace `CIPhotoEffectNoir` with high-contrast monochrome (`CIColorControls` saturation=0, contrast≈1.8, brightness≈+0.15) so backgrounds go paper-white and text goes solid black, matching Apple Notes' scanner output.
    - **Greyscale** — keep saturation=0 but bump contrast (~1.3) so the page isn't muddy grey.
    - **Photo** — increase saturation to ~1.5 and contrast to ~1.3 so the difference vs Color is obvious.
- **Filter at scan time** — pick a filter in the Name & Save sheet before the initial save, applied to every page of that scan. Faster than entering per-page editor for each.

### Search

- **Horizontal highlight accuracy** — currently highlights are vertically accurate but horizontally approximate (system font width ≠ original glyph width). Fix: scale the invisible text horizontally to match each `VNRecognizedTextObservation`'s `boundingBox` width.
- **Cross-document match navigation** — search results currently break context when you tap into a document. Could surface "Match 1 of 7 across 3 documents" with cross-doc prev/next.

### Editing

- **Rotate-in-strip** — a context-menu rotate option on edit-mode thumbnails, avoiding a trip through the per-page editor.
- **Page extraction** — multi-select + "Save as new document" to break apart a scan.

### Library

- **Sort options** — by date, by name, by page count. Currently always newest-first.
- **Grid view** — alternate to list view, larger thumbnails. Useful for visually-driven workflows.

### Platform reach

- **Widget** — recent scans on the home screen. Small (single doc) and medium (4-doc grid) variants.
- **Shortcuts integration** — App Intent for "Scan a document with Pocket Scanner" via Siri / Shortcuts app.
- **iPad layout** — bring back iPad support with a split-view layout (sidebar list + viewer pane) that uses the larger screen properly. Different from "iPhone app on iPad" stretched mode.

### Error handling (verification)

These code paths exist but were never exercised on a real device. v1.2 should provoke each and confirm the UX works:

- **Storage-full save failure** — fill the device, attempt a scan, verify the AlertCenter retry path works.
- **NSFileVersion conflict** — edit the same doc on two devices simultaneously, verify the picker UI works.
- **Corrupt PDF "Try to recover"** path — currently the library shows a 🚫 row with a Delete action; spec also called for a "Try to recover" action using PDFKit's lenient reader.

### Business / pricing

- **Launch sale** — drop to $2.99 for the first week post-launch, then return to $4.99. App Store users see "was $4.99, now $2.99" as a deal.
- **Tip jar IAP** — one-time "Buy the developer a coffee" tiers ($1.99 / $4.99 / $9.99) in Settings. Some users like to support indie devs they like.

### Internationalization

- **Localizable strings** — currently all UI is English. Likely targets: French, Spanish, German.
- **OCR language detection** — Vision supports many languages but defaults to device locale. Surface a language picker in Settings for users who scan multilingual documents.
