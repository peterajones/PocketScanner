# Future Enhancements

A running list of ideas for future versions of Pocket Scanner, organized by intended release. Items here are *candidates*, not commitments — we may drop, defer, or reshape any of them.

Versions earlier than the current shipping release are deleted from this doc as they ship; the history is in git.

---

## Enhancements v1.3 and beyond

Lower priority. Some of these may never ship. The list exists to capture what we considered.

### Search

- **In-folder cross-doc search** — `FolderContentsView`'s own searchText doesn't feed the inherited `navigationDestination`; cross-doc nav only works off `LibraryView`'s search field. Have `FolderContentsView` build its own `SearchContext` or share `LibraryView`'s binding.

### Editing

- **Rotate-in-strip** — a context-menu rotate option on edit-mode thumbnails, avoiding a trip through the per-page editor.
- **Page extraction** — multi-select + "Save as new document" to break apart a scan.
- **Preserve annotations across page edits** — annotations shipped in v1.4, but editing a page in the per-page editor (crop / rotate / filter) rebuilds the page from scratch via `DocumentMutations.replacePage`, dropping any highlights/strikethroughs on that page. A correct fix is non-trivial because a cropped / perspective-corrected page has different geometry, so marks would need re-mapping rather than re-attaching. Uncommon sequence; deferred from v1.4.
- **Annotation rectangle-drag fallback** — annotation marks anchor to the OCR text selection, so on a poorly-recognised scan the drag-select can be imprecise. A drag-a-rectangle highlight mode would let users mark regions the OCR missed.

### Error handling

- **Corrupt PDF "Try to recover"** — currently the library shows a 🚫 row with a Delete action; spec also called for a "Try to recover" action using PDFKit's lenient reader.

### Business / pricing

- **Launch sale** — drop to $2.99 for the first week post-launch, then return to $4.99. App Store users see "was $4.99, now $2.99" as a deal.
- **Tip jar IAP** — one-time "Buy the developer a coffee" tiers ($1.99 / $4.99 / $9.99) in Settings. Some users like to support indie devs they like.

### Internationalization

- **Localizable strings** — currently all UI is English. Likely targets: French, Spanish, German.
- **OCR language detection** — Vision supports many languages but defaults to device locale. Surface a language picker in Settings for users who scan multilingual documents.
