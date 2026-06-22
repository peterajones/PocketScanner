# Signature Signing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a user scan a pen-on-paper signature, auto-clean it to a transparent cut-out, save one reusable signature, and drag/resize it onto a page as an editable (deletable) stamp. Ships as **v2.0 (18)**.

**Architecture:** A new `Signature/` group: `SignatureProcessor` (scan → transparent PNG, pure/testable), `SignatureStore` (persist the one PNG), `SignatureCaptureView` (scan → preview → save), `SignaturePlacementView` (drag/resize overlay → commit). Touch points: `SettingsView` (Signature section) and `DocumentViewerView` (Sign action + stamp create/delete). Reuses the existing scan capture (`CaptureSheet`), `PerspectiveCorrector`, the B&W `ImageFilter`, and the annotation tap-delete + `DocumentSession.save()` paths.

**Tech Stack:** Swift, SwiftUI, PDFKit (stamp `PDFAnnotation`), Core Image (luminance→alpha key), VisionKit (existing capture), XCTest.

**Spec:** `docs/superpowers/specs/2026-06-22-signature-signing-design.md`

---

## File Structure

- Create: `Signature/SignatureProcessor.swift` — scan `UIImage` → tight transparent `UIImage` (Core Image keying + crop).
- Create: `Signature/SignatureStore.swift` — save/load/clear the one signature PNG in Application Support.
- Create: `Signature/SignatureCaptureView.swift` — scan (`CaptureSheet`) → `SignatureProcessor` → checkerboard preview → Save/Rescan.
- Create: `Signature/SignaturePlacementView.swift` — drag/pinch overlay over the current page → emit a page-space rect.
- Create: `Signature/ImageStampAnnotation.swift` — `PDFAnnotation` subclass that renders the signature image (created in Task 1's spike, kept if persistence works).
- Modify: `Viewer/DocumentViewerView.swift` — "Sign" toolbar action, placement presentation, stamp create, tap-delete recognition.
- Modify: `Viewer/DocumentSession.swift` — `signatureAnnotationName` tag.
- Modify: `Annotations/AnnotationFactory.swift` — `isUserDeletable` recognizes the signature stamp.
- Modify: `Settings/SettingsView.swift` — Signature section.
- Modify: `docs/FutureEnhancements.md` + memory — on merge.
- Test: `DocumentScannerTests/SignatureProcessorTests.swift`, `SignatureStoreTests.swift`, `SignatureAnnotationPersistenceTests.swift`.

Build / test commands:
```bash
cd DocumentScanner && xcodebuild build \
  -scheme DocumentScanner -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -5
cd DocumentScanner && xcodebuild test \
  -scheme DocumentScanner -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:DocumentScannerTests 2>&1 | grep -E "\*\* TEST|failed" | tail -5
```

> SourceKit may show "cannot find … in scope" / "No such module" for these files — stale-index
> artifacts. `xcodebuild` is the source of truth.

---

## Task 1: Persistence spike — does an image stamp survive save→reload? (GO/NO-GO)

**Why first:** the spec's editable-stamp model depends on a PDF-embedded image annotation surviving a disk round-trip. A custom `PDFAnnotation` subclass that only overrides `draw(with:in:)` renders at runtime but may **not** persist (PDFKit re-instantiates a plain annotation on load). This task proves it one way or the other **before** any UI is built. If it fails, STOP and report to the controller — the fallback (flatten-on-commit, permanent) is a user decision, not a silent switch.

**Files:**
- Create: `DocumentScanner/DocumentScanner/Signature/ImageStampAnnotation.swift`
- Test: `DocumentScanner/DocumentScannerTests/SignatureAnnotationPersistenceTests.swift`

- [ ] **Step 1: Implement the image stamp annotation (with an embedded appearance so it can persist)**

Create `Signature/ImageStampAnnotation.swift`:

```swift
import PDFKit
import UIKit

/// A stamp annotation that draws a (signature) image. Draws at runtime via the
/// override; to survive a save→reload round-trip it must also carry a PDF
/// appearance stream, which `draw(with:in:)` alone does not create — Task 1's
/// spike verifies whether PDFKit persists this. Tagged so the viewer's
/// tap-to-delete recognizes it.
final class ImageStampAnnotation: PDFAnnotation {
    private let image: UIImage

    init(image: UIImage, bounds: CGRect, userName: String) {
        self.image = image
        super.init(bounds: bounds, forType: .stamp, withProperties: nil)
        self.userName = userName
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draw(with box: PDFDisplayBox, in context: CGContext) {
        super.draw(with: box, in: context)
        guard let cg = image.cgImage else { return }
        context.saveGState()
        context.draw(cg, in: bounds)
        context.restoreGState()
    }
}
```

- [ ] **Step 2: Write the persistence test**

Create `DocumentScannerTests/SignatureAnnotationPersistenceTests.swift`:

```swift
import XCTest
import PDFKit
import UIKit
@testable import DocumentScanner

final class SignatureAnnotationPersistenceTests: XCTestCase {

    private func solidImage(_ color: UIColor, _ size: CGSize) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { ctx in
            color.setFill(); ctx.fill(CGRect(origin: .zero, size: size))
        }
    }

    /// A one-page PDF with an image stamp annotation, written to data and
    /// reloaded, must still expose an annotation tagged as our signature on the
    /// page. This is the GO/NO-GO for the editable-stamp model.
    func test_imageStampAnnotation_survivesDataRoundTrip() throws {
        let pdf = PDFDocument()
        let page = PDFPage()
        pdf.insert(page, at: 0)
        let bounds = page.bounds(for: .mediaBox)

        let stamp = ImageStampAnnotation(
            image: solidImage(.black, CGSize(width: 100, height: 40)),
            bounds: CGRect(x: 50, y: 50, width: 100, height: 40),
            userName: "DocumentScanner.signature")
        page.addAnnotation(stamp)

        let data = try XCTUnwrap(pdf.dataRepresentation())
        let reloaded = try XCTUnwrap(PDFDocument(data: data))
        let reloadedPage = try XCTUnwrap(reloaded.page(at: 0))

        let signatureAnnos = reloadedPage.annotations.filter {
            $0.userName == "DocumentScanner.signature"
        }
        XCTAssertFalse(signatureAnnos.isEmpty,
            "Image stamp annotation did not survive the PDF data round-trip — editable-stamp model is not viable as-is; escalate for the flatten fallback.")
    }
}
```

- [ ] **Step 3: Run the spike**

```bash
cd DocumentScanner && xcodebuild test -scheme DocumentScanner \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:DocumentScannerTests/SignatureAnnotationPersistenceTests 2>&1 | grep -E "\*\* TEST|failed|passed" | tail -5
```

- [ ] **Step 4: Decision gate**

- **PASS** → the tagged annotation persists. Keep `ImageStampAnnotation`, commit, proceed to Task 2. (If the tag survives but the *image* doesn't render on reload, note it — Task 6 may need to set an appearance stream / re-attach the image on load; report as DONE_WITH_CONCERNS.)
- **FAIL** → STOP. Report BLOCKED to the controller with the result. Do not invent a persistence hack. The controller will escalate to the user to choose flatten-on-commit (permanent), which changes Task 6.

- [ ] **Step 5: Commit (on PASS)**

```bash
git add DocumentScanner/DocumentScanner/Signature/ImageStampAnnotation.swift \
        DocumentScanner/DocumentScannerTests/SignatureAnnotationPersistenceTests.swift
git commit -m "spike: verify image stamp annotation persists across PDF round-trip"
```

---

## Task 2: `SignatureProcessor` — scan → transparent cut-out (pure, tested)

**Files:**
- Create: `DocumentScanner/DocumentScanner/Signature/SignatureProcessor.swift`
- Test: `DocumentScanner/DocumentScannerTests/SignatureProcessorTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `DocumentScannerTests/SignatureProcessorTests.swift`:

```swift
import XCTest
import UIKit
@testable import DocumentScanner

final class SignatureProcessorTests: XCTestCase {

    /// White page with a black bar across the middle — mimics ink on paper.
    private func inkOnPaper(size: CGSize = CGSize(width: 200, height: 200)) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            UIColor.black.setFill()
            ctx.fill(CGRect(x: 40, y: 90, width: 120, height: 20))
        }
    }

    private func alpha(of image: UIImage, atX x: Int, y: Int) -> CGFloat {
        let cg = image.cgImage!
        let w = cg.width, h = cg.height
        var px: [UInt8] = [0, 0, 0, 0]
        let cs = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(data: &px, width: 1, height: 1, bitsPerComponent: 8,
                            bytesPerRow: 4, space: cs,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(cg, in: CGRect(x: -x, y: -(h - 1 - y), width: w, height: h))
        return CGFloat(px[3]) / 255.0
    }

    func test_process_makesPaperTransparent_keepsInkOpaque() throws {
        let out = try XCTUnwrap(SignatureProcessor().process(inkOnPaper()))
        // After auto-crop the result is ~the ink bar. Its center should be opaque ink…
        let cx = out.cgImage!.width / 2, cy = out.cgImage!.height / 2
        XCTAssertGreaterThan(alpha(of: out, atX: cx, y: cy), 0.8, "ink should be opaque")
        // …and a top corner (paper that survived crop margins, if any) should be transparent.
        XCTAssertLessThan(alpha(of: out, atX: 0, y: 0), 0.2, "paper should be transparent")
    }

    func test_process_cropsToInkBounds() throws {
        let src = inkOnPaper(size: CGSize(width: 200, height: 200))
        let out = try XCTUnwrap(SignatureProcessor().process(src))
        // The ink bar is 120x20 inside 200x200 — cropped output is much smaller.
        XCTAssertLessThan(out.size.width, 160)
        XCTAssertLessThan(out.size.height, 80)
    }

    func test_process_blankPage_returnsNil() {
        let blank = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100)).image { ctx in
            UIColor.white.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
        }
        XCTAssertNil(SignatureProcessor().process(blank), "all-paper input has no ink → nil")
    }
}
```

- [ ] **Step 2: Run to verify failure**

```bash
cd DocumentScanner && xcodebuild test -scheme DocumentScanner \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:DocumentScannerTests/SignatureProcessorTests 2>&1 | grep -E "Cannot find|error:|\*\* TEST" | tail -5
```
Expected: FAIL — "Cannot find 'SignatureProcessor' in scope".

- [ ] **Step 3: Implement `SignatureProcessor`**

Create `Signature/SignatureProcessor.swift`:

```swift
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

/// Turns a scanned signature (dark ink on light paper) into a tight transparent
/// cut-out: Black & White → key the paper to alpha → crop to the ink bounds.
/// Pure: same input → same output; no I/O. Returns nil when there's no ink.
struct SignatureProcessor {
    private let context = CIContext()
    private let filterEngine = ImageFilterEngine()

    func process(_ scanned: UIImage) -> UIImage? {
        // 1) Black & White: paper → ~white, ink → ~black (reuse the app preset).
        let bw = filterEngine.apply(.blackAndWhite, to: scanned) ?? scanned
        guard let cg = bw.cgImage else { return nil }
        let input = CIImage(cgImage: cg)

        // 2) Build alpha from inverted luminance, recolor to black ink:
        //    invert (ink→white, paper→black) → maskToAlpha (white→opaque,
        //    black→transparent) → zero RGB keeping alpha (opaque pixels → black).
        let inverted = input.applyingFilter("CIColorInvert")
        let masked = inverted.applyingFilter("CIMaskToAlpha")
        let blackInk = masked.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
            "inputBiasVector": CIVector(x: 0, y: 0, z: 0, w: 0),
        ])

        // 3) Crop to the non-transparent (ink) bounds.
        guard let crop = inkBounds(of: blackInk), !crop.isEmpty else { return nil }
        guard let outCG = context.createCGImage(blackInk, from: crop) else { return nil }
        return UIImage(cgImage: outCG, scale: scanned.scale, orientation: .up)
    }

    /// Tight bounding box of pixels with meaningful alpha, via CIAreaAlphaWeightedROI-free
    /// manual scan of a downscaled alpha raster (cheap, deterministic).
    private func inkBounds(of image: CIImage) -> CGRect? {
        let extent = image.extent
        guard extent.width > 0, extent.height > 0 else { return nil }
        let w = Int(extent.width), h = Int(extent.height)
        var px = [UInt8](repeating: 0, count: w * h * 4)
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8,
                                  bytesPerRow: w * 4, space: cs,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let cg = context.createCGImage(image, from: extent) else { return nil }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))

        var minX = w, minY = h, maxX = -1, maxY = -1
        for y in 0..<h {
            for x in 0..<w {
                if px[(y * w + x) * 4 + 3] > 40 { // alpha threshold
                    if x < minX { minX = x }; if x > maxX { maxX = x }
                    if y < minY { minY = y }; if y > maxY { maxY = y }
                }
            }
        }
        guard maxX >= minX, maxY >= minY else { return nil }
        // CIImage origin is bottom-left; convert the raster (top-left) box back.
        let pad = 4
        let rx = max(0, minX - pad)
        let ry = max(0, (h - 1 - maxY) - pad)
        let rw = min(w - rx, (maxX - minX) + 1 + pad * 2)
        let rh = min(h - ry, (maxY - minY) + 1 + pad * 2)
        return CGRect(x: rx, y: ry, width: rw, height: rh)
    }
}
```

- [ ] **Step 4: Run to verify pass**

```bash
cd DocumentScanner && xcodebuild test -scheme DocumentScanner \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:DocumentScannerTests/SignatureProcessorTests 2>&1 | grep -E "\*\* TEST|failed" | tail -5
```
Expected: `** TEST SUCCEEDED **`. If the alpha-orientation assertions are flipped, adjust the `inkBounds` y-conversion — do not loosen the thresholds.

- [ ] **Step 5: Commit**

```bash
git add DocumentScanner/DocumentScanner/Signature/SignatureProcessor.swift \
        DocumentScanner/DocumentScannerTests/SignatureProcessorTests.swift
git commit -m "feat: SignatureProcessor — scan to transparent signature cut-out (tested)"
```

---

## Task 3: `SignatureStore` — persist the one signature (tested)

**Files:**
- Create: `DocumentScanner/DocumentScanner/Signature/SignatureStore.swift`
- Test: `DocumentScanner/DocumentScannerTests/SignatureStoreTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `DocumentScannerTests/SignatureStoreTests.swift`:

```swift
import XCTest
import UIKit
@testable import DocumentScanner

final class SignatureStoreTests: XCTestCase {

    private func tempStore() -> SignatureStore {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("sigstore-\(UUID())", isDirectory: true)
        return SignatureStore(directory: dir)
    }

    private func image(_ size: CGSize = CGSize(width: 60, height: 24)) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor.black.setFill(); ctx.fill(CGRect(origin: .zero, size: size))
        }
    }

    func test_save_then_load_roundTrips() throws {
        let store = tempStore()
        XCTAssertFalse(store.hasSignature)
        try store.save(image())
        XCTAssertTrue(store.hasSignature)
        let loaded = try XCTUnwrap(store.load())
        XCTAssertEqual(loaded.cgImage?.width, 60)
        XCTAssertEqual(loaded.cgImage?.height, 24)
    }

    func test_clear_removes() throws {
        let store = tempStore()
        try store.save(image())
        store.clear()
        XCTAssertFalse(store.hasSignature)
        XCTAssertNil(store.load())
    }

    func test_load_whenEmpty_isNil() {
        XCTAssertNil(tempStore().load())
    }
}
```

- [ ] **Step 2: Run to verify failure**

```bash
cd DocumentScanner && xcodebuild test -scheme DocumentScanner \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:DocumentScannerTests/SignatureStoreTests 2>&1 | grep -E "Cannot find|error:|\*\* TEST" | tail -5
```
Expected: FAIL — "Cannot find 'SignatureStore' in scope".

- [ ] **Step 3: Implement `SignatureStore`**

Create `Signature/SignatureStore.swift`:

```swift
import UIKit

/// Persists the user's single reusable signature as a transparent PNG. Stored in
/// Application Support (local, not iCloud-synced in v1). Injectable directory so
/// it's unit-testable.
struct SignatureStore {
    private let fileURL: URL

    init(directory: URL = SignatureStore.defaultDirectory) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        self.fileURL = directory.appendingPathComponent("signature.png")
    }

    static var defaultDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Signature", isDirectory: true)
    }

    var hasSignature: Bool { FileManager.default.fileExists(atPath: fileURL.path) }

    func save(_ image: UIImage) throws {
        guard let data = image.pngData() else {
            throw NSError(domain: "SignatureStore", code: 1)
        }
        try data.write(to: fileURL, options: .atomic)
    }

    func load() -> UIImage? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }

    func clear() { try? FileManager.default.removeItem(at: fileURL) }
}
```

- [ ] **Step 4: Run to verify pass**

```bash
cd DocumentScanner && xcodebuild test -scheme DocumentScanner \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:DocumentScannerTests/SignatureStoreTests 2>&1 | grep -E "\*\* TEST|failed" | tail -5
```
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add DocumentScanner/DocumentScanner/Signature/SignatureStore.swift \
        DocumentScanner/DocumentScannerTests/SignatureStoreTests.swift
git commit -m "feat: SignatureStore — persist one reusable signature PNG (tested)"
```

---

## Task 4: `SignatureCaptureView` — scan → preview → save

**Files:**
- Create: `DocumentScanner/DocumentScanner/Signature/SignatureCaptureView.swift`

- [ ] **Step 1: Implement the capture view**

Reuses `CaptureSheet` (the existing `UIViewControllerRepresentable` over `DocumentScannerPresenting`, `onFinish: ([UIImage]) -> Void` / `onCancel`). Create `Signature/SignatureCaptureView.swift`:

```swift
import SwiftUI

/// Scan a signature on paper → SignatureProcessor → preview on a checkerboard
/// → Save (to SignatureStore) or Rescan. Presented from Settings and from the
/// viewer's first-run. Calls `onSaved` after a successful save, `onCancel` if
/// the user backs out without saving.
struct SignatureCaptureView: View {
    let presenter: DocumentScannerPresenting
    let store: SignatureStore
    let onSaved: () -> Void
    let onCancel: () -> Void

    @State private var processed: UIImage?
    @State private var showingScanner = true
    @State private var processingFailed = false

    private let processor = SignatureProcessor()

    var body: some View {
        NavigationStack {
            Group {
                if let processed {
                    VStack(spacing: 16) {
                        Text("Your signature").font(.headline)
                        CheckerboardPreview(image: processed)
                            .frame(maxWidth: .infinity)
                            .frame(height: 200)
                            .padding()
                        Text("Looks good? Save it to reuse on any document.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                } else if processingFailed {
                    ContentUnavailableView("Couldn't read that",
                        systemImage: "signature",
                        description: Text("Try again on a plain, well-lit sheet with a dark pen."))
                } else {
                    ProgressView("Preparing…")
                }
            }
            .navigationTitle("Add Signature")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if processed != nil {
                        Button("Save") { save() }
                    } else {
                        Button("Rescan") { showingScanner = true; processingFailed = false }
                    }
                }
            }
            .fullScreenCover(isPresented: $showingScanner) {
                CaptureSheet(
                    presenter: presenter,
                    onFinish: { images in showingScanner = false; handleScan(images) },
                    onCancel: { showingScanner = false; if processed == nil { onCancel() } }
                )
                .ignoresSafeArea()
            }
        }
    }

    private func handleScan(_ images: [UIImage]) {
        guard let first = images.first else { processingFailed = true; return }
        if let out = processor.process(first) {
            processed = out
            processingFailed = false
        } else {
            processed = nil
            processingFailed = true
        }
    }

    private func save() {
        guard let processed else { return }
        try? store.save(processed)
        onSaved()
    }
}

/// Renders an image over a checkerboard so transparency is visible.
private struct CheckerboardPreview: View {
    let image: UIImage
    var body: some View {
        ZStack {
            Checkerboard().fill(Color(.systemGray5))
            Image(uiImage: image).resizable().scaledToFit().padding(8)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.systemGray4)))
    }
}

private struct Checkerboard: Shape {
    var square: CGFloat = 10
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let cols = Int(rect.width / square) + 1, rows = Int(rect.height / square) + 1
        for r in 0..<rows {
            for c in 0..<cols where (r + c) % 2 == 0 {
                p.addRect(CGRect(x: CGFloat(c) * square, y: CGFloat(r) * square,
                                 width: square, height: square))
            }
        }
        return p
    }
}
```

> `CaptureSheet`'s initializer is `CaptureSheet(presenter:onFinish:onCancel:)` (confirmed) — matches the call above.

- [ ] **Step 2: Build**

```bash
cd DocumentScanner && xcodebuild build -scheme DocumentScanner \
  -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add DocumentScanner/DocumentScanner/Signature/SignatureCaptureView.swift
git commit -m "feat: SignatureCaptureView — scan, preview on checkerboard, save"
```

---

## Task 5: Settings — Signature section

**Files:**
- Modify: `DocumentScanner/DocumentScanner/Settings/SettingsView.swift`

- [ ] **Step 1: Add the Signature section**

`SettingsView` currently takes `lockSettings`. It needs the scanner presenter to drive capture; add a stored `let scannerPresenter: DocumentScannerPresenting` and pass it from the call sites (the library toolbar `NavigationLink { SettingsView(...) }` — update those to pass `scannerPresenter: scannerPresenter`). Add state + a section:

```swift
    @State private var signatureThumbnail: UIImage?
    @State private var showingSignatureCapture = false
    private let signatureStore = SignatureStore()
```

Add a section before About:

```swift
            Section {
                if let signatureThumbnail {
                    HStack {
                        Image(uiImage: signatureThumbnail).resizable().scaledToFit()
                            .frame(height: 40)
                        Spacer()
                    }
                    Button("Replace Signature") { showingSignatureCapture = true }
                    Button("Remove Signature", role: .destructive) {
                        signatureStore.clear(); signatureThumbnail = nil
                    }
                } else {
                    Button("Add Signature") { showingSignatureCapture = true }
                }
            } header: {
                Text("Signature")
            } footer: {
                Text("Scan your signature once on paper, then reuse it to sign any document.")
            }
```

Wire load + the capture sheet (on the Form):

```swift
        .onAppear { signatureThumbnail = signatureStore.load() }
        .sheet(isPresented: $showingSignatureCapture) {
            SignatureCaptureView(
                presenter: scannerPresenter,
                store: signatureStore,
                onSaved: { showingSignatureCapture = false; signatureThumbnail = signatureStore.load() },
                onCancel: { showingSignatureCapture = false }
            )
        }
```

- [ ] **Step 2: Build**

```bash
cd DocumentScanner && xcodebuild build -scheme DocumentScanner \
  -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`. (Fix the `SettingsView(...)` call sites in `LibraryView` to pass `scannerPresenter` — the build will flag them.)

- [ ] **Step 3: Commit**

```bash
git add DocumentScanner/DocumentScanner/Settings/SettingsView.swift \
        DocumentScanner/DocumentScanner/Library/LibraryView.swift
git commit -m "feat: Settings Signature section — capture, replace, remove"
```

---

## Task 6: Viewer — Sign action, placement, commit, delete

**Files:**
- Modify: `DocumentScanner/DocumentScanner/Viewer/DocumentSession.swift`
- Modify: `DocumentScanner/DocumentScanner/Annotations/AnnotationFactory.swift`
- Create: `DocumentScanner/DocumentScanner/Signature/SignaturePlacementView.swift`
- Modify: `DocumentScanner/DocumentScanner/Viewer/DocumentViewerView.swift`

- [ ] **Step 1: Add the signature annotation tag**

In `DocumentSession.swift`, next to `userAnnotationName`:

```swift
    /// Annotation `userName` marking a placed signature stamp. Persists across
    /// save like user marks (not search-tagged, so save() keeps it).
    nonisolated static let signatureAnnotationName = "DocumentScanner.signature"
```

- [ ] **Step 2: Recognize the signature in tap-to-delete**

In `AnnotationFactory.isUserDeletable`, broaden so a signature stamp is deletable:

```swift
    static func isUserDeletable(_ annotation: PDFAnnotation) -> Bool {
        if annotation.userName == DocumentSession.signatureAnnotationName { return true }
        let isMarkSubtype = annotation.type == "Highlight" || annotation.type == "StrikeOut"
        return isMarkSubtype && annotation.userName != DocumentSession.searchHighlightAnnotationName
    }
```

- [ ] **Step 3: Implement `SignaturePlacementView`**

Create `Signature/SignaturePlacementView.swift` — shows the page image with the signature as a draggable/pinch-resizable overlay; **Done** returns the signature's frame in the page's image-pixel space; **Cancel** returns nil.

```swift
import SwiftUI
import PDFKit

/// Overlays the saved signature on a page image; the user drags and pinches it
/// into position. `onPlace` receives the final signature rect in the page's
/// PDF coordinate space (origin bottom-left); `onCancel` discards.
struct SignaturePlacementView: View {
    let pageImage: UIImage
    let signature: UIImage
    let pageBounds: CGRect          // page.bounds(for: .mediaBox)
    let onPlace: (CGRect) -> Void
    let onCancel: () -> Void

    @State private var center: CGPoint = .zero
    @State private var scale: CGFloat = 1
    @GestureState private var dragOffset: CGSize = .zero
    @GestureState private var pinch: CGFloat = 1

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let fit = aspectFit(pageImage.size, in: geo.size)
                ZStack {
                    Image(uiImage: pageImage).resizable().scaledToFit()
                    let sigSize = signatureSize(in: fit.size)
                    Image(uiImage: signature)
                        .resizable().scaledToFit()
                        .frame(width: sigSize.width * scale * pinch,
                               height: sigSize.height * scale * pinch)
                        .position(x: center.x + dragOffset.width,
                                  y: center.y + dragOffset.height)
                        .gesture(
                            DragGesture().updating($dragOffset) { v, s, _ in s = v.translation }
                                .onEnded { v in center.x += v.translation.width; center.y += v.translation.height }
                        )
                        .simultaneousGesture(
                            MagnificationGesture().updating($pinch) { v, s, _ in s = v }
                                .onEnded { v in scale *= v }
                        )
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .onAppear { if center == .zero { center = CGPoint(x: geo.size.width/2, y: geo.size.height/2) } }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { onCancel() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { onPlace(pageRect(in: geo.size)) }
                    }
                }
            }
            .navigationTitle("Place Signature")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // Map the on-screen signature frame to PDF page coordinates (origin bottom-left).
    private func pageRect(in container: CGSize) -> CGRect {
        let fit = aspectFit(pageImage.size, in: container)
        let sigSize = signatureSize(in: fit.size)
        let w = sigSize.width * scale, h = sigSize.height * scale
        // signature top-left in view space:
        let originView = CGPoint(x: center.x - w/2, y: center.y - h/2)
        // into the fitted-image local space:
        let lx = (originView.x - fit.origin.x), ly = (originView.y - fit.origin.y)
        // normalized 0..1 within the page image:
        let nx = lx / fit.size.width, ny = ly / fit.size.height
        let nw = w / fit.size.width, nh = h / fit.size.height
        // to page coords; flip Y (view top-left → PDF bottom-left):
        let px = pageBounds.minX + nx * pageBounds.width
        let pw = nw * pageBounds.width
        let ph = nh * pageBounds.height
        let py = pageBounds.minY + (1 - ny - nh) * pageBounds.height
        return CGRect(x: px, y: py, width: pw, height: ph)
    }

    private func signatureSize(in fitted: CGSize) -> CGSize {
        // default the signature to ~40% of page width, preserving aspect.
        let targetW = fitted.width * 0.4
        let aspect = signature.size.height / max(signature.size.width, 1)
        return CGSize(width: targetW, height: targetW * aspect)
    }

    private func aspectFit(_ image: CGSize, in container: CGSize) -> CGRect {
        let s = min(container.width / image.width, container.height / image.height)
        let size = CGSize(width: image.width * s, height: image.height * s)
        return CGRect(x: (container.width - size.width)/2,
                      y: (container.height - size.height)/2,
                      width: size.width, height: size.height)
    }
}
```

- [ ] **Step 4: Track the visible page in `PDFKitView`**

The viewer scrolls all pages (`.singlePageContinuous`) and the SwiftUI layer doesn't know which page is on screen. Add lightweight tracking so the signature lands on the page the user is viewing.

In `PDFKitView` (the `UIViewRepresentable` at line ~432), add a binding and a coordinator that observes page changes:

```swift
    @Binding var currentPageIndex: Int
```
In `makeUIView`, after the view is built, set up the coordinator + observer (add a `makeCoordinator()` and `Coordinator` if the representable doesn't already have one):

```swift
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator {
        let parent: PDFKitView
        init(_ parent: PDFKitView) { self.parent = parent }
        @objc func pageChanged(_ note: Notification) {
            guard let view = note.object as? PDFView,
                  let doc = view.document, let page = view.currentPage else { return }
            let idx = doc.index(for: page)
            if idx != parent.currentPageIndex { parent.currentPageIndex = idx }
        }
    }
```
Register in `makeUIView` (after creating `v`):

```swift
        NotificationCenter.default.addObserver(
            context.coordinator, selector: #selector(Coordinator.pageChanged(_:)),
            name: .PDFViewPageChanged, object: v)
```
Pass the binding where `PDFKitView(...)` is constructed (line ~147): add `currentPageIndex: $currentVisiblePageIndex`.

- [ ] **Step 5: Wire the Sign action into `DocumentViewerView`**

Add state and a bottom-bar **Sign** button (near the existing Edit button at line ~214). On tap: if `signatureStore.load()` is nil → present `SignatureCaptureView` first, then placement; else present placement for the viewed page.

```swift
    @State private var showingSignCapture = false
    @State private var placingSignature: UIImage?     // non-nil → show placement
    @State private var currentVisiblePageIndex = 0
    private let signatureStore = SignatureStore()
```

Bottom-bar button (in the `ToolbarItemGroup(placement: .bottomBar)`):

```swift
                Button("Sign") {
                    if let sig = signatureStore.load() { placingSignature = sig }
                    else { showingSignCapture = true }
                }
```

Presentations (on the same view that hosts the PDF; uses the current page = page 0 of the active single-doc session, or the viewer's current page index if it tracks one — use `session.pdf.page(at: currentPageIndex)`; if the viewer shows one page at a time use that, otherwise default to the first visible page):

```swift
        .sheet(isPresented: $showingSignCapture) {
            SignatureCaptureView(
                presenter: scannerPresenter, store: signatureStore,
                onSaved: { showingSignCapture = false; placingSignature = signatureStore.load() },
                onCancel: { showingSignCapture = false }
            )
        }
        .sheet(item: Binding(get: { placingSignature.map { SigImage(image: $0) } },
                             set: { if $0 == nil { placingSignature = nil } })) { wrapper in
            if let page = currentPageForSigning(session: session) {
                SignaturePlacementView(
                    pageImage: pageRenderForSigning(page),
                    signature: wrapper.image,
                    pageBounds: page.bounds(for: .mediaBox),
                    onPlace: { rect in placeSignature(wrapper.image, at: rect, on: page, session: session); placingSignature = nil },
                    onCancel: { placingSignature = nil }
                )
            }
        }
```

Helpers (add to the view; `SigImage` is a tiny Identifiable wrapper; `currentPageForSigning` returns the page the viewer is showing — reuse the viewer's existing current-page tracking, or `session.pdf.page(at: 0)` if it shows the whole doc; `pageRenderForSigning` reuses `PageImageRenderer().image(from:)`):

```swift
    private struct SigImage: Identifiable { let id = UUID(); let image: UIImage }

    /// The page the user is currently viewing (tracked from PDFKitView). Clamped
    /// so a stale index can't trap.
    private func currentPageForSigning(session: DocumentSession) -> PDFPage? {
        let idx = min(max(currentVisiblePageIndex, 0), session.pdf.pageCount - 1)
        return session.pdf.page(at: idx)
    }

    private func pageRenderForSigning(_ page: PDFPage) -> UIImage {
        PageImageRenderer().image(from: page) ?? UIImage()
    }

    private func placeSignature(_ image: UIImage, at rect: CGRect, on page: PDFPage, session: DocumentSession) {
        let stamp = ImageStampAnnotation(image: image, bounds: rect,
                                         userName: DocumentSession.signatureAnnotationName)
        page.addAnnotation(stamp)
        _ = try? session.save()
        annotationRevision &+= 1
    }
```

- [ ] **Step 6: Build**

```bash
cd DocumentScanner && xcodebuild build -scheme DocumentScanner \
  -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`. The existing tap-to-delete already routes any `isUserDeletable` annotation to the "Delete" confirm — verify the signature is now tappable→deletable (its title is generic "Delete"; that's fine for v1).

- [ ] **Step 7: Commit**

```bash
git add DocumentScanner/DocumentScanner/Viewer/DocumentSession.swift \
        DocumentScanner/DocumentScanner/Annotations/AnnotationFactory.swift \
        DocumentScanner/DocumentScanner/Signature/SignaturePlacementView.swift \
        DocumentScanner/DocumentScanner/Viewer/DocumentViewerView.swift
git commit -m "feat: sign a document — Sign action, placement, commit, delete"
```

---

## Task 7: Full suite + roadmap/memory

**Files:**
- Modify: `docs/FutureEnhancements.md`

- [ ] **Step 1: Full unit suite (no regressions)**

```bash
cd DocumentScanner && xcodebuild test -scheme DocumentScanner \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:DocumentScannerTests 2>&1 | grep -E "\*\* TEST|failed" | tail -5
```
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 2: Roadmap — record the feature + deferred 2.x items**

In `docs/FutureEnhancements.md`, add under a new `### Signing` section a note that signature signing shipped in **v2.0**, and list the deferred non-goals (multiple signatures; typed/drawn; initials/date; iCloud-sync; auto-placement; multi-page) as the **2.x** follow-ups. Remove the shelved "Annotation rectangle-drag fallback" item (superseded — free-form placement now exists via signatures).

- [ ] **Step 3: Commit**

```bash
git add docs/FutureEnhancements.md
git commit -m "docs: record signature signing (v2.0) + 2.x follow-ups"
```

---

## Done

After Task 7: a user can scan their signature once (Settings ▸ Signature), then **Sign** any document — drag/resize the cut-out onto the page, where it persists as an editable stamp that can be tapped and removed later. Capture cleanup is automatic (B&W → key → crop) with a checkerboard preview + Rescan; no sliders.

**On-device smoke test (manual):**
1. Settings ▸ Signature ▸ **Add Signature** → scan a signature on paper → checkerboard preview shows a clean transparent cut-out → **Save**; the thumbnail appears.
2. Bad input (blank/blurry) → preview shows the "Couldn't read that" state → **Rescan**.
3. Open a doc ▸ **Sign** → the signature appears → drag + pinch into place → **Done** → it's on the page.
4. Close + reopen the doc → the signature is **still there** (persistence) → tap it → **Delete** → gone.
5. With no saved signature, **Sign** routes to capture first, then placement.
6. Replace + Remove signature in Settings behave correctly.

Ships in **v2.0 (18)** (bump `MARKETING_VERSION` 1.12→2.0, `CURRENT_PROJECT_VERSION`→18 as the usual `chore:` at archive time). The deferred items are the 2.x roadmap.
