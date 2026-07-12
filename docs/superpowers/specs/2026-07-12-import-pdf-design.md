# Import a PDF — Design (v2.9 / 28)

**Status:** Approved 2026-07-12. Feature "Import a PDF" from `docs/FutureEnhancements.md`.

## Problem

Pocket Scanner is **camera-only** — there's no way to bring in an existing PDF (e.g.
a contract received by email) to sign and date it. Today the only workaround is to
open the PDF on another screen and scan it with the camera, which is awkward and
can't work when the PDF is already on the phone.

## Key finding — the ingest pipeline already exists

Investigation confirmed the app already ingests **any** PDF placed in its Documents
folder — so this feature needs **no new pipeline**, only an entry point:

- **Library lists any PDF.** `MetadataQueryLibraryStore`'s query is `%K LIKE '*.pdf'`
  — it doesn't check provenance. A PDF in the folder appears (and iCloud's live query
  updates without a manual refresh).
- **Born-digital PDFs are searchable for free.** `DocumentSummary.fromFile` sets
  `ocrSnippet: pdf.string ?? ""` (extracts text from any PDF at load), and in-viewer
  search uses PDFKit's `findString` on the PDF's real text layer.
- **View / sign / date all operate on a `PDFDocument`** — which an imported PDF is.
- **Corrupt/unreadable PDFs are already handled** (`fromFile` flags `isCorrupt`).

So the entire feature is: **a native entry point that copies an incoming PDF into the
Documents folder.** Everything downstream is reuse.

## Goal & scope

Let a user bring an existing PDF into the library (to view/sign/date/search it) via
two entry points, both writing through the existing storage layer:

1. **Document handler** — "Open in / Copy to Pocket Scanner" appears wherever the user
   has a PDF (Mail, Files, Safari). Lands the doc at **root**.
2. **In-app picker** — an **"Import PDF"** item in the `＋` menu (beside "Scan
   Document") opens the Files picker; imports into the **current context** (root or the
   folder being viewed).

**iCloud-agnostic:** import writes through `DocumentStorage`, which is built against
`ICloudContainer.resolveDocumentsURL()` — the iCloud container's `/Documents` when
signed in, the local Documents directory when not. So import is as available as
scanning is; a signed-out user imports into local storage (no sync, fully usable).
Import is in fact the *only* ingest path for signed-out users (no visible iCloud
folder to drop into).

## Non-goals (v1)

- **No OCR on import.** Born-digital PDFs are already searchable via `pdf.string`; an
  *image-only* PDF imports and is fully usable but not text-searchable. OCR-on-import
  (render → Vision → rebuild with a text layer) is a logged follow-up in
  `docs/FutureEnhancements.md`, deferred to keep v1 small.
- **No naming/confirm sheet** — silent import using the filename; the existing Rename
  covers changes.
- **Single file per import** — the picker's multi-select is an easy later flag.
- **No auto-open** to the viewer after import — the doc appears at the top of the
  library (newest-first); tapping it opens the viewer to sign/date.
- No share **extension** (a separate target/app group) — the document handler covers
  the share-sheet case without it.

## Architecture

### `PDFImporter` (the shared core)

A small, testable unit both entry points call:

```
PDFImporter.importPDF(from sourceURL: URL, using storage: DocumentStorage) throws -> URL
```

- Wraps the read in `startAccessingSecurityScopedResource()` / `stopAccessingSecurityScopedResource()`
  (incoming URLs from Files / other apps are security-scoped).
- **Validates** the file is a readable PDF: `guard let pdf = PDFDocument(url: sourceURL)`
  — else throws `PDFImporterError.unreadablePDF`.
- **Writes via the existing `DocumentStorage`**: `storage.write(pdf, preferredName: <source filename without extension>)`.
  This reuses sanitization, unique naming (`Contract` → `Contract (2)`), and the
  coordinated atomic write. The user's original file is never moved or deleted (we copy).
- Returns the new document's URL (or rethrows a storage/IO error).

`DocumentStorage` is scoped to a destination by its `documentsURL` — pass the
storage for root (document handler) or the current folder (in-app picker).

### Entry point 1 — document handler

- **Info.plist:** declare the app opens PDFs — a `CFBundleDocumentTypes` entry with
  `LSItemContentTypes = ["com.adobe.pdf"]`, role Editor. Set
  `LSSupportsOpeningDocumentsInPlace` appropriately so "Copy to / Open in Pocket
  Scanner" surfaces. (This is the first document-type declaration in the app; there
  were none before.)
- **Handling:** the SwiftUI `App` gains `.onOpenURL { url in … }`, which runs
  `PDFImporter.importPDF(from: url, using: <root storage>)`, then refreshes the library.
- Result: from any PDF, "Open in / Copy to Pocket Scanner" imports it to root.

### Entry point 2 — in-app picker

- The `＋` menu (in `LibraryView` / `FolderContentsView`) gains **"Import PDF"** beside
  "Scan Document".
- Tapping presents SwiftUI `.fileImporter(isPresented:allowedContentTypes: [.pdf], allowsMultipleSelection: false)`.
- On selection, `PDFImporter.importPDF(from: pickedURL, using: <current-view storage>)`,
  then refresh. Lands in the current context (the view's storage is already scoped to
  root or the open folder).

## Data flow

```
[PDF in Mail/Files/Safari] --Open in--> App.onOpenURL --------\
                                                               > PDFImporter.importPDF(from:using:) -> DocumentStorage.write -> /Documents/<name>.pdf
[＋ ▸ Import PDF] --.fileImporter--> pickedURL ----------------/                                            |
                                                                                                           v
                                                                              library refresh -> new doc appears at top -> tap -> view / sign / date / search
```

## Error handling

- **Not a readable PDF** (wrong type / corrupt) → `PDFImporter` throws before writing;
  the caller shows an alert (*"Couldn't import — that file isn't a readable PDF."*).
  Nothing is written.
- **Security-scoped access failure / unreadable file** → same alert; no partial state.
- **IO / write failure** → surfaced from `DocumentStorage.write`'s throwing path as an
  alert.
- **After success** → refresh the library (needed for the manual-refresh local store;
  the iCloud live query auto-updates). Reuses the scan flow's refresh-after-save.

## Testing

- **`PDFImporter` unit tests** (the real logic, testable with temp dirs + a temp
  `DocumentStorage`):
  1. valid PDF source → a file is written into the destination with the filename, and
     it reloads as a valid PDF (page count preserved).
  2. name collision (destination already has `Contract.pdf`) → the import gets a
     unique suffixed name; both files exist.
  3. invalid / non-PDF source (e.g. a text file) → throws `unreadablePDF`, nothing
     written.
- **Entry points** (`onOpenURL`, `.fileImporter`, Info.plist declaration) are thin
  UI/config wiring → verified on-device in the smoke test:
  - Tap a PDF in Files → **Open in / Copy to Pocket Scanner** → it appears in the
    library, opens, is searchable (for a born-digital PDF), signable, datable.
  - `＋ → Import PDF` → pick a PDF → it appears in the current folder.
  - Signed-out (local storage) import works too.

## Files (anticipated)

- **Create** `DocumentScanner/DocumentScanner/Import/PDFImporter.swift` — the shared
  import core + `PDFImporterError`.
- **Modify** `DocumentScanner/DocumentScanner/Info.plist` — add `CFBundleDocumentTypes`
  (PDF) + `LSSupportsOpeningDocumentsInPlace`.
- **Modify** `DocumentScanner/DocumentScanner/App/DocumentScannerApp.swift` — `.onOpenURL`
  handling → import to root + refresh.
- **Modify** `DocumentScanner/DocumentScanner/Library/LibraryView.swift` and
  `FolderContentsView.swift` — "Import PDF" menu item + `.fileImporter` + error alert.
- **Create** `DocumentScanner/DocumentScannerTests/PDFImporterTests.swift`.
- Update `docs/FutureEnhancements.md` (mark Import a PDF built) in the same session.
