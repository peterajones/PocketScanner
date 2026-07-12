# Import a PDF Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a user bring an existing PDF into the library (to view/sign/date/search) via two entry points — a document handler ("Open in Pocket Scanner") and an in-app "Import PDF" picker — reusing the existing storage + library so there's no new pipeline.

**Architecture:** A small `PDFImporter` validates a source PDF URL and writes it through the existing `DocumentStorage` (which already gives unique naming + coordinated writes). Both entry points call it; everything downstream (library listing, search, view/sign/date) already works because the library lists any `*.pdf` and search reads `pdf.string`.

**Tech Stack:** Swift, SwiftUI (`.onOpenURL`, `.fileImporter`), PDFKit, `UniformTypeIdentifiers`, Info.plist document types, XCTest.

**Context for the implementer:**
- `DocumentStorage.write(_ pdf: PDFDocument, preferredName: String) throws -> URL` already sanitizes the name, de-collides (`Contract` → `Contract (2)`), and does a coordinated atomic write. Reuse it — do not reimplement.
- The library query is `%K LIKE '*.pdf'` and `DocumentSummary.fromFile` sets `ocrSnippet: pdf.string ?? ""`, so an imported born-digital PDF appears + is searchable with zero extra work.
- The app builds `DocumentStorage(documentsURL: resolvedDocumentsURL)` (iCloud) or `DocumentStorage(documentsURL: container.localDocumentsURL)` (local). `resolvedDocumentsURL = container.resolveDocumentsURL()` is iCloud-when-available-else-local, so it is correct for the document-handler path in **both** cases.
- App-level alerts go through `AlertCenter.present(AppAlert(title:message:))` (default "OK" button).
- Ground-truth test command (from repo root):
  ```
  xcodebuild test -project DocumentScanner/DocumentScanner.xcodeproj -scheme DocumentScanner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:DocumentScannerTests
  ```
  Scope one class with `-only-testing:DocumentScannerTests/PDFImporterTests`. New files auto-join their target (file-system-synchronized groups) — no `.pbxproj` edits.

---

## File Structure

- **Create** `DocumentScanner/DocumentScanner/Import/PDFImporter.swift` — the shared import core + `PDFImporterError`.
- **Create** `DocumentScanner/DocumentScannerTests/PDFImporterTests.swift`.
- **Modify** `DocumentScanner/DocumentScanner/Info.plist` — `CFBundleDocumentTypes` (PDF) + `LSSupportsOpeningDocumentsInPlace`.
- **Modify** `DocumentScanner/DocumentScanner/App/DocumentScannerApp.swift` — `.onOpenURL` → import to root + refresh.
- **Modify** `DocumentScanner/DocumentScanner/Library/LibraryView.swift` and `FolderContentsView.swift` — "Import PDF" menu item + `.fileImporter` + error alert.
- **Modify** `docs/FutureEnhancements.md` — mark built.

---

## Task 1: `PDFImporter` (the shared core)

**Files:**
- Create: `DocumentScanner/DocumentScanner/Import/PDFImporter.swift`
- Test: `DocumentScanner/DocumentScannerTests/PDFImporterTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `DocumentScanner/DocumentScannerTests/PDFImporterTests.swift`:

```swift
import XCTest
import PDFKit
@testable import DocumentScanner

final class PDFImporterTests: XCTestCase {

    private func tempDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pdfimport-\(UUID())", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// A real, readable multi-page PDF at `<fresh temp dir>/<name>.pdf`.
    private func makeSourcePDF(named name: String, pages: Int) -> URL {
        let pdf = PDFDocument()
        for i in 0..<pages { pdf.insert(PDFPage(), at: i) }
        let url = tempDir().appendingPathComponent("\(name).pdf")
        pdf.write(to: url)
        return url
    }

    func test_import_validPDF_writesReadableCopy() throws {
        let dest = tempDir()
        let storage = DocumentStorage(documentsURL: dest)
        let source = makeSourcePDF(named: "Contract", pages: 3)

        let url = try PDFImporter.importPDF(from: source, using: storage)

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(url.deletingPathExtension().lastPathComponent, "Contract")
        XCTAssertEqual(try XCTUnwrap(PDFDocument(url: url)).pageCount, 3)
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path), "source not moved/deleted")
    }

    func test_import_collision_getsUniqueName() throws {
        let dest = tempDir()
        let storage = DocumentStorage(documentsURL: dest)

        _ = try PDFImporter.importPDF(from: makeSourcePDF(named: "Doc", pages: 1), using: storage)
        let second = try PDFImporter.importPDF(from: makeSourcePDF(named: "Doc", pages: 1), using: storage)

        XCTAssertNotEqual(second.lastPathComponent, "Doc.pdf", "collision resolved to a new name")
        let pdfs = try FileManager.default.contentsOfDirectory(atPath: dest.path).filter { $0.hasSuffix(".pdf") }
        XCTAssertEqual(pdfs.count, 2, "both imports kept")
    }

    func test_import_invalidPDF_throws_andWritesNothing() throws {
        let dest = tempDir()
        let storage = DocumentStorage(documentsURL: dest)
        let bad = tempDir().appendingPathComponent("notreal.pdf")
        try Data("not a pdf".utf8).write(to: bad)

        XCTAssertThrowsError(try PDFImporter.importPDF(from: bad, using: storage)) { error in
            XCTAssertEqual(error as? PDFImporterError, .unreadablePDF)
        }
        let contents = (try? FileManager.default.contentsOfDirectory(atPath: dest.path)) ?? []
        XCTAssertTrue(contents.isEmpty, "nothing written on failure")
    }
}
```

- [ ] **Step 2: Run — verify it fails**

Run: `xcodebuild test … -only-testing:DocumentScannerTests/PDFImporterTests`
Expected: FAIL to compile — `PDFImporter` / `PDFImporterError` undefined.

- [ ] **Step 3: Implement**

Create `DocumentScanner/DocumentScanner/Import/PDFImporter.swift`:

```swift
import Foundation
import PDFKit

enum PDFImporterError: Error, Equatable {
    case unreadablePDF
}

/// Imports an existing PDF into the library by reusing `DocumentStorage`. Used by
/// both entry points (the document handler and the in-app picker). The source file
/// is never moved or deleted — we copy it in.
enum PDFImporter {
    /// - Parameters:
    ///   - sourceURL: a possibly security-scoped URL from Files / another app.
    ///   - storage: destination storage (root or the current folder).
    /// - Returns: the new document's URL.
    /// - Throws: `PDFImporterError.unreadablePDF` if the file isn't a readable PDF,
    ///   or a `DocumentStorage` error on write failure.
    static func importPDF(from sourceURL: URL, using storage: DocumentStorage) throws -> URL {
        let scoped = sourceURL.startAccessingSecurityScopedResource()
        defer { if scoped { sourceURL.stopAccessingSecurityScopedResource() } }

        guard let pdf = PDFDocument(url: sourceURL) else {
            throw PDFImporterError.unreadablePDF
        }
        let name = sourceURL.deletingPathExtension().lastPathComponent
        return try storage.write(pdf, preferredName: name)
    }
}
```

- [ ] **Step 4: Run — verify it passes**

Run: same `-only-testing:DocumentScannerTests/PDFImporterTests`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add DocumentScanner/DocumentScanner/Import/PDFImporter.swift DocumentScanner/DocumentScannerTests/PDFImporterTests.swift
git commit -m "feat: PDFImporter — import a PDF via the existing DocumentStorage"
```

---

## Task 2: Declare the app as a PDF handler (Info.plist)

**Files:**
- Modify: `DocumentScanner/DocumentScanner/Info.plist`

- [ ] **Step 1: Add the document type + in-place support**

In `DocumentScanner/DocumentScanner/Info.plist`, add these keys inside the top-level `<dict>` (e.g. right after the `UILaunchStoryboardName` entry):

```xml
	<key>CFBundleDocumentTypes</key>
	<array>
		<dict>
			<key>CFBundleTypeName</key>
			<string>PDF Document</string>
			<key>LSItemContentTypes</key>
			<array>
				<string>com.adobe.pdf</string>
			</array>
			<key>CFBundleTypeRole</key>
			<string>Editor</string>
			<key>LSHandlerRank</key>
			<string>Alternate</string>
		</dict>
	</array>
	<key>LSSupportsOpeningDocumentsInPlace</key>
	<true/>
```

Rationale: this makes **"Open in Pocket Scanner"** appear wherever the user has a PDF (Mail, Files, Safari). `LSSupportsOpeningDocumentsInPlace = true` gives us the user's file in place as a security-scoped URL (which `PDFImporter` already handles) — so we copy it in with **no Inbox copy to clean up**. `LSHandlerRank = Alternate` (we're not claiming to be the default PDF app).

- [ ] **Step 2: Verify it builds**

Run: `xcodebuild build -project DocumentScanner/DocumentScanner.xcodeproj -scheme DocumentScanner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO`
Expected: BUILD SUCCEEDED (Info.plist parses).

- [ ] **Step 3: Commit**

```bash
git add DocumentScanner/DocumentScanner/Info.plist
git commit -m "feat: declare the app as a PDF handler (Open in Pocket Scanner)"
```

---

## Task 3: Document handler — `.onOpenURL`

**Files:**
- Modify: `DocumentScanner/DocumentScanner/App/DocumentScannerApp.swift`

- [ ] **Step 1: Add the handler method**

In `DocumentScannerApp`, add a method (near `handleIncoming`/the other private helpers, e.g. just before `appAlert`):

```swift
    /// Imports a PDF opened from another app (Mail/Files/Safari) into the library
    /// root, then refreshes the active store. Errors surface via the alert center.
    private func handleIncomingPDF(_ url: URL) {
        guard url.pathExtension.lowercased() == "pdf" else { return }
        let storage = DocumentStorage(documentsURL: resolvedDocumentsURL)
        do {
            _ = try PDFImporter.importPDF(from: url, using: storage)
            if iCloudAvailable { metadataStore.refresh() } else { localStore.refresh() }
        } catch {
            alertCenter.present(AppAlert(
                title: "Couldn't Import",
                message: "That file isn't a readable PDF."))
        }
    }
```

- [ ] **Step 2: Attach `.onOpenURL` to the scene content**

In `body`, on the outer `Group { … }` (the same place `.touchIndicators()` is applied), add:

```swift
            .touchIndicators()
            .onOpenURL { url in handleIncomingPDF(url) }
```

(so the whole existing `.touchIndicators()` line becomes those two chained modifiers).

- [ ] **Step 3: Build**

Run: `xcodebuild build -project DocumentScanner/DocumentScanner.xcodeproj -scheme DocumentScanner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO`
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add DocumentScanner/DocumentScanner/App/DocumentScannerApp.swift
git commit -m "feat: import PDFs opened from other apps (.onOpenURL)"
```

---

## Task 4: In-app "Import PDF" picker

Add "Import PDF" to the `＋` menu in **both** the root library and folder views, presenting a Files picker that imports into that view's storage. Same pattern in each.

**Files:**
- Modify: `DocumentScanner/DocumentScanner/Library/LibraryView.swift`
- Modify: `DocumentScanner/DocumentScanner/Library/FolderContentsView.swift`

- [ ] **Step 1: LibraryView — import UTType + state**

At the top of `LibraryView.swift`, add `import UniformTypeIdentifiers`. Add state near the other `@State` vars (after `showingNewFolderAlert`):

```swift
    @State private var showingImporter = false
    @State private var importError: String?
```

- [ ] **Step 2: LibraryView — always a menu, with "Import PDF"**

Replace the `ToolbarItem(placement: .topBarTrailing) { if showFolders { Menu { … } … } else { Button { … } … } }` block with a single menu:

```swift
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            triggerScan()
                        } label: {
                            Label("Scan Document", systemImage: "doc.viewfinder")
                        }
                        Button {
                            showingImporter = true
                        } label: {
                            Label("Import PDF", systemImage: "square.and.arrow.down")
                        }
                        if showFolders {
                            Button {
                                newFolderName = ""
                                showingNewFolderAlert = true
                            } label: {
                                Label("New Folder", systemImage: "folder.badge.plus")
                            }
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityIdentifier("Library.AddButton")
                }
```

(This keeps `Library.AddButton` as a menu — the UI tests already tap it then choose "Scan Document", so they still pass.)

- [ ] **Step 3: LibraryView — the `.fileImporter` + error alert**

Add these modifiers alongside the other `.alert(...)` modifiers on the content (e.g. after the `.alert("New Folder", …)` block):

```swift
            .fileImporter(isPresented: $showingImporter,
                          allowedContentTypes: [.pdf],
                          allowsMultipleSelection: false) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    do {
                        _ = try PDFImporter.importPDF(from: url, using: storage)
                        store.refresh()
                    } catch {
                        importError = "That file isn't a readable PDF."
                    }
                case .failure:
                    importError = "Couldn't import the file."
                }
            }
            .alert("Couldn't Import", isPresented: Binding(
                get: { importError != nil },
                set: { if !$0 { importError = nil } }
            )) {
                Button("OK", role: .cancel) { importError = nil }
            } message: {
                Text(importError ?? "")
            }
```

> If the compiler reports "unable to type-check this expression in reasonable time" on `LibraryView`'s body (it has many modifiers), extract the `.fileImporter` + its `.alert` into a small `@ViewBuilder private func importModifiers(...)`-style helper or a `ViewModifier`, the same fix used in `DocumentViewerView` (`dateStampContent`). Re-run the build.

- [ ] **Step 4: FolderContentsView — mirror the change**

Apply the same four edits to `FolderContentsView.swift`: add `import UniformTypeIdentifiers`; add `showingImporter`/`importError` state; add "Import PDF" to its `＋` menu (the `Folder.AddButton` menu); add the identical `.fileImporter` + `.alert` (using this view's `storage` and `store.refresh()`). The folder's `storage` is already scoped to that folder, so imports land in the open folder.

- [ ] **Step 5: Build + full unit suite**

Run: `xcodebuild test -project DocumentScanner/DocumentScanner.xcodeproj -scheme DocumentScanner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:DocumentScannerTests`
Expected: PASS — all prior tests + `PDFImporterTests`. (Confirms both views compile and nothing regressed.)

- [ ] **Step 6: Commit**

```bash
git add DocumentScanner/DocumentScanner/Library/LibraryView.swift DocumentScanner/DocumentScanner/Library/FolderContentsView.swift
git commit -m "feat: in-app Import PDF (＋ menu → Files picker) in library + folders"
```

---

## Task 5: Docs

**Files:**
- Modify: `docs/FutureEnhancements.md`

- [ ] **Step 1: Mark Import a PDF built**

In `docs/FutureEnhancements.md`, change the `### Import a PDF` heading's entry from a candidate to built. Replace the opening paragraph so it leads with the built status (keep the OCR-on-import follow-up bullet beneath it):

```markdown
### Import a PDF (bring in an emailed document)

~~**Import a PDF**~~ — **Built (branch `feature/import-pdf`, v2.9).** Two entry points
feed a shared `PDFImporter` that writes through the existing `DocumentStorage`: (1) a
**document handler** — Info.plist declares the app opens PDFs (`CFBundleDocumentTypes`
+ `LSSupportsOpeningDocumentsInPlace`), so **"Open in Pocket Scanner"** appears in
Mail/Files/Safari (`.onOpenURL` → import to root); (2) an in-app **"Import PDF"** item
in the `＋` menu (`.fileImporter` → import to the current folder). No new pipeline — the
library already lists any `*.pdf`, search reads `pdf.string`, and view/sign/date work
on any `PDFDocument`. iCloud-agnostic (rides `DocumentStorage`; works signed-out into
local storage). Spec/plan under `docs/superpowers/` dated 2026-07-12.
```

- [ ] **Step 2: Commit**

```bash
git add docs/FutureEnhancements.md
git commit -m "docs: mark Import a PDF built (v2.9)"
```

---

## After all tasks

- **On-device smoke** (Release build; can't be unit-tested): 
  1. In **Mail/Files/Safari**, open a PDF → Share/⋯ → **Open in Pocket Scanner** → it appears at the top of the library, opens, is **searchable** (born-digital), and can be **signed + dated**.
  2. `＋ → Import PDF` at root → pick a PDF → lands at root; repeat inside a folder → lands in that folder.
  3. Import an **invalid/non-PDF** (if reachable) → "Couldn't Import" alert, nothing added.
  4. **Signed out of iCloud** → import still works (local storage).
- Then use **superpowers:finishing-a-development-branch** to merge.
- Version bump to **2.9 (28)** + What's New + submit happen at release time (after v2.8 goes live — one version in review at a time).

---

## Self-review notes (checked against the spec)

- **Spec coverage:** shared `PDFImporter` reusing `DocumentStorage` (Task 1); document handler via Info.plist + `.onOpenURL` (Tasks 2–3); in-app picker in library + folders (Task 4); iCloud-agnostic (Task 3 uses `resolvedDocumentsURL`; Task 4 uses each view's `storage`); no OCR / silent import / filename naming / single file (Tasks 1 & 4); errors → alert (Tasks 3–4); refresh-after-import (Tasks 3–4). All covered.
- **Type consistency:** `PDFImporter.importPDF(from:using:) -> URL`, `PDFImporterError.unreadablePDF`, `DocumentStorage.write(_:preferredName:)`, `AlertCenter.present(AppAlert(title:message:))`, `showingImporter`/`importError` used identically across tasks.
- **No placeholders:** every step has complete code/markup and exact commands.
- **Keyword check:** method is `importPDF` (not `import`, a Swift keyword).
