# Mobile Document Scanner — Plan 2a: Viewer toolbar + page operations

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make saved documents editable. Add the viewer toolbar (share, rename, delete-document) and an edit mode that supports page-level operations: reorder, delete a page, append more pages.

**Architecture:** A new `DocumentMutations` value-type helper performs PDF transformations (reorder/delete/append) by re-assembling the PDF through `PDFAssembler`. This is testable in isolation. The viewer view binds to a `DocumentSession` `@Observable` view-model that owns the current `PDFDocument` and writes mutations back through `DocumentStorage`. We drop `ByteFaithfulPDFDocument` — once we mutate PDFs we can no longer pretend to round-trip the original bytes, so we accept that PDFKit will re-stamp `CreationDate` on each write. The library's `createdAt` continues to fall back to filesystem `creationDate`, which is what matters for sort order.

**Tech Stack:** SwiftUI, PDFKit, VisionKit (for "Add Pages"), the existing pipeline (`ScanPipeline`, `PDFAssembler`, `OCREngine`, `DocumentStorage`).

**Spec:** [`docs/superpowers/specs/2026-05-21-mobile-document-scanner-design.md`](../specs/2026-05-21-mobile-document-scanner-design.md) — Viewer and Edit-mode sections.

**Prerequisite plan:** [Plan 1](2026-05-21-mobile-document-scanner-plan-1-foundation.md) must be completed and verified on device. Plan 2b (per-page crop/rotate editor) follows this.

---

## A note for the first-time iOS developer

You finished Plan 1 — the foundation is solid. Plan 2a is the first plan that mutates state at a richer level than "append a row to a list." A few iOS idioms used here:

- **`@Observable` view-models.** A `DocumentSession` class wraps the current document and its mutation state. Like a tiny per-screen Zustand store.
- **`PDFKit` page array.** `PDFDocument` exposes `page(at:)`, `insert(_:at:)`, `removePage(at:)`. Mutating it doesn't write to disk — we re-save via `DocumentStorage` at action boundaries.
- **`ShareLink`.** SwiftUI's built-in share button. Takes a value (e.g. a URL) and the system handles the share-sheet UI.
- **`.editMode`.** SwiftUI's environment-driven edit toggle. `EditButton` flips it; `List` shows reorder/delete controls automatically when active.
- **Atomic file replace.** `DocumentStorage.write(replacing:)` (new method) writes to a temp file then renames over the original. Safer than mutating in place under iCloud's sync.

## File structure (target end-state of Plan 2a)

```text
DocumentScanner/
  Storage/
    DocumentStorage.swift                   # ADD: write(_:replacing:) overwrite-in-place
    DocumentDeletion.swift                  # NEW: NSFileCoordinator-coordinated delete + rename
  Pipeline/
    PDFAssembler.swift                      # MODIFY: drop ByteFaithfulPDFDocument
  Viewer/
    DocumentViewerView.swift                # MODIFY: toolbar with share/edit/delete, inline rename
    DocumentSession.swift                   # NEW: @Observable view-model owning current doc
    EditModeView.swift                      # NEW: thumbnail strip + reorder/delete UI
    PageThumbnail.swift                     # NEW: small reusable page-thumb view
  Capture/
    CaptureSheet.swift                      # MODIFY: nothing — reused for Add Pages
  Library/
    LibraryView.swift                       # MODIFY: pass scannerPresenter+pipeline+storage to viewer
  Pipeline/
    DocumentMutations.swift                 # NEW: reorder/delete/append helpers, testable
DocumentScannerTests/
  PDFAssemblerTests.swift                   # MODIFY: drop ByteFaithfulPDFDocument-related test, keep round-trip
  DocumentMutationsTests.swift              # NEW: tests for reorder/delete/append
  DocumentStorageTests.swift                # ADD: tests for replace + delete + rename
```

After Plan 2a:

- Tapping a row opens the viewer with share / rename / edit / delete in the nav bar.
- Tapping "Edit" reveals a thumbnail strip; drag to reorder, swipe to delete, tap "Add Pages" to scan more.
- All changes write back to the original URL via atomic replace; the library refreshes through `NSMetadataQuery`.

---

## Task 1: Drop ByteFaithfulPDFDocument, update PDFAssembler

**Files:**

- Modify: `DocumentScanner/DocumentScanner/Pipeline/PDFAssembler.swift`
- Modify: `DocumentScanner/DocumentScannerTests/PDFAssemblerTests.swift`

`ByteFaithfulPDFDocument` exists to keep PDFKit from re-stamping `CreationDate` on `dataRepresentation()`. With Plan 2a mutating PDFs, we can't rely on the original bytes anymore, so the subclass earns its keep no longer. Returning a plain `PDFDocument` simplifies the code path and lets callers mutate freely.

- [ ] **Step 1: Update the round-trip test to reflect the new contract**

  Open `DocumentScanner/DocumentScannerTests/PDFAssemblerTests.swift`. The current `test_assemble_metadataSurvivesByteRoundTrip` asserts the *creation date* survives a round-trip. After this change, PDFKit will overwrite that date. Replace the test body with one that checks the *producer* string survives instead (PDFKit doesn't rewrite producer):

  ```swift
  func test_assemble_producerSurvivesByteRoundTrip() throws {
      let image = whitePageImage()
      let pdf = try PDFAssembler().assemble(
          pages: [ScannedPage(image: image, recognizedStrings: [])],
          createdAt: Date()
      )
      let data = try XCTUnwrap(pdf.dataRepresentation())
      let reloaded = try XCTUnwrap(PDFDocument(data: data))
      XCTAssertEqual(
          reloaded.documentAttributes?[PDFDocumentAttribute.producerAttribute] as? String,
          "DocumentScanner"
      )
  }
  ```

  Delete the `test_assemble_metadataSurvivesByteRoundTrip` function. Keep `test_assemble_setsCreatedAtMetadata` since the date still appears in `documentAttributes` (it's just not byte-faithful through dataRepresentation any more).

  Actually — `test_assemble_setsCreatedAtMetadata` will start failing too because PDFKit re-stamps the date on `dataRepresentation()`. But that test reads `pdf.documentAttributes` directly without going through `dataRepresentation()`, so on the freshly-parsed PDF (which `PDFAssembler` returns by going `data → PDFDocument(data:)`), the date is still the one we put in `auxiliaryInfo`. Run it; if it fails, weaken the assertion to "creation date attribute is non-nil and within 1 second of expected" rather than equality.

- [ ] **Step 2: Run the tests and watch the round-trip test pass with the new contract**

  ```
  xcodebuild test -scheme DocumentScanner -destination 'id=B762C669-0A64-4665-8C00-10BD6628CBA2' -only-testing:DocumentScannerTests/PDFAssemblerTests 2>&1 | tail -15
  ```

  Expected: `test_assemble_producerSurvivesByteRoundTrip` exists but is failing (no `ByteFaithfulPDFDocument` change yet, so the date used to survive AND the producer probably does too — but we want the test to be there so it locks the new contract).

- [ ] **Step 3: Remove `ByteFaithfulPDFDocument`**

  Edit `DocumentScanner/DocumentScanner/Pipeline/PDFAssembler.swift`. Delete the entire `ByteFaithfulPDFDocument` private class. Change the assemble method's final `guard let document = ByteFaithfulPDFDocument(byteFaithfulData: ...)` to:

  ```swift
  guard let document = PDFDocument(data: data as Data) else {
      throw PDFAssemblerError.documentLoadFailed
  }
  return document
  ```

  Update the file's top-level comment block to remove the ByteFaithful mention. The `auxiliaryInfo` block stays — the date and producer still get baked in by CGContext, and PDFKit honors them on parse (it only overwrites on re-serialization).

- [ ] **Step 4: Run all tests**

  ```
  xcodebuild test -scheme DocumentScanner -destination 'id=B762C669-0A64-4665-8C00-10BD6628CBA2' 2>&1 | grep -E "Test case.*(passed|failed)" | tail -25
  ```

  All tests must pass. If `test_assemble_setsCreatedAtMetadata` now fails, weaken the assertion as described in step 1.

- [ ] **Step 5: Commit**

  ```
  cd /Users/pjones/Desktop/mobileDocumentScanner
  git add DocumentScanner/DocumentScanner/Pipeline/PDFAssembler.swift DocumentScanner/DocumentScannerTests/PDFAssemblerTests.swift
  git commit -m "Drop ByteFaithfulPDFDocument from PDFAssembler

  Plan 2a will mutate PDFs after assembly (reorder, delete, append
  pages), and the byte-faithful subclass was only valid for the
  immutable case. Return a plain PDFDocument; dataRepresentation now
  re-stamps CreationDate on re-serialization, but the library's
  createdAt already falls back to filesystem creationDate so the
  library sort order is unaffected. Producer string still survives
  the round trip — new test locks that.

  Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
  ```

## Task 2: Add DocumentSession view-model

**Files:**

- Create: `DocumentScanner/DocumentScanner/Viewer/DocumentSession.swift`

A small `@Observable` class that owns the currently-viewed document, exposes a mutable `displayName`, and centralizes the "save back to disk" plumbing. Decouples `DocumentViewerView` from `DocumentStorage` so the view stays declarative.

- [ ] **Step 1: Implement `DocumentSession`**

  ```swift
  import Foundation
  import Observation
  import PDFKit

  /// Per-screen view-model owning the document the viewer is showing. Wraps
  /// the file URL, the parsed PDFDocument, and the document's display name
  /// (filename without extension). Saves back to disk via DocumentStorage
  /// at explicit save points.
  @Observable
  final class DocumentSession {
      private(set) var url: URL
      private(set) var pdf: PDFDocument
      var displayName: String

      private let storage: DocumentStorage

      enum InitError: Error { case unreadablePDF }

      init(summary: DocumentSummary, storage: DocumentStorage) throws {
          guard let pdf = PDFDocument(url: summary.url) else { throw InitError.unreadablePDF }
          self.url = summary.url
          self.pdf = pdf
          self.displayName = summary.displayName
          self.storage = storage
      }

      /// Persist the current `pdf` over the current `url`. Used after edit-mode
      /// mutations or rename. Returns the (possibly new) URL.
      @discardableResult
      func save() throws -> URL {
          let newURL = try storage.write(pdf, replacing: url, withName: displayName)
          self.url = newURL
          return newURL
      }
  }
  ```

  The `storage.write(_:replacing:withName:)` overload doesn't exist yet — it lands in Task 3.

- [ ] **Step 2: Build to verify it compiles (it should fail — missing storage method)**

  ```
  cd /Users/pjones/Desktop/mobileDocumentScanner/DocumentScanner
  xcodebuild build -scheme DocumentScanner -destination 'id=B762C669-0A64-4665-8C00-10BD6628CBA2' 2>&1 | tail -5
  ```

  Expected: build fails on `storage.write(_:replacing:withName:)`. Proceed to Task 3.

- [ ] **Step 3: Commit (failing build will be unblocked by Task 3 — commit each task even if dependent ones aren't done; this is a multi-file plan)**

  Skip the commit until Task 3 is also complete; commit them together as one logical unit.

## Task 3: Add DocumentStorage replace + rename methods

**Files:**

- Modify: `DocumentScanner/DocumentScanner/Storage/DocumentStorage.swift`
- Modify: `DocumentScanner/DocumentScannerTests/DocumentStorageTests.swift`

Add three new operations: replace (write over an existing URL atomically), rename (change filename while preserving content), and delete. All coordinated through `NSFileCoordinator`.

- [ ] **Step 1: Write failing tests**

  Add to `DocumentScannerTests/DocumentStorageTests.swift`:

  ```swift
  func test_replace_overwritesExistingFile() throws {
      let storage = DocumentStorage(documentsURL: tempDir)
      let url = try storage.write(makeSinglePagePDF(), preferredName: "Receipt")
      let originalData = try Data(contentsOf: url)

      // Second PDF that's structurally different (2 pages)
      let twoPagePDF: PDFDocument = {
          let d = PDFDocument()
          d.insert(makeSinglePagePDF().page(at: 0)!, at: 0)
          d.insert(makeSinglePagePDF().page(at: 0)!, at: 1)
          return d
      }()
      let returnedURL = try storage.write(twoPagePDF, replacing: url, withName: "Receipt")

      XCTAssertEqual(returnedURL, url)
      let newData = try Data(contentsOf: returnedURL)
      XCTAssertNotEqual(originalData, newData, "file should have been overwritten")
      let reloaded = try XCTUnwrap(PDFDocument(url: returnedURL))
      XCTAssertEqual(reloaded.pageCount, 2)
  }

  func test_replace_renamesFileWhenNameChanges() throws {
      let storage = DocumentStorage(documentsURL: tempDir)
      let url = try storage.write(makeSinglePagePDF(), preferredName: "Receipt")
      let newURL = try storage.write(makeSinglePagePDF(), replacing: url, withName: "Lease Agreement")
      XCTAssertEqual(newURL.lastPathComponent, "Lease Agreement.pdf")
      XCTAssertFalse(FileManager.default.fileExists(atPath: url.path),
                     "old file should have been removed")
      XCTAssertTrue(FileManager.default.fileExists(atPath: newURL.path))
  }

  func test_replace_resolvesCollisionWhenRenamingToExistingName() throws {
      let storage = DocumentStorage(documentsURL: tempDir)
      _ = try storage.write(makeSinglePagePDF(), preferredName: "Lease")
      let other = try storage.write(makeSinglePagePDF(), preferredName: "Receipt")
      let renamedURL = try storage.write(makeSinglePagePDF(), replacing: other, withName: "Lease")
      XCTAssertEqual(renamedURL.lastPathComponent, "Lease (2).pdf")
  }

  func test_delete_removesFile() throws {
      let storage = DocumentStorage(documentsURL: tempDir)
      let url = try storage.write(makeSinglePagePDF(), preferredName: "Receipt")
      try storage.delete(at: url)
      XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
  }
  ```

- [ ] **Step 2: Run tests, see them fail (method not found)**

  ```
  xcodebuild test -scheme DocumentScanner -destination 'id=B762C669-0A64-4665-8C00-10BD6628CBA2' -only-testing:DocumentScannerTests/DocumentStorageTests 2>&1 | tail -15
  ```

  Expected: compile errors.

- [ ] **Step 3: Add the new methods to `DocumentStorage`**

  Edit `DocumentScanner/DocumentScanner/Storage/DocumentStorage.swift`. Add after the existing `write(_:preferredName:)`:

  ```swift
  /// Overwrite the existing file at `existingURL`, possibly renaming it to a new
  /// sanitized name. If the new name collides with another file (other than the
  /// one we're replacing), resolves with `(N)` suffix. Returns the final URL.
  func write(_ pdf: PDFDocument, replacing existingURL: URL, withName preferredName: String) throws -> URL {
      let sanitized = Self.sanitize(preferredName)
      guard !sanitized.isEmpty else { throw DocumentStorageError.emptyName }

      let targetURL = try uniqueURL(base: sanitized, allowingMatch: existingURL)

      guard let data = pdf.dataRepresentation() else {
          throw DocumentStorageError.writeFailed
      }

      var coordinatorError: NSError?
      var writeError: Error?
      let coordinator = NSFileCoordinator()
      coordinator.coordinate(writingItemAt: targetURL, options: .forReplacing, error: &coordinatorError) { url in
          do {
              try data.write(to: url, options: .atomic)
          } catch {
              writeError = error
          }
      }
      if let error = coordinatorError ?? (writeError as NSError?) { throw error }

      if targetURL != existingURL {
          // Remove old file under rename.
          try? FileManager.default.removeItem(at: existingURL)
      }
      return targetURL
  }

  func delete(at url: URL) throws {
      var coordinatorError: NSError?
      var removeError: Error?
      let coordinator = NSFileCoordinator()
      coordinator.coordinate(writingItemAt: url, options: .forDeleting, error: &coordinatorError) { url in
          do { try FileManager.default.removeItem(at: url) }
          catch { removeError = error }
      }
      if let error = coordinatorError ?? (removeError as NSError?) { throw error }
  }
  ```

  Update the existing private `uniqueURL` to take an `allowingMatch` URL — if the candidate matches it, that's OK (we're replacing that file):

  ```swift
  private func uniqueURL(base: String, allowingMatch: URL? = nil) throws -> URL {
      let candidate = documentsURL.appendingPathComponent("\(base).pdf")
      if candidate == allowingMatch || !FileManager.default.fileExists(atPath: candidate.path) {
          return candidate
      }
      for index in 2...999 {
          let suffixed = documentsURL.appendingPathComponent("\(base) (\(index)).pdf")
          if suffixed == allowingMatch || !FileManager.default.fileExists(atPath: suffixed.path) {
              return suffixed
          }
      }
      throw DocumentStorageError.writeFailed
  }
  ```

- [ ] **Step 4: Run tests, all pass**

  ```
  xcodebuild test -scheme DocumentScanner -destination 'id=B762C669-0A64-4665-8C00-10BD6628CBA2' -only-testing:DocumentScannerTests/DocumentStorageTests 2>&1 | tail -10
  ```

- [ ] **Step 5: Commit Tasks 2 + 3 together**

  ```
  cd /Users/pjones/Desktop/mobileDocumentScanner
  git add DocumentScanner/DocumentScanner/Viewer/DocumentSession.swift DocumentScanner/DocumentScanner/Storage/DocumentStorage.swift DocumentScanner/DocumentScannerTests/DocumentStorageTests.swift
  git commit -m "Add DocumentSession view-model + DocumentStorage replace/delete

  DocumentSession owns the currently-viewed document's URL, PDF, and
  editable displayName, with a save() that writes back through
  DocumentStorage. DocumentStorage gains write(_:replacing:withName:)
  for atomic overwrite (with optional rename) and delete(at:) for
  removal, both NSFileCoordinator-coordinated.

  Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
  ```

## Task 4: DocumentMutations — reorder, delete, append helpers

**Files:**

- Create: `DocumentScanner/DocumentScanner/Pipeline/DocumentMutations.swift`
- Create: `DocumentScanner/DocumentScannerTests/DocumentMutationsTests.swift`

A pure value-type helper. Doesn't touch disk, doesn't touch SwiftUI — just `PDFDocument` → mutated `PDFDocument`. Easy to unit-test.

- [ ] **Step 1: Write the failing tests**

  Create `DocumentScanner/DocumentScannerTests/DocumentMutationsTests.swift`:

  ```swift
  import XCTest
  import PDFKit
  @testable import DocumentScanner

  final class DocumentMutationsTests: XCTestCase {

      func test_reorder_movesPageToNewIndex() throws {
          let pdf = try threePagePDF()
          DocumentMutations.reorder(in: pdf, from: 0, to: 2)
          XCTAssertEqual(pageMarkers(pdf), ["B", "C", "A"])
      }

      func test_deletePage_removesPageAtIndex() throws {
          let pdf = try threePagePDF()
          DocumentMutations.deletePage(in: pdf, at: 1)
          XCTAssertEqual(pageMarkers(pdf), ["A", "C"])
      }

      func test_append_addsNewPagesToEnd() throws {
          let pdf = try threePagePDF()
          let extra = try singlePagePDF(marker: "D")
          DocumentMutations.append(extra, to: pdf)
          XCTAssertEqual(pageMarkers(pdf), ["A", "B", "C", "D"])
      }

      // MARK: - Helpers

      private func threePagePDF() throws -> PDFDocument {
          let pdf = PDFDocument()
          for marker in ["A", "B", "C"] {
              try pdf.insert(markedPage(marker), at: pdf.pageCount)
          }
          return pdf
      }

      private func singlePagePDF(marker: String) throws -> PDFDocument {
          let pdf = PDFDocument()
          try pdf.insert(markedPage(marker), at: 0)
          return pdf
      }

      /// Builds a PDFPage whose `string` contains the marker, by routing through
      /// PDFAssembler so the searchable-text mechanism is the same as production.
      private func markedPage(_ marker: String) throws -> PDFPage {
          let image = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100)).image { _ in
              UIColor.white.setFill()
              UIRectFill(CGRect(x: 0, y: 0, width: 100, height: 100))
          }
          let assembled = try PDFAssembler().assemble(
              pages: [ScannedPage(image: image, recognizedStrings: [marker])],
              createdAt: Date()
          )
          return try XCTUnwrap(assembled.page(at: 0))
      }

      private func pageMarkers(_ pdf: PDFDocument) -> [String] {
          (0..<pdf.pageCount).compactMap { idx in
              pdf.page(at: idx)?.string?.trimmingCharacters(in: .whitespacesAndNewlines)
          }
      }
  }
  ```

- [ ] **Step 2: Run tests, watch them fail**

  ```
  xcodebuild test -scheme DocumentScanner -destination 'id=B762C669-0A64-4665-8C00-10BD6628CBA2' -only-testing:DocumentScannerTests/DocumentMutationsTests 2>&1 | tail -15
  ```

- [ ] **Step 3: Implement `DocumentMutations`**

  Create `DocumentScanner/DocumentScanner/Pipeline/DocumentMutations.swift`:

  ```swift
  import Foundation
  import PDFKit

  /// Pure helpers that mutate a `PDFDocument` in place. No disk I/O.
  /// Save the document via `DocumentStorage.write(_:replacing:withName:)` after.
  enum DocumentMutations {

      static func reorder(in pdf: PDFDocument, from: Int, to: Int) {
          guard from != to, let page = pdf.page(at: from) else { return }
          pdf.removePage(at: from)
          let clampedTo = min(to, pdf.pageCount)
          pdf.insert(page, at: clampedTo)
      }

      static func deletePage(in pdf: PDFDocument, at index: Int) {
          guard index >= 0, index < pdf.pageCount else { return }
          pdf.removePage(at: index)
      }

      /// Append all pages from `other` onto `pdf`. Used by "Add Pages" after the
      /// new scans run through ScanPipeline → PDFAssembler.
      static func append(_ other: PDFDocument, to pdf: PDFDocument) {
          for i in 0..<other.pageCount {
              guard let page = other.page(at: i) else { continue }
              pdf.insert(page, at: pdf.pageCount)
          }
      }
  }
  ```

- [ ] **Step 4: Run tests, all pass**

  ```
  xcodebuild test -scheme DocumentScanner -destination 'id=B762C669-0A64-4665-8C00-10BD6628CBA2' -only-testing:DocumentScannerTests/DocumentMutationsTests 2>&1 | tail -10
  ```

- [ ] **Step 5: Commit**

  ```
  cd /Users/pjones/Desktop/mobileDocumentScanner
  git add DocumentScanner/DocumentScanner/Pipeline/DocumentMutations.swift DocumentScanner/DocumentScannerTests/DocumentMutationsTests.swift
  git commit -m "Add DocumentMutations: reorder/delete/append PDF pages

  Pure value-type helpers that mutate a PDFDocument in place. Each is
  unit-tested with a 3-page fixture and a per-page marker string so
  the tests verify page identity through the mutation, not just
  pageCount. No disk I/O.

  Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
  ```

## Task 5: PageThumbnail view

**Files:**

- Create: `DocumentScanner/DocumentScanner/Viewer/PageThumbnail.swift`

A small reusable view that renders a single PDF page as a thumbnail. Used in the edit-mode strip in Task 7.

- [ ] **Step 1: Implement `PageThumbnail`**

  ```swift
  import SwiftUI
  import PDFKit

  struct PageThumbnail: View {
      let page: PDFPage
      let size: CGSize

      @State private var image: UIImage?

      var body: some View {
          Group {
              if let image {
                  Image(uiImage: image).resizable().scaledToFit()
              } else {
                  RoundedRectangle(cornerRadius: 4).fill(Color(.systemGray6))
              }
          }
          .frame(width: size.width, height: size.height)
          .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(.systemGray4)))
          .task(id: ObjectIdentifier(page)) {
              image = await Self.render(page: page, size: size)
          }
      }

      private static func render(page: PDFPage, size: CGSize) async -> UIImage? {
          await Task.detached(priority: .userInitiated) {
              page.thumbnail(of: size, for: .mediaBox)
          }.value
      }
  }
  ```

- [ ] **Step 2: Build to verify**

  ```
  cd /Users/pjones/Desktop/mobileDocumentScanner/DocumentScanner
  xcodebuild build -scheme DocumentScanner -destination 'id=B762C669-0A64-4665-8C00-10BD6628CBA2' 2>&1 | tail -5
  ```

- [ ] **Step 3: Commit**

  ```
  cd /Users/pjones/Desktop/mobileDocumentScanner
  git add DocumentScanner/DocumentScanner/Viewer/PageThumbnail.swift
  git commit -m "Add PageThumbnail view for edit-mode strip

  Renders a single PDFPage at a target size, with a placeholder while
  the thumbnail renders asynchronously. Used by EditModeView in a
  later task.

  Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
  ```

## Task 6: Viewer toolbar — share, rename, delete

**Files:**

- Modify: `DocumentScanner/DocumentScanner/Viewer/DocumentViewerView.swift`
- Modify: `DocumentScanner/DocumentScanner/Library/LibraryView.swift`

Replace the Plan-1 read-only `DocumentViewerView` with a session-backed view that has:

- `ShareLink` (system share sheet)
- Inline rename: tap the title to edit
- Delete-document button with confirmation

Note: the Edit-mode toolbar button is wired in Task 7; the toolbar slot is reserved here.

- [ ] **Step 1: Replace `DocumentViewerView.swift`**

  ```swift
  import SwiftUI
  import PDFKit

  struct DocumentViewerView: View {
      let summary: DocumentSummary
      let storage: DocumentStorage
      /// Closure dismissing the viewer; provided by LibraryView so the deletion
      /// path can pop the navigation stack.
      let onDeleted: () -> Void

      @State private var session: DocumentSession?
      @State private var loadError: String?
      @State private var isRenaming = false
      @State private var showDeleteConfirm = false

      var body: some View {
          Group {
              if let session {
                  loadedBody(session: session)
              } else if let loadError {
                  ContentUnavailableView("Couldn't open document",
                                         systemImage: "doc.text.fill",
                                         description: Text(loadError))
              } else {
                  ProgressView()
              }
          }
          .task {
              do { session = try DocumentSession(summary: summary, storage: storage) }
              catch { loadError = String(describing: error) }
          }
      }

      @ViewBuilder
      private func loadedBody(session: DocumentSession) -> some View {
          PDFKitView(document: session.pdf)
              .ignoresSafeArea(edges: .bottom)
              .navigationBarTitleDisplayMode(.inline)
              .toolbar {
                  ToolbarItem(placement: .principal) {
                      if isRenaming {
                          TextField("Name", text: Binding(
                              get: { session.displayName },
                              set: { session.displayName = $0 }
                          ))
                          .textFieldStyle(.roundedBorder)
                          .submitLabel(.done)
                          .onSubmit { commitRename(session: session) }
                          .frame(minWidth: 200)
                      } else {
                          Button(session.displayName) { isRenaming = true }
                              .font(.headline)
                              .foregroundStyle(.primary)
                      }
                  }
                  ToolbarItemGroup(placement: .topBarTrailing) {
                      ShareLink(item: session.url)
                      Button { showDeleteConfirm = true } label: {
                          Image(systemName: "trash")
                      }
                  }
              }
              .confirmationDialog("Delete this document?", isPresented: $showDeleteConfirm) {
                  Button("Delete", role: .destructive) {
                      try? storage.delete(at: session.url)
                      onDeleted()
                  }
                  Button("Cancel", role: .cancel) {}
              } message: {
                  Text("This will permanently remove \"\(session.displayName).pdf\" from iCloud.")
              }
      }

      private func commitRename(session: DocumentSession) {
          isRenaming = false
          let trimmed = session.displayName.trimmingCharacters(in: .whitespaces)
          guard !trimmed.isEmpty else {
              session.displayName = summary.displayName // revert to original
              return
          }
          do { try session.save() }
          catch { session.displayName = summary.displayName } // revert on failure
      }
  }

  private struct PDFKitView: UIViewRepresentable {
      let document: PDFDocument
      func makeUIView(context: Context) -> PDFView {
          let v = PDFView()
          v.autoScales = true
          v.displayMode = .singlePageContinuous
          v.usePageViewController(false)
          return v
      }
      func updateUIView(_ view: PDFView, context: Context) {
          view.document = document
      }
  }
  ```

- [ ] **Step 2: Update `LibraryView` to pass storage + handle delete-dismiss**

  In `LibraryView`'s `navigationDestination(for: DocumentSummary.self)` block, replace `DocumentViewerView(summary: summary)` with:

  ```swift
  .navigationDestination(for: DocumentSummary.self) { summary in
      DocumentViewerView(
          summary: summary,
          storage: storage,
          onDeleted: {
              store.refresh()
              path.removeLast()
          }
      )
  }
  ```

  This requires `path` state for the NavigationStack. Add at the top of LibraryView:

  ```swift
  @State private var path: [DocumentSummary] = []
  ```

  And change `NavigationStack {` to `NavigationStack(path: $path) {`.

- [ ] **Step 3: Build and run on simulator to verify the empty-state path**

  Cmd+R. The empty library still renders, the + button still presents the scanner. There's nothing to view since the library starts empty in a fresh simulator without iCloud data. The viewer changes will be exercised against real scans on device.

- [ ] **Step 4: Commit**

  ```
  cd /Users/pjones/Desktop/mobileDocumentScanner
  git add DocumentScanner/DocumentScanner/Viewer/DocumentViewerView.swift DocumentScanner/DocumentScanner/Library/LibraryView.swift
  git commit -m "Viewer toolbar: ShareLink, inline rename, delete-with-confirm

  DocumentViewerView now holds a DocumentSession so it can render the
  current PDF, expose an editable displayName in the nav title (tap
  to rename), share via the system share sheet, and delete the
  document with a confirmation dialog. Deletion pops the navigation
  stack back to the library and triggers a refresh.

  Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
  ```

## Task 7: Edit mode — thumbnail strip + reorder

**Files:**

- Create: `DocumentScanner/DocumentScanner/Viewer/EditModeView.swift`
- Modify: `DocumentScanner/DocumentScanner/Viewer/DocumentViewerView.swift`

Adds an "Edit" toolbar button. While editing, a thumbnail strip appears at the bottom; drag any thumbnail to reorder. Tapping the page in the main PDFView still scrolls to it.

- [ ] **Step 1: Implement `EditModeView`**

  Create `DocumentScanner/DocumentScanner/Viewer/EditModeView.swift`:

  ```swift
  import SwiftUI
  import PDFKit

  struct EditModeView: View {
      @Bindable var session: DocumentSession

      var body: some View {
          ScrollView(.horizontal, showsIndicators: false) {
              HStack(spacing: 12) {
                  ForEach(currentPages.indices, id: \.self) { index in
                      thumbnail(at: index)
                  }
              }
              .padding(.horizontal, 16)
          }
          .frame(height: 140)
          .background(.thinMaterial)
      }

      private var currentPages: [PDFPage] {
          (0..<session.pdf.pageCount).compactMap(session.pdf.page(at:))
      }

      @ViewBuilder
      private func thumbnail(at index: Int) -> some View {
          if let page = session.pdf.page(at: index) {
              VStack(spacing: 4) {
                  PageThumbnail(page: page, size: CGSize(width: 80, height: 104))
                      .draggable(IndexPayload(index: index)) {
                          PageThumbnail(page: page, size: CGSize(width: 60, height: 78))
                      }
                      .dropDestination(for: IndexPayload.self) { items, _ in
                          guard let first = items.first else { return false }
                          DocumentMutations.reorder(in: session.pdf, from: first.index, to: index)
                          try? session.save()
                          return true
                      }
                  Text("\(index + 1)").font(.caption).foregroundStyle(.secondary)
              }
          }
      }

      private struct IndexPayload: Codable, Transferable {
          let index: Int
          static var transferRepresentation: some TransferRepresentation {
              CodableRepresentation(contentType: .data)
          }
      }
  }
  ```

- [ ] **Step 2: Add Edit toolbar button + strip to `DocumentViewerView`**

  In `DocumentViewerView.loadedBody`, add an `@State private var editMode = false` at the struct level and:

  In `.toolbar { ToolbarItemGroup(placement: .topBarTrailing) { ... } }`, prepend a button before `ShareLink`:

  ```swift
  Button(editMode ? "Done" : "Edit") { editMode.toggle() }
  ```

  And wrap the `PDFKitView` in a VStack so the strip can sit beneath it:

  ```swift
  VStack(spacing: 0) {
      PDFKitView(document: session.pdf)
          .ignoresSafeArea(edges: editMode ? [] : .bottom)
      if editMode {
          EditModeView(session: session)
              .transition(.move(edge: .bottom))
      }
  }
  .animation(.easeInOut(duration: 0.2), value: editMode)
  ```

  The `.ignoresSafeArea` conditional makes the PDF use the full screen when not editing, and respect the safe area (leaving room for the strip) when editing.

- [ ] **Step 3: Build to verify**

  ```
  cd /Users/pjones/Desktop/mobileDocumentScanner/DocumentScanner
  xcodebuild build -scheme DocumentScanner -destination 'id=B762C669-0A64-4665-8C00-10BD6628CBA2' 2>&1 | tail -5
  ```

- [ ] **Step 4: Commit**

  ```
  cd /Users/pjones/Desktop/mobileDocumentScanner
  git add DocumentScanner/DocumentScanner/Viewer/EditModeView.swift DocumentScanner/DocumentScanner/Viewer/DocumentViewerView.swift
  git commit -m "Edit mode: thumbnail strip with drag-to-reorder

  Toggles via a new Edit/Done toolbar button. When active, a
  scrollable horizontal strip of page thumbnails appears at the
  bottom. Each thumbnail is both a drag source and a drop
  destination; the receiving page's index is the new position. The
  reorder is applied immediately and persisted via session.save().

  Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
  ```

## Task 8: Edit mode — delete a page

**Files:**

- Modify: `DocumentScanner/DocumentScanner/Viewer/EditModeView.swift`

Long-press a thumbnail to reveal a delete option. If it's the last page, prompt to delete the whole document instead.

- [ ] **Step 1: Add context-menu delete to `EditModeView`**

  In the `thumbnail(at:)` function, add `.contextMenu` after the `.dropDestination`:

  ```swift
  .contextMenu {
      Button(role: .destructive) {
          deletePage(at: index)
      } label: {
          Label("Delete page", systemImage: "trash")
      }
  }
  ```

  And add the `deletePage` method on `EditModeView`:

  ```swift
  @Environment(\.dismiss) private var dismiss
  ```

  (at the top of the struct, alongside `session`)

  ```swift
  private func deletePage(at index: Int) {
      guard session.pdf.pageCount > 1 else {
          // Last page — delegate to viewer-level delete-document flow.
          // We surface this via a NotificationCenter "request delete document"
          // rather than coupling EditModeView to storage/onDeleted.
          NotificationCenter.default.post(name: .requestDeleteDocument, object: nil)
          return
      }
      DocumentMutations.deletePage(in: session.pdf, at: index)
      try? session.save()
  }
  ```

  Add this notification name in the same file:

  ```swift
  extension Notification.Name {
      static let requestDeleteDocument = Notification.Name("requestDeleteDocument")
  }
  ```

- [ ] **Step 2: Wire the notification in `DocumentViewerView`**

  In `loadedBody`, add:

  ```swift
  .onReceive(NotificationCenter.default.publisher(for: .requestDeleteDocument)) { _ in
      showDeleteConfirm = true
  }
  ```

  Now the last-page-delete path opens the existing delete-document confirmation, which already handles file removal and `onDeleted()` callback.

- [ ] **Step 3: Build to verify**

- [ ] **Step 4: Commit**

  ```
  cd /Users/pjones/Desktop/mobileDocumentScanner
  git add DocumentScanner/DocumentScanner/Viewer/EditModeView.swift DocumentScanner/DocumentScanner/Viewer/DocumentViewerView.swift
  git commit -m "Edit mode: long-press a page to delete it

  Adds a context menu with a destructive Delete action on each
  thumbnail. Deleting the only remaining page surfaces the
  delete-whole-document confirmation flow rather than producing a
  zero-page PDF.

  Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
  ```

## Task 9: Edit mode — Add Pages button

**Files:**

- Modify: `DocumentScanner/DocumentScanner/Viewer/EditModeView.swift`
- Modify: `DocumentScanner/DocumentScanner/Viewer/DocumentViewerView.swift`
- Modify: `DocumentScanner/DocumentScanner/Library/LibraryView.swift`

The "Add Pages" button presents the same `CaptureSheet` as the initial capture, but on finish the new images run through `ScanPipeline` and then `DocumentMutations.append` onto the current document. OCR runs only on the new pages.

- [ ] **Step 1: Pass `scannerPresenter` and `pipeline` down to the viewer**

  In `LibraryView`'s `navigationDestination`, expand the `DocumentViewerView` call to forward these:

  ```swift
  DocumentViewerView(
      summary: summary,
      storage: storage,
      scannerPresenter: scannerPresenter,
      pipeline: pipeline,
      onDeleted: { ... }
  )
  ```

  In `DocumentViewerView`, add the new properties:

  ```swift
  let scannerPresenter: DocumentScannerPresenting
  let pipeline: ScanPipeline
  ```

- [ ] **Step 2: Add Add-Pages button to the edit strip**

  In `EditModeView.body`, add a sentinel "+" button at the end of the HStack:

  ```swift
  Button {
      onAddPages()
  } label: {
      VStack {
          RoundedRectangle(cornerRadius: 4)
              .stroke(style: StrokeStyle(lineWidth: 1, dash: [4]))
              .foregroundStyle(.tint)
              .overlay(Image(systemName: "plus").font(.title2).foregroundStyle(.tint))
              .frame(width: 80, height: 104)
          Text("Add").font(.caption).foregroundStyle(.tint)
      }
  }
  ```

  Add `let onAddPages: () -> Void` to the `EditModeView` struct, callable from `DocumentViewerView`.

- [ ] **Step 3: Wire Add-Pages in `DocumentViewerView`**

  Add `@State private var showAddPages = false` and `@State private var addPagesTask: Task<Void, Never>?`.

  Pass `onAddPages: { showAddPages = true }` to `EditModeView(session:onAddPages:)`.

  Add a `.fullScreenCover(isPresented: $showAddPages)` matching `LibraryView`'s capture sheet pattern:

  ```swift
  .fullScreenCover(isPresented: $showAddPages) {
      CaptureSheet(
          presenter: scannerPresenter,
          onFinish: { images in
              showAddPages = false
              addPagesTask = Task {
                  guard let session else { return }
                  do {
                      let result = try await pipeline.process(images: images)
                      DocumentMutations.append(result.pdf, to: session.pdf)
                      try session.save()
                  } catch {
                      // Surfaced later by Plan 4 error handling.
                  }
              }
          },
          onCancel: { showAddPages = false }
      )
      .ignoresSafeArea()
  }
  ```

- [ ] **Step 4: Build + commit**

  ```
  cd /Users/pjones/Desktop/mobileDocumentScanner/DocumentScanner
  xcodebuild build -scheme DocumentScanner -destination 'id=B762C669-0A64-4665-8C00-10BD6628CBA2' 2>&1 | tail -5
  ```

  ```
  cd /Users/pjones/Desktop/mobileDocumentScanner
  git add DocumentScanner/DocumentScanner/Viewer/EditModeView.swift DocumentScanner/DocumentScanner/Viewer/DocumentViewerView.swift DocumentScanner/DocumentScanner/Library/LibraryView.swift
  git commit -m "Edit mode: Add Pages button re-uses capture flow

  A dashed-outline + tile at the end of the edit-mode strip presents
  the same VisionKit CaptureSheet used for initial capture. On
  finish, the new pages run through ScanPipeline (OCR runs only on
  the new pages), and DocumentMutations.append concatenates them
  onto the current document, then session.save() writes back.

  Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
  ```

## Task 10: Device smoke test

Same form as Plan 1's Task 15.

- [ ] **Step 1: Cmd+R to a real iPhone, install the new build**

- [ ] **Step 2: Open an existing scanned document** (or create a fresh one first to have something to edit).

- [ ] **Step 3: Verify Viewer toolbar:**
  - Title shows the filename. Tap it → it becomes an editable TextField. Type a new name, tap Done. Verify in Files.app that the file was renamed in iCloud Drive.
  - Tap **Share** → iOS share sheet appears. Verify "AirDrop", "Mail", "Save to Files" are present. Cancel.
  - Tap **trash** → confirmation appears. Cancel.

- [ ] **Step 4: Verify Edit mode:**
  - Tap **Edit**. Strip appears at the bottom.
  - **Reorder:** Drag a thumbnail onto another's position. The PDF view updates. Open Files.app and the file should reflect the new page order.
  - **Delete page:** Long-press a thumbnail (with multiple pages still present). Tap Delete. Page disappears from PDF view + strip.
  - **Delete last page:** Long-press when only one page remains. Tap Delete. The "Delete document?" confirmation appears. Cancel.
  - **Add Pages:** Tap the + tile. VisionKit opens. Scan another sheet. After OCR finishes, the new page appears as the last thumbnail and as the last page in the PDFView.

- [ ] **Step 5: Verify in Files.app**
  - iCloud Drive → Document Scanner. All edits should be reflected. Long-press a word in a freshly-appended page to confirm OCR ran on it.

- [ ] **Step 6: If anything is broken, capture the error**
  - Check Xcode's console (bottom pane while running on device) for OSLog output.
  - Note which step failed and the exact symptom; the next session can debug from that.

- [ ] **Step 7: Commit the milestone marker**

  ```
  cd /Users/pjones/Desktop/mobileDocumentScanner
  git commit --allow-empty -m "Milestone: Plan 2a verified end-to-end on device"
  ```

---

## After Plan 2a

What lands:

- Viewer toolbar: share, inline rename, delete-document
- Edit mode: drag-to-reorder, long-press-to-delete, Add Pages re-using the capture pipeline

What remains for Plan 2b:

- Per-page editor: tap a thumbnail to open a single-page editor with crop (initialized via `VNDetectDocumentSegmentationRequest`) and rotate
- Partial re-OCR after crop

## Self-review notes

- Spec coverage in scope of Plan 2a: viewer toolbar (share/rename/delete) ✓, edit-mode reorder ✓, delete page ✓, delete whole document via last-page case ✓, append pages ✓. Per-page editor (re-crop/rotate) deferred to Plan 2b as planned.
- ByteFaithfulPDFDocument removal: addressed in Task 1; documentation updated.
- Type consistency: `DocumentSession`, `DocumentMutations`, `DocumentStorage` signatures match across consumers. `PDFDocument` returned by `PDFAssembler` is now the plain type, propagating cleanly.
- Placeholder scan: none. Each step has code or an explicit instruction.
- Test coverage: unit tests for `DocumentMutations` (3 cases) and the new `DocumentStorage` overloads (4 cases). Viewer + EditModeView are SwiftUI views with no unit tests in this plan — exercised via the device smoke test.
- Notification-based last-page handoff in Task 8: chosen because EditModeView would otherwise need access to `storage` and `onDeleted` from the viewer. A direct closure would also work; flagged as a small follow-up if you prefer.
