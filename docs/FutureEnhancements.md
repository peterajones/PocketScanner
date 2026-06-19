# Future Enhancements

A running list of ideas for future versions of Pocket Scanner, organized by intended release. Items here are *candidates*, not commitments — we may drop, defer, or reshape any of them.

Versions earlier than the current shipping release are deleted from this doc as they ship; the history is in git.

---

## Enhancements v1.3 and beyond

Lower priority. Some of these may never ship. The list exists to capture what we considered.

### Editing

- **Preserve annotations across page edits** — annotations shipped in v1.4, but editing a page in the per-page editor (crop / rotate / filter) rebuilds the page from scratch via `DocumentMutations.replacePage`, dropping any highlights/strikethroughs on that page. A correct fix is non-trivial because a cropped / perspective-corrected page has different geometry, so marks would need re-mapping rather than re-attaching. Uncommon sequence; deferred from v1.4.
- **Annotation rectangle-drag fallback** — annotation marks anchor to the OCR text selection, so on a poorly-recognised scan the drag-select can be imprecise. A drag-a-rectangle highlight mode would let users mark regions the OCR missed.

### Error handling

- **Corrupt PDF "Try to recover"** — currently the library shows a 🚫 row with a Delete action; spec also called for a "Try to recover" action using PDFKit's lenient reader.

### App Store presence

An ongoing effort (not a one-off) to make the listing look professional. Today's
preview images are screenshots that read as amateur; the better-looking apps lead
with an **App Preview** (the autoplay video in the first slot) followed by framed
static shots.

- **Device-frame template** — *first deliverable*. A single layered source file with
  the iPhone 17 chrome as the background layer and a blank (transparent) viewport
  cut-out, into which the App Preview video frame and the static screenshot layers
  can be dropped. End state: one master file where each marketing shot is a layer
  composited inside consistent device chrome.
  - Open decisions: which tool / file format for the layered master (Figma, Sketch,
    Photoshop PSD, Affinity); exact App Store screenshot pixel dimensions for the
    required display sizes; where the canonical chrome asset comes from (Apple's
    marketing resources vs. a third-party device-frame kit).
- **App Preview video** — a short (≤30s) screen-recorded walkthrough for slot 1:
  scan → pick a filter → annotate → rotate → search. Produced inside the template's
  viewport so it sits in the same device frame as the static shots.
- **Refreshed static screenshots** — re-shoot the static slots through the template
  so the whole gallery looks consistent and intentional.

### Business / pricing

- **Launch sale** — drop to $2.99 for the first week post-launch, then return to $4.99. App Store users see "was $4.99, now $2.99" as a deal.
- **Tip jar IAP** — one-time "Buy the developer a coffee" tiers ($1.99 / $4.99 / $9.99) in Settings. Some users like to support indie devs they like.

### Internationalization

- **Localizable strings** — currently all UI is English. Likely targets: French, Spanish, German.
- **OCR language detection** — Vision supports many languages but defaults to device locale. Surface a language picker in Settings for users who scan multilingual documents.
