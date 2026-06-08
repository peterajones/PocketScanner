# Filter at Scan Time Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the user pick a filter (Color / Greyscale / B&W / Photo) with a live page-1 preview while saving a fresh scan, baking it into every page.

**Architecture:** Split `ScanPipeline` into `recognize` (OCR on the original images, run in the background while naming) and `assemble(pages:filter:)` (applies the filter, builds the searchable PDF). The Save sheet gains a downscaled page-1 preview + a segmented filter picker and calls `assemble` with the chosen filter on Save. OCR always runs on the original image so filters never degrade text recognition.

**Tech Stack:** Swift, SwiftUI, PDFKit, CoreImage (`ImageFilterEngine`), XCTest, xcodebuild.

---

## Conventions for this plan

- **Run tests / build** (from repo root):

  ```bash
  cd DocumentScanner && xcodebuild build \
    -scheme DocumentScanner -destination 'platform=iOS Simulator,name=iPhone 17'
  cd DocumentScanner && xcodebuild test \
    -scheme DocumentScanner -destination 'platform=iOS Simulator,name=iPhone 17' \
    -only-testing:DocumentScannerTests/<ClassName>
  ```

  Full unit suite: `-only-testing:DocumentScannerTests`. If `iPhone 17` isn't
  installed, run `xcrun simctl list devices available` and substitute.

- **SourceKit/LSP false positives:** "No such module 'SwiftUI'/'PDFKit'/'UIKit'"
  and "Cannot find type" diagnostics appear constantly in this project and are
  spurious. `xcodebuild` is the source of truth.

- **Commit trailer:** every commit ends with
  `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.

- **Two UI tests are known-broken in the simulator** (`GoldenPathTests`,
  `EditModeTests`) — they fail on a clean `main` too. Ignore them; rely on the
  `DocumentScannerTests` unit bundle.

---

## File Structure

- **Modify** `Pipeline/ScanPipeline.swift` — split into `recognize` +
  `assemble(pages:filter:)`; keep `process` as a no-filter convenience.
- **Modify** `Capture/NameDocumentSheet.swift` — new inputs (raw images + recognize
  task + pipeline); page-1 preview + segmented filter picker; assemble-with-filter
  on save.
- **Modify** `Library/LibraryView.swift` & `Library/FolderContentsView.swift` —
  update each `NameSheetContext` + capture `onFinish` + `.sheet` to the new inputs.
- **Modify** `DocumentScannerTests/ScanPipelineTests.swift` — cover `recognize` and
  `assemble(pages:filter:)`.

---

## Task 1: Split `ScanPipeline` (recognize + assemble-with-filter)

**Files:**
- Modify: `DocumentScanner/DocumentScanner/Pipeline/ScanPipeline.swift`
- Test: `DocumentScanner/DocumentScannerTests/ScanPipelineTests.swift`

- [ ] **Step 1: Add the failing tests**

In `DocumentScanner/DocumentScannerTests/ScanPipelineTests.swift`, add these two
tests after `test_process_returnsConcatenatedOCRText` (they use the existing
`whiteImage()` helper and `StubOCR`):

```swift
    func test_recognize_returnsPagePerImageWithObservations() async throws {
        let images = [whiteImage(), whiteImage()]
        let pipeline = ScanPipeline(ocr: StubOCR(returning: ["alpha"]))
        let pages = await pipeline.recognize(images: images)
        XCTAssertEqual(pages.count, 2)
        XCTAssertTrue(pages.allSatisfy { page in
            page.observations.contains { $0.string == "alpha" }
        })
    }

    func test_assemble_withFilter_keepsSearchableTextLayer() async throws {
        let needle = "FilterNeedle"
        let pipeline = ScanPipeline(ocr: StubOCR(returning: [needle]))
        let pages = await pipeline.recognize(images: [whiteImage()])
        let result = try await pipeline.assemble(pages: pages, filter: .blackAndWhite)
        XCTAssertEqual(result.pdf.pageCount, 1)
        XCTAssertFalse(result.pdf.findString(needle, withOptions: .caseInsensitive).isEmpty,
                       "the B&W filter must not break the OCR text layer")
        XCTAssertTrue(result.ocrText.contains(needle))
    }
```

- [ ] **Step 2: Run to verify it fails**

Run:
```bash
cd DocumentScanner && xcodebuild test \
  -scheme DocumentScanner -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:DocumentScannerTests/ScanPipelineTests
```
Expected: FAIL to compile — `recognize`/`assemble` are not members of `ScanPipeline`.

- [ ] **Step 3: Split the pipeline**

In `DocumentScanner/DocumentScanner/Pipeline/ScanPipeline.swift`, add a stored
filter engine and replace the single `process(images:createdAt:)` method with the
three methods below. First add the engine property next to the other stored
properties:

```swift
    private let ocr: OCRProviding
    private let assembler: PDFAssembler
    private let filterEngine = ImageFilterEngine()
    private let logger = Logger(subsystem: "ca.peter-jones.DocumentScanner", category: "Pipeline")
```

Then replace the whole `func process(...) { ... }` method with:

```swift
    /// OCR each image. OCR runs on the ORIGINAL (unfiltered) image so that a
    /// later visual filter never degrades text recognition. Per-page OCR
    /// failures are logged and absorbed — the page is still returned, without a
    /// text layer.
    func recognize(images: [UIImage]) async -> [ScannedPage] {
        var pages: [ScannedPage] = []
        pages.reserveCapacity(images.count)
        for (index, image) in images.enumerated() {
            let observations: [OCRObservation]
            do {
                observations = try await ocr.recognizeText(in: image)
            } catch {
                logger.error("OCR failed on page \(index + 1, privacy: .public): \(error.localizedDescription, privacy: .public)")
                observations = []
            }
            pages.append(ScannedPage(image: image, observations: observations))
        }
        return pages
    }

    /// Apply `filter` to each page's image, then assemble the searchable PDF from
    /// the filtered images + the (original-image) observations. A filter that
    /// fails to render falls back to the original image.
    func assemble(pages: [ScannedPage], filter: ImageFilter, createdAt: Date = .init()) throws -> ScanResult {
        let filteredPages = pages.map { page -> ScannedPage in
            let image = filterEngine.apply(filter, to: page.image) ?? page.image
            return ScannedPage(image: image, observations: page.observations)
        }
        let pdf = try assembler.assemble(pages: filteredPages, createdAt: createdAt)
        let ocrText = pages
            .flatMap(\.observations)
            .map(\.string)
            .joined(separator: "\n")
        return ScanResult(pdf: pdf, ocrText: ocrText)
    }

    /// Convenience: recognize + assemble with no filter. Used by add-pages and
    /// any caller that doesn't offer a filter choice.
    func process(images: [UIImage], createdAt: Date = .init()) async throws -> ScanResult {
        let pages = await recognize(images: images)
        return try assemble(pages: pages, filter: .none, createdAt: createdAt)
    }
```

(Leave the file's `import` lines, `ScanResult` struct, and `init` unchanged.)

- [ ] **Step 4: Run to verify it passes**

Run:
```bash
cd DocumentScanner && xcodebuild test \
  -scheme DocumentScanner -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:DocumentScannerTests/ScanPipelineTests
```
Expected: PASS (all five tests — the three existing `process` tests still pass via
the convenience method).

- [ ] **Step 5: Commit**

```bash
git add DocumentScanner/DocumentScanner/Pipeline/ScanPipeline.swift \
        DocumentScanner/DocumentScannerTests/ScanPipelineTests.swift
git commit -m "feat: split ScanPipeline into recognize + assemble(filter)"
```

---

## Task 2: Rewire the Save sheet onto the new plumbing (no UI yet)

Swap `NameDocumentSheet` and both call sites from a finished-`ScanResult` task to
raw images + a background `recognize` task, saving with `filter: .none`. No visible
change yet — this just moves the wiring so Task 3 can add the picker.

**Files:**
- Modify: `DocumentScanner/DocumentScanner/Capture/NameDocumentSheet.swift`
- Modify: `DocumentScanner/DocumentScanner/Library/LibraryView.swift`
- Modify: `DocumentScanner/DocumentScanner/Library/FolderContentsView.swift`

- [ ] **Step 1: Rewrite `NameDocumentSheet` (no filter UI)**

Replace the ENTIRE contents of `DocumentScanner/DocumentScanner/Capture/NameDocumentSheet.swift` with:

```swift
import SwiftUI
import PDFKit

/// Modal shown after capture. Lets the user name the document while OCR runs in
/// the background; Save applies the chosen filter (none for now — the picker is
/// added in a later step) and writes the assembled PDF to disk.
struct NameDocumentSheet: View {
    let images: [UIImage]
    let recognizeTask: Task<[ScannedPage], Never>
    let pipeline: ScanPipeline
    let storage: DocumentStorage
    let onSaved: () -> Void
    let onCancel: () -> Void

    @State private var name: String = DefaultDocumentName.fallback()
    @State private var hasUserEdited = false
    @State private var isWorking = false
    @Environment(\.alertCenter) private var alertCenter

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Name", text: Binding(
                        get: { name },
                        set: { newValue in
                            hasUserEdited = true
                            name = newValue
                        }
                    ))
                        .textInputAutocapitalization(.words)
                        .disabled(isWorking)
                        .accessibilityIdentifier("NameSheet.NameField")
                }
            }
            .navigationTitle("Save Scan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        recognizeTask.cancel()
                        onCancel()
                    }
                    .disabled(isWorking)
                    .accessibilityIdentifier("NameSheet.Cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isWorking {
                        ProgressView()
                    } else {
                        Button("Save") { Task { await save() } }
                            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                            .accessibilityIdentifier("NameSheet.Save")
                    }
                }
            }
            .task { await refineDefaultName() }
        }
        .interactiveDismissDisabled(isWorking)
    }

    /// While OCR runs, the sheet shows a timestamp default. Once recognition
    /// finishes, swap in a smarter name — but only if the user hasn't already
    /// started typing their own.
    private func refineDefaultName() async {
        let pages = await recognizeTask.value
        guard !hasUserEdited else { return }
        let ocrText = pages.flatMap(\.observations).map(\.string).joined(separator: "\n")
        if let suggestion = DefaultDocumentName.suggest(from: ocrText) {
            name = suggestion
        }
    }

    private func save() async {
        isWorking = true
        defer { isWorking = false }
        do {
            let pages = await recognizeTask.value
            let result = try await pipeline.assemble(pages: pages, filter: .none)
            _ = try storage.write(result.pdf, preferredName: name)
            onSaved()
        } catch {
            alertCenter.present(AppAlert(
                title: "Couldn't save",
                message: error.localizedDescription,
                primary: AppAlert.Action(title: "Retry", role: .default, handler: {
                    Task { await save() }
                }),
                secondary: AppAlert.Action(title: "Cancel", role: .cancel, handler: {
                    onCancel()
                })
            ))
        }
    }
}
```

- [ ] **Step 2: Update `LibraryView`'s `NameSheetContext`, capture `onFinish`, and `.sheet`**

In `DocumentScanner/DocumentScanner/Library/LibraryView.swift`:

(a) Replace the `NameSheetContext` struct:

```swift
    private struct NameSheetContext: Identifiable {
        let id = UUID()
        let task: Task<ScanResult, Error>
    }
```

with:

```swift
    private struct NameSheetContext: Identifiable {
        let id = UUID()
        let images: [UIImage]
        let recognizeTask: Task<[ScannedPage], Never>
    }
```

(b) Replace the capture `onFinish` body:

```swift
                        showingCapture = false
                        let task = Task { try await pipeline.process(images: images) }
                        nameSheet = NameSheetContext(task: task)
```

with:

```swift
                        showingCapture = false
                        let captured = images
                        let recognizeTask = Task { await pipeline.recognize(images: captured) }
                        nameSheet = NameSheetContext(images: captured, recognizeTask: recognizeTask)
```

(c) Replace the `NameDocumentSheet(...)` call:

```swift
                NameDocumentSheet(
                    pipelineTask: ctx.task,
                    storage: storage,
                    onSaved: {
                        nameSheet = nil
                        store.refresh()
                    },
                    onCancel: { nameSheet = nil }
                )
```

with:

```swift
                NameDocumentSheet(
                    images: ctx.images,
                    recognizeTask: ctx.recognizeTask,
                    pipeline: pipeline,
                    storage: storage,
                    onSaved: {
                        nameSheet = nil
                        store.refresh()
                    },
                    onCancel: { nameSheet = nil }
                )
```

- [ ] **Step 3: Update `FolderContentsView` the same way**

In `DocumentScanner/DocumentScanner/Library/FolderContentsView.swift`:

(a) Replace the `NameSheetContext` struct:

```swift
    private struct NameSheetContext: Identifiable {
        let id = UUID()
        let task: Task<ScanResult, Error>
    }
```

with:

```swift
    private struct NameSheetContext: Identifiable {
        let id = UUID()
        let images: [UIImage]
        let recognizeTask: Task<[ScannedPage], Never>
    }
```

(b) Replace the capture `onFinish` body:

```swift
                    showingCapture = false
                    let task = Task { try await pipeline.process(images: images) }
                    nameSheet = NameSheetContext(task: task)
```

with:

```swift
                    showingCapture = false
                    let captured = images
                    let recognizeTask = Task { await pipeline.recognize(images: captured) }
                    nameSheet = NameSheetContext(images: captured, recognizeTask: recognizeTask)
```

(c) Replace the `NameDocumentSheet(...)` call (note it passes `folderStorage`):

```swift
            NameDocumentSheet(
                pipelineTask: ctx.task,
                storage: folderStorage,
                onSaved: {
                    nameSheet = nil
                    store.refresh()
                },
                onCancel: { nameSheet = nil }
            )
```

with:

```swift
            NameDocumentSheet(
                images: ctx.images,
                recognizeTask: ctx.recognizeTask,
                pipeline: pipeline,
                storage: folderStorage,
                onSaved: {
                    nameSheet = nil
                    store.refresh()
                },
                onCancel: { nameSheet = nil }
            )
```

- [ ] **Step 4: Build + full unit suite**

Run the build command, then the full test command. Expected: BUILD SUCCEEDED and
TEST SUCCEEDED (behavior is unchanged — still saves in Color).

- [ ] **Step 5: Commit**

```bash
git add DocumentScanner/DocumentScanner/Capture/NameDocumentSheet.swift \
        DocumentScanner/DocumentScanner/Library/LibraryView.swift \
        DocumentScanner/DocumentScanner/Library/FolderContentsView.swift
git commit -m "refactor: Save sheet uses recognize + assemble plumbing"
```

---

## Task 3: Add the page-1 preview + filter picker

**Files:**
- Modify: `DocumentScanner/DocumentScanner/Capture/NameDocumentSheet.swift`

- [ ] **Step 1: Add filter state + preview state and a downscale helper**

In `NameDocumentSheet`, add these properties after `@State private var isWorking = false`:

```swift
    @State private var filter: ImageFilter = .none
    @State private var previewBase: UIImage?     // downscaled page 1
    @State private var previewImage: UIImage?    // previewBase with `filter` applied
    private let filterEngine = ImageFilterEngine()
```

Add this helper method (next to `save()`):

```swift
    /// Downscale page 1 so live filtering stays snappy regardless of scan size.
    /// Done on the main actor (a single resize) to avoid a non-Sendable UIImage
    /// capture across a detached task (a Swift 6 concurrency error).
    private func loadPreviewBase() {
        guard let first = images.first else { return }
        let base = Self.downscaled(first, maxDimension: 1000)
        previewBase = base
        previewImage = base   // filter defaults to .none
    }

    private func applyFilterToPreview() {
        guard let base = previewBase else { return }
        previewImage = filterEngine.apply(filter, to: base) ?? base
    }

    private static func downscaled(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > maxDimension else { return image }
        let scale = maxDimension / longest
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
```

- [ ] **Step 2: Add the preview + picker sections to the Form**

In `body`, replace the `Form { Section("Name") { … } }` block with:

```swift
            Form {
                Section {
                    if let previewImage {
                        Image(uiImage: previewImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .frame(maxHeight: 280)
                            .accessibilityIdentifier("NameSheet.Preview")
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 160)
                    }
                }
                Section("Filter") {
                    Picker("Filter", selection: $filter) {
                        ForEach(ImageFilter.allCases) { f in
                            Text(f.displayName).tag(f)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(isWorking)
                    .accessibilityIdentifier("NameSheet.FilterPicker")
                }
                Section("Name") {
                    TextField("Name", text: Binding(
                        get: { name },
                        set: { newValue in
                            hasUserEdited = true
                            name = newValue
                        }
                    ))
                        .textInputAutocapitalization(.words)
                        .disabled(isWorking)
                        .accessibilityIdentifier("NameSheet.NameField")
                }
            }
```

- [ ] **Step 3: Wire the preview lifecycle and use the chosen filter on save**

(a) Add a preview-load `.task` and a filter-change handler. In `body`, change:

```swift
            .task { await refineDefaultName() }
        }
        .interactiveDismissDisabled(isWorking)
```

to:

```swift
            .task { await refineDefaultName() }
            .task { loadPreviewBase() }
            .onChange(of: filter) { _, _ in applyFilterToPreview() }
        }
        .interactiveDismissDisabled(isWorking)
```

(b) In `save()`, change the assemble call to use the chosen filter:

```swift
            let result = try await pipeline.assemble(pages: pages, filter: .none)
```

to:

```swift
            let result = try await pipeline.assemble(pages: pages, filter: filter)
```

- [ ] **Step 4: Build to verify**

Run the build command. Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Commit**

```bash
git add DocumentScanner/DocumentScanner/Capture/NameDocumentSheet.swift
git commit -m "feat: page-1 filter preview + picker in the Save sheet"
```

---

## Task 4: Version bump + manual smoke test

**Files:**
- Modify: `DocumentScanner/DocumentScanner.xcodeproj/project.pbxproj` (via Xcode UI)

- [ ] **Step 1: Bump version (manual, in Xcode)**

Xcode → target **DocumentScanner** → General: set **Version** to `1.6` and **Build**
to `11`. Updates `MARKETING_VERSION` (1.5 → 1.6) and `CURRENT_PROJECT_VERSION`
(10 → 11) for the main-app Debug + Release configs; leave the test targets.

Verify:
```bash
grep -n "MARKETING_VERSION\|CURRENT_PROJECT_VERSION" \
  DocumentScanner/DocumentScanner.xcodeproj/project.pbxproj
```
Expected: main-app configs show `MARKETING_VERSION = 1.6;` / `CURRENT_PROJECT_VERSION = 11;`.

- [ ] **Step 2: Manual smoke test (device/simulator — user-driven)**

  1. Scan a (multi-page) document → the Save sheet shows a **page-1 preview**, a
     **Color/Greyscale/B&W/Photo** picker, and the name field.
  2. Tap each preset → the preview updates live; Color shows the original.
  3. Pick **B&W**, Save → open the doc → **every page** is B&W, and **search**
     still finds text in it (OCR survived).
  4. Scan again → the picker is back on **Color** (no carry-over); saving without
     touching it produces a normal colour scan.
  5. Add-pages from the viewer still works (uses the unchanged `process` path).

- [ ] **Step 3: Commit the version bump**

```bash
git add DocumentScanner/DocumentScanner.xcodeproj/project.pbxproj
git commit -m "chore: bump to v1.6 (11)"
```

---

## Done

After Task 3 the Save sheet offers a live page-1 filter preview + picker that bakes
the chosen preset into every page, with OCR preserved on the originals and the
unit suite green. Next steps (outside this plan): push, archive, upload, submit —
same flow as prior releases.
