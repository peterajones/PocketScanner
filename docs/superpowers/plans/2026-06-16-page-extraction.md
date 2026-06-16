# Page Extraction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the user multi-select pages in edit mode and save **copies** of them as a new document (in the source's folder), non-destructively.

**Architecture:** A new pure `DocumentMutations.extractPages(from:at:)` returns a fresh `PDFDocument` of deep-copied pages. `EditModeView` gains an `onExtract` closure (multi-select header button + single-page context-menu item). `DocumentViewerView` implements it: name alert → write to the source's parent folder via `DocumentStorage` → original untouched.

**Tech Stack:** Swift, SwiftUI, PDFKit, XCTest.

**Spec:** `docs/superpowers/specs/2026-06-16-page-extraction-design.md`

---

## File Structure

- Modify: `DocumentScanner/DocumentScanner/Pipeline/DocumentMutations.swift` — add `extractPages`
- Modify (test): `DocumentScanner/DocumentScannerTests/DocumentMutationsTests.swift` — new cases
- Modify: `DocumentScanner/DocumentScanner/Viewer/EditModeView.swift` — `onExtract` + UI
- Modify: `DocumentScanner/DocumentScanner/Viewer/DocumentViewerView.swift` — handler + name/error alerts

Build / test commands:
```bash
cd DocumentScanner && xcodebuild build \
  -scheme DocumentScanner -destination 'platform=iOS Simulator,name=iPhone 17'
cd DocumentScanner && xcodebuild test \
  -scheme DocumentScanner -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:DocumentScannerTests
```

> **Note:** Task 2 adds a required `onExtract` parameter to `EditModeView` *and* updates its
> only call site (`DocumentViewerView`) together, so the project compiles after each task.

---

## Task 1: `DocumentMutations.extractPages` (pure, TDD)

**Files:**
- Modify: `DocumentScanner/DocumentScanner/Pipeline/DocumentMutations.swift`
- Test: `DocumentScanner/DocumentScannerTests/DocumentMutationsTests.swift`

- [ ] **Step 1: Write the failing tests**

Add these cases to `DocumentMutationsTests` (above the `// MARK: - Helpers` line). They reuse
the existing `threePagePDF()`, `markedPage(_:)`, and `pageMarkers(_:)` helpers:

```swift
    func test_extractPages_returnsSelectedPagesInAscendingOrder() throws {
        let pdf = PDFDocument()
        for marker in ["A", "B", "C", "D", "E"] {
            pdf.insert(try markedPage(marker), at: pdf.pageCount)
        }
        let extracted = DocumentMutations.extractPages(from: pdf, at: [3, 1])
        XCTAssertEqual(pageMarkers(extracted), ["B", "D"])
    }

    func test_extractPages_leavesOriginalUnchanged() throws {
        let pdf = try threePagePDF()       // [A, B, C]
        _ = DocumentMutations.extractPages(from: pdf, at: [0, 2])
        XCTAssertEqual(pageMarkers(pdf), ["A", "B", "C"])
    }

    func test_extractPages_skipsOutOfRangeIndices() throws {
        let pdf = try threePagePDF()       // [A, B, C]
        let extracted = DocumentMutations.extractPages(from: pdf, at: [1, 99, -1])
        XCTAssertEqual(pageMarkers(extracted), ["B"])
    }

    func test_extractPages_emptySetYieldsEmptyDocument() throws {
        let pdf = try threePagePDF()
        let extracted = DocumentMutations.extractPages(from: pdf, at: [])
        XCTAssertEqual(extracted.pageCount, 0)
    }

    func test_extractPages_preservesRotation() throws {
        let pdf = try threePagePDF()
        DocumentMutations.rotatePage(in: pdf, at: 1, clockwise: true) // B -> 90
        let extracted = DocumentMutations.extractPages(from: pdf, at: [1])
        XCTAssertEqual(extracted.page(at: 0)?.rotation, 90)
        XCTAssertEqual(pdf.page(at: 1)?.rotation, 90, "original page keeps its rotation")
    }

    func test_extractPages_preservesSearchableText_afterDiskRoundTrip() throws {
        let pdf = PDFDocument()
        for marker in ["First", "Second", "Third"] {
            pdf.insert(try markedPage(marker), at: pdf.pageCount)
        }
        let extracted = DocumentMutations.extractPages(from: pdf, at: [1]) // "Second"

        let tmpURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("extract-roundtrip-\(UUID().uuidString).pdf")
        defer { try? FileManager.default.removeItem(at: tmpURL) }
        try XCTUnwrap(extracted.dataRepresentation()).write(to: tmpURL)

        let reloaded = try XCTUnwrap(PDFDocument(url: tmpURL))
        XCTAssertEqual(reloaded.pageCount, 1)
        XCTAssertFalse(reloaded.findString("Second", withOptions: .caseInsensitive).isEmpty,
                       "the extracted page's OCR text layer must survive copy + round-trip")
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
cd DocumentScanner && xcodebuild test \
  -scheme DocumentScanner -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:DocumentScannerTests/DocumentMutationsTests 2>&1 | tail -20
```
Expected: FAILS to compile — `type 'DocumentMutations' has no member 'extractPages'`.

- [ ] **Step 3: Implement `extractPages`**

In `DocumentMutations.swift`, add this method inside the `enum DocumentMutations` (e.g. after
`rotatePage`):

```swift
    /// Build a NEW `PDFDocument` containing deep copies of the pages at `indices`,
    /// in ascending index order. The source `pdf` is NOT mutated. Out-of-range
    /// indices are skipped; an empty set yields an empty document. `PDFPage.copy()`
    /// preserves the page's content stream (incl. the invisible OCR text layer),
    /// its `/Rotate` value, and its annotations. Save the result via
    /// `DocumentStorage.write(_:preferredName:)`.
    static func extractPages(from pdf: PDFDocument, at indices: Set<Int>) -> PDFDocument {
        let result = PDFDocument()
        for index in indices.sorted() {
            guard index >= 0, index < pdf.pageCount,
                  let page = pdf.page(at: index),
                  let copy = page.copy() as? PDFPage else { continue }
            result.insert(copy, at: result.pageCount)
        }
        return result
    }
```

- [ ] **Step 4: Run the tests to verify they pass**

```bash
cd DocumentScanner && xcodebuild test \
  -scheme DocumentScanner -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:DocumentScannerTests/DocumentMutationsTests 2>&1 | tail -20
```
Expected: `** TEST SUCCEEDED **`, all `extractPages` cases pass.

- [ ] **Step 5: Commit**

```bash
git add DocumentScanner/DocumentScanner/Pipeline/DocumentMutations.swift \
        DocumentScanner/DocumentScannerTests/DocumentMutationsTests.swift
git commit -m "feat: DocumentMutations.extractPages (copy pages to a new PDFDocument) + tests"
```

---

## Task 2: Wire extraction into the UI (EditModeView + DocumentViewerView)

**Files:**
- Modify: `DocumentScanner/DocumentScanner/Viewer/EditModeView.swift`
- Modify: `DocumentScanner/DocumentScanner/Viewer/DocumentViewerView.swift`

(No unit test — SwiftUI wiring; verified by build + the full suite, then on device in Task 3.)

- [ ] **Step 1: Add the `onExtract` closure to `EditModeView`**

In `EditModeView.swift`, add the property right after `onAddPages`:

```swift
    let onAddPages: () -> Void
    let onExtract: (Set<Int>) -> Void
```

- [ ] **Step 2: Add the "Save as New" button to the multi-select header**

In `multiSelectHeader`, replace the trailing Delete button:

```swift
            Spacer()
            Button(role: .destructive) {
                deleteSelected()
            } label: {
                Image(systemName: "trash")
            }
            .disabled(selectedIndices.isEmpty)
            .accessibilityIdentifier("EditMode.MultiSelect.Delete")
        }
```

with a Save-as-New button followed by Delete:

```swift
            Spacer()
            Button {
                extractSelected()
            } label: {
                Image(systemName: "doc.badge.plus")
            }
            .disabled(selectedIndices.isEmpty)
            .accessibilityIdentifier("EditMode.MultiSelect.SaveAsNew")
            Button(role: .destructive) {
                deleteSelected()
            } label: {
                Image(systemName: "trash")
            }
            .disabled(selectedIndices.isEmpty)
            .accessibilityIdentifier("EditMode.MultiSelect.Delete")
        }
```

- [ ] **Step 3: Add the single-page context-menu item**

In `thumbnailImage(for:index:)`, in the `.contextMenu { … }`, insert a "Save page as new" item
between the Rotate Right button and the Delete page button:

```swift
                    Button {
                        rotatePage(at: index, clockwise: true)
                    } label: {
                        Label("Rotate Right", systemImage: "rotate.right")
                    }
                    Button {
                        onExtract([index])
                    } label: {
                        Label("Save page as new", systemImage: "doc.badge.plus")
                    }
                    Button(role: .destructive) {
                        deletePage(at: index)
                    } label: {
                        Label("Delete page", systemImage: "trash")
                    }
```

- [ ] **Step 4: Add the `extractSelected` helper**

In `EditModeView.swift`, add next to `deleteSelected()`:

```swift
    private func extractSelected() {
        guard !selectedIndices.isEmpty else { return }
        onExtract(selectedIndices)
        exitMultiSelect()
    }
```

- [ ] **Step 5: Add extraction state + struct to `DocumentViewerView`**

In `DocumentViewerView.swift`, add the struct next to `PendingDeletion`:

```swift
    private struct PendingExtraction: Identifiable {
        let id = UUID()
        let pdf: PDFDocument
    }
```

and these `@State` properties next to `pendingDeletion`:

```swift
    @State private var pendingExtraction: PendingExtraction?
    @State private var extractName: String = ""
    @State private var extractError: String?
```

- [ ] **Step 6: Pass `onExtract` to `EditModeView`**

Update the `EditModeView(...)` call site:

```swift
                EditModeView(
                    session: session,
                    onEditPage: { editingPageIndex = $0 },
                    onAddPages: { showAddPages = true },
                    onExtract: { indices in
                        let extracted = DocumentMutations.extractPages(from: session.pdf, at: indices)
                        guard extracted.pageCount > 0 else { return }
                        extractName = "\(session.displayName) extract"
                        pendingExtraction = PendingExtraction(pdf: extracted)
                    }
                )
```

- [ ] **Step 7: Add the name alert + error alert**

In `loadedBody`, attach these two modifiers immediately after the existing
`.confirmationDialog("Delete this document?", …) { … }` block:

```swift
        .alert("Save as New Document", isPresented: Binding(
            get: { pendingExtraction != nil },
            set: { if !$0 { pendingExtraction = nil } }
        )) {
            TextField("Name", text: $extractName)
            Button("Save") { saveExtraction(session: session) }
                .disabled(extractName.trimmingCharacters(in: .whitespaces).isEmpty)
            Button("Cancel", role: .cancel) { pendingExtraction = nil }
        } message: {
            Text("Adds a new document with the selected pages to this folder. The original is unchanged.")
        }
        .alert("Couldn't Save", isPresented: Binding(
            get: { extractError != nil },
            set: { if !$0 { extractError = nil } }
        )) {
            Button("OK", role: .cancel) { extractError = nil }
        } message: {
            Text(extractError ?? "")
        }
```

- [ ] **Step 8: Add the `saveExtraction` method**

In `DocumentViewerView.swift`, add next to `commitRename`:

```swift
    private func saveExtraction(session: DocumentSession) {
        guard let extraction = pendingExtraction else { return }
        let name = extractName.trimmingCharacters(in: .whitespaces)
        // Write next to the source document so the new doc lands in the same
        // folder (consistent with folder-aware scan saving). DocumentStorage
        // sanitizes the name and resolves collisions with a " (N)" suffix.
        let folderStorage = DocumentStorage(documentsURL: session.url.deletingLastPathComponent())
        do {
            _ = try folderStorage.write(extraction.pdf, preferredName: name)
        } catch {
            extractError = "Couldn't save \"\(name)\". Please try again."
        }
        pendingExtraction = nil
    }
```

> The new file lands on disk in the source's folder; it appears in the library when the
> user navigates back (iCloud mode updates via `NSMetadataQuery`; local mode refreshes via
> the library view's existing on-appear `localStore.refresh()`). No extra refresh code needed.

- [ ] **Step 9: Build**

```bash
cd DocumentScanner && xcodebuild build \
  -scheme DocumentScanner -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 10: Run the full unit suite (no regressions)**

```bash
cd DocumentScanner && xcodebuild test \
  -scheme DocumentScanner -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:DocumentScannerTests 2>&1 | grep -E "extractPages|\*\* TEST|failed|error:" | tail -20
```
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 11: Commit**

```bash
git add DocumentScanner/DocumentScanner/Viewer/EditModeView.swift \
        DocumentScanner/DocumentScanner/Viewer/DocumentViewerView.swift
git commit -m "feat: page extraction UI — Save as New (multi-select + single page)"
```

---

## Task 3: On-device verification

**Files:** none (manual).

- [ ] **Step 1: Multi-select extraction**

Open a multi-page document → **Edit** → long-press a thumbnail → **Select Multiple** → select
2–3 pages → tap **Save as New** (the `doc.badge.plus` button) → accept/edit the default name
(`"{name} extract"`) → **Save**. Confirm:
- The alert dismisses; you stay in the original document.
- The **original still has all its pages** (unchanged).
- Navigate back → the **new document appears in the same folder** with only the selected pages.

- [ ] **Step 2: Single-page extraction**

Long-press one thumbnail → **Save page as new** → name → Save. Confirm a 1-page new document
appears in the same folder; original unchanged.

- [ ] **Step 3: Fidelity check**

Extract a page that is **rotated** and/or **annotated** (highlight). Open the new document:
the page keeps its rotation and marks, and **search** finds its text.

- [ ] **Step 4: Folder placement**

Repeat Step 1 from a document **inside a folder** → confirm the new document lands **in that
folder**, not the root library.

---

## Done

After Task 3: users can select pages in edit mode and **Save as New** — a copy of those pages
becomes a new document in the source's folder, with rotation, annotations, and searchable text
intact, and the original untouched. Ships in **v1.8 (13)** alongside the framed App Store media
revamp. Roadmap entry (`docs/FutureEnhancements.md` → Editing → Page extraction) to be removed
on merge.
