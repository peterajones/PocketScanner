# Scanned-PDF File-Size Reduction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Shrink scanned PDFs ~10–20× (from ~3.5 MB/page toward flatbed-comparable) by downsampling + JPEG-compressing each page at the single image→PDF chokepoint.

**Architecture:** A new pure `PageImageCompressor` (downsample-never-upsample + JPEG-encode) feeds `PDFAssembler.renderPage`, which draws a JPEG-backed `CGImage` so the emitted PDF embeds the compressed stream. `renderPage` is the sole image→PDF path (`PDFPage(image:)` is used nowhere), so this covers new scans, edited pages, and added pages. The searchable invisible-text layer + metadata are untouched.

**Tech Stack:** Swift, UIKit, CoreGraphics/ImageIO, PDFKit, XCTest.

**Spec:** `docs/superpowers/specs/2026-07-07-pdf-file-size-design.md`

---

## File Structure

- `DocumentScanner/DocumentScanner/Pipeline/PageImageCompressor.swift` — **new** pure helper: `downsampledSize(for:maxLongEdge:)` + `compressedJPEGData(from:maxLongEdge:quality:)`.
- `DocumentScanner/DocumentScanner/Pipeline/PDFAssembler.swift` — `renderPage` draws a JPEG-backed, downsampled image (fallback to the existing normalized image on failure).
- Tests: `DocumentScanner/DocumentScannerTests/PageImageCompressorTests.swift` (new) and additions to `DocumentScanner/DocumentScannerTests/PDFAssemblerTests.swift`.

Baked defaults (within the spec's tuning range; confirmed/adjusted in the on-device smoke): **maxLongEdge = 2400 px, quality = 0.65**.

Full suite: `./scripts/test.sh`.

---

## Task 1: `PageImageCompressor` — downsample + JPEG (pure)

**Files:**
- Create: `DocumentScanner/DocumentScanner/Pipeline/PageImageCompressor.swift`
- Test: `DocumentScanner/DocumentScannerTests/PageImageCompressorTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `PageImageCompressorTests.swift`:

```swift
import XCTest
import UIKit
@testable import DocumentScanner

final class PageImageCompressorTests: XCTestCase {

    private func solidImage(_ w: CGFloat, _ h: CGFloat) -> UIImage {
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1; fmt.opaque = true
        return UIGraphicsImageRenderer(size: CGSize(width: w, height: h), format: fmt).image { ctx in
            UIColor.white.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
            UIColor.black.setFill(); ctx.fill(CGRect(x: 10, y: 10, width: w - 20, height: 40))
        }
    }

    func test_downsampledSize_scalesDownWhenAboveCap() {
        let s = PageImageCompressor.downsampledSize(for: CGSize(width: 3000, height: 4000), maxLongEdge: 2000)
        XCTAssertEqual(s.width, 1500, accuracy: 1)
        XCTAssertEqual(s.height, 2000, accuracy: 1)
    }

    func test_downsampledSize_leavesSmallImageUntouched() {
        let s = PageImageCompressor.downsampledSize(for: CGSize(width: 1000, height: 800), maxLongEdge: 2000)
        XCTAssertEqual(s, CGSize(width: 1000, height: 800))
    }

    func test_downsampledSize_preservesAspectRatio() {
        let src = CGSize(width: 4000, height: 3000)
        let s = PageImageCompressor.downsampledSize(for: src, maxLongEdge: 2000)
        XCTAssertEqual(s.width / s.height, src.width / src.height, accuracy: 0.01)
    }

    func test_compressedJPEGData_isDecodableAndCappedLongEdge() throws {
        let data = try XCTUnwrap(
            PageImageCompressor.compressedJPEGData(from: solidImage(3000, 4000), maxLongEdge: 2000, quality: 0.6)
        )
        let decoded = try XCTUnwrap(UIImage(data: data))
        XCTAssertLessThanOrEqual(max(decoded.size.width, decoded.size.height) * decoded.scale, 2000 + 1)
    }

    func test_compressedJPEGData_doesNotUpsampleSmallImage() throws {
        let data = try XCTUnwrap(
            PageImageCompressor.compressedJPEGData(from: solidImage(800, 600), maxLongEdge: 2000, quality: 0.6)
        )
        let decoded = try XCTUnwrap(UIImage(data: data))
        XCTAssertEqual(decoded.size.width * decoded.scale, 800, accuracy: 1)
        XCTAssertEqual(decoded.size.height * decoded.scale, 600, accuracy: 1)
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `xcodebuild test -project DocumentScanner/DocumentScanner.xcodeproj -scheme DocumentScanner -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:DocumentScannerTests/PageImageCompressorTests/test_downsampledSize_scalesDownWhenAboveCap`
Expected: FAIL — no type `PageImageCompressor`.

- [ ] **Step 3: Implement**

Create `PageImageCompressor.swift`:

```swift
import UIKit

/// Downsamples a scanned page image and JPEG-encodes it, so `PDFAssembler` can
/// embed a compact page instead of the full-resolution lossless capture (~24×
/// smaller in practice). Pure + SwiftUI-free so the size logic is unit-tested.
enum PageImageCompressor {

    /// The size to render at: scaled so the longest edge is at most `maxLongEdge`
    /// points. Never upsamples (returns the source size when already within cap).
    static func downsampledSize(for size: CGSize, maxLongEdge: CGFloat) -> CGSize {
        let longest = max(size.width, size.height)
        guard longest > maxLongEdge, longest > 0 else { return size }
        let scale = maxLongEdge / longest
        return CGSize(width: (size.width * scale).rounded(),
                      height: (size.height * scale).rounded())
    }

    /// Bakes in orientation, downsamples to `maxLongEdge`, and JPEG-encodes at
    /// `quality`. Returns nil if encoding fails. `scale = 1` so the produced JPEG's
    /// pixel dimensions equal the point dimensions (matching how `PDFAssembler`
    /// derives the page mediaBox from pixel size).
    static func compressedJPEGData(from image: UIImage,
                                   maxLongEdge: CGFloat,
                                   quality: CGFloat) -> Data? {
        let target = downsampledSize(for: image.size, maxLongEdge: maxLongEdge)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let rendered = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return rendered.jpegData(compressionQuality: quality)
    }
}
```

- [ ] **Step 4: Run to verify pass**

Run: `xcodebuild test -project DocumentScanner/DocumentScanner.xcodeproj -scheme DocumentScanner -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:DocumentScannerTests/PageImageCompressorTests`
Expected: 5/5 PASS.

- [ ] **Step 5: Commit**

```bash
git add DocumentScanner/DocumentScanner/Pipeline/PageImageCompressor.swift DocumentScanner/DocumentScannerTests/PageImageCompressorTests.swift
git commit -m "feat: PageImageCompressor — downsample + JPEG for scanned pages

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 2: Wire compression into `PDFAssembler` (spike + integration)

**Files:**
- Modify: `DocumentScanner/DocumentScanner/Pipeline/PDFAssembler.swift`
- Test: `DocumentScanner/DocumentScannerTests/PDFAssemblerTests.swift`

**This task contains the spike.** The size-threshold test is the proof that CoreGraphics embeds the JPEG *small* (passes DCTDecode through) rather than re-inflating it. If that test still FAILS after wiring, **STOP and report DONE_WITH_CONCERNS/BLOCKED** — do not attempt the larger `UIGraphicsPDFRenderer` rebuild without escalating (it risks the searchable-text layer and is a design change).

- [ ] **Step 1: Write the failing tests**

Add to `PDFAssemblerTests.swift` (it already imports `PDFKit`/`UIKit` and tests `PDFAssembler`; add a gradient-image helper if one isn't present):

```swift
// A large, continuous-tone image: compresses poorly losslessly (like a real
// camera capture), so the size test meaningfully proves JPEG compression ran.
private func largeGradientImage(_ w: CGFloat = 3000, _ h: CGFloat = 4000) -> UIImage {
    let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1; fmt.opaque = true
    return UIGraphicsImageRenderer(size: CGSize(width: w, height: h), format: fmt).image { ctx in
        let colors = [UIColor.systemRed.cgColor, UIColor.systemBlue.cgColor] as CFArray
        let space = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1])!
        ctx.cgContext.drawLinearGradient(gradient, start: .zero,
                                         end: CGPoint(x: w, y: h), options: [])
    }
}

func test_assemble_compressesLargePageWellBelowLosslessSize() throws {
    let page = ScannedPage(image: largeGradientImage(), observations: [])
    let pdf = try PDFAssembler().assemble(pages: [page], createdAt: Date())
    let data = try XCTUnwrap(pdf.dataRepresentation())
    // A 12MP continuous-tone image embedded losslessly is multiple MB; downsampled
    // JPEG must land far below that. Generous ceiling — proves compression happened.
    XCTAssertLessThan(data.count, 800_000, "expected downsampled+JPEG page, got \(data.count) bytes")
}

func test_assemble_downsamplesLargePageToCap() throws {
    let page = ScannedPage(image: largeGradientImage(3000, 4000), observations: [])
    let pdf = try PDFAssembler().assemble(pages: [page], createdAt: Date())
    let bounds = try XCTUnwrap(pdf.page(at: 0)).bounds(for: .mediaBox)
    XCTAssertLessThanOrEqual(max(bounds.width, bounds.height), 2400 + 1)
}

func test_assemble_doesNotUpsampleSmallPage() throws {
    let small = UIGraphicsImageRenderer(size: CGSize(width: 600, height: 800)).image { ctx in
        UIColor.white.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 600, height: 800))
    }
    let pdf = try PDFAssembler().assemble(pages: [ScannedPage(image: small, observations: [])], createdAt: Date())
    let bounds = try XCTUnwrap(pdf.page(at: 0)).bounds(for: .mediaBox)
    XCTAssertEqual(max(bounds.width, bounds.height), 800, accuracy: 2)
}
```

Searchability guard — reuse the existing `obs(_:y:)` helper already defined in
`PDFAssemblerTests.swift` (it builds an `OCRObservation`), so this compiles without
touching the `OCRObservation` initializer:

```swift
func test_assemble_preservesSearchableText_afterCompression() throws {
    let page = ScannedPage(image: largeGradientImage(), observations: [obs("INVOICE", y: 0.8)])
    let pdf = try PDFAssembler().assemble(pages: [page], createdAt: Date())
    XCTAssertTrue((pdf.string ?? "").contains("INVOICE"))
}
```

- [ ] **Step 2: Run to verify failure**

Run: `xcodebuild test -project DocumentScanner/DocumentScanner.xcodeproj -scheme DocumentScanner -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:DocumentScannerTests/PDFAssemblerTests/test_assemble_compressesLargePageWellBelowLosslessSize`
Expected: FAIL — the current lossless embed produces a file well over 800 KB.

- [ ] **Step 3: Implement — draw a JPEG-backed, downsampled image**

In `PDFAssembler.swift`, change `renderPage` so `cgImage` comes from the compressor, falling back to the existing `normalizedCGImage` only if compression fails. Replace the top of `renderPage`:

```swift
private func renderPage(_ page: ScannedPage, into context: CGContext) throws {
    let cgImage = try compressedCGImage(from: page.image)

    // Page size in points matches the (possibly downsampled) image's pixel size at
    // 1pt-per-pixel; preserves aspect ratio without further resampling.
    let size = CGSize(width: CGFloat(cgImage.width), height: CGFloat(cgImage.height))
    var pageRect = CGRect(origin: .zero, size: size)

    context.beginPage(mediaBox: &pageRect)
    context.draw(cgImage, in: pageRect)

    if !page.observations.isEmpty {
        drawInvisibleText(page.observations, in: pageRect, into: context)
    }
    context.endPage()
}
```

And add this helper (below `normalizedCGImage`). Building the `CGImage` from the JPEG data via `CGImageSource` is what lets CoreGraphics embed the JPEG stream (DCTDecode) in the PDF instead of re-inflating it:

```swift
/// Downsampled + JPEG-encoded page image, built from the JPEG bytes via ImageIO so
/// the CoreGraphics PDF context embeds the compressed (DCTDecode) stream. Falls back
/// to the uncompressed normalized image if compression fails (a large page beats a
/// failed save). Long-edge cap and quality are tuned for document legibility.
private func compressedCGImage(from image: UIImage) throws -> CGImage {
    if let jpeg = PageImageCompressor.compressedJPEGData(from: image, maxLongEdge: 2400, quality: 0.65),
       let source = CGImageSourceCreateWithData(jpeg as CFData, nil),
       let cg = CGImageSourceCreateImageAtIndex(source, 0, nil) {
        return cg
    }
    guard let normalized = normalizedCGImage(from: image) else {
        throw PDFAssemblerError.pageCreationFailed
    }
    return normalized
}
```

- [ ] **Step 4: Run to verify pass (this is the spike verdict)**

Run: `xcodebuild test -project DocumentScanner/DocumentScanner.xcodeproj -scheme DocumentScanner -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:DocumentScannerTests/PDFAssemblerTests`
Expected: PASS — size test under 800 KB (JPEG embedded), downsample + no-upsample + searchable-text all green.

**If `test_assemble_compressesLargePageWellBelowLosslessSize` still FAILS** (file remained large ⇒ CoreGraphics re-inflated the JPEG): STOP. Report **BLOCKED/DONE_WITH_CONCERNS** with the observed byte size. Do not silently rebuild the assembler on `UIGraphicsPDFRenderer` — that's the pre-agreed fallback but it's a design-level change (re-implements the invisible-text + metadata layers) and needs a go-ahead.

- [ ] **Step 5: Commit**

```bash
git add DocumentScanner/DocumentScanner/Pipeline/PDFAssembler.swift DocumentScanner/DocumentScannerTests/PDFAssemblerTests.swift
git commit -m "feat: downsample + JPEG-compress pages in PDFAssembler

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 3: Roadmap doc + full-suite verification

**Files:**
- Modify: `docs/FutureEnhancements.md`

- [ ] **Step 1: Mark C shipped**

In `docs/FutureEnhancements.md` "Next up" section, change the **C** bullet to struck-through/shipped, noting it ships as v2.5 (24) and that B → A remain next. Keep the B and A bullets.

- [ ] **Step 2: Run the full suite**

Run: `./scripts/test.sh`
Expected: `Passed: <n>  Failed: 0` (197 + the new PageImageCompressor + PDFAssembler tests).

- [ ] **Step 3: Commit**

```bash
git add docs/FutureEnhancements.md
git commit -m "docs: mark PDF file-size reduction shipped (v2.5)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

- [ ] **Step 4: On-device smoke (manual, at release time)**

Scan a real tax slip → confirm the saved PDF drops to flatbed-comparable size (Files → Get Info) **and** the fine print stays legible; edit a page (crop/filter) and add pages → confirm those are compressed too; open a pre-existing large doc → unchanged (no retroactive compression). If small print is soft, nudge `maxLongEdge` up (e.g. 2600) / `quality` up (e.g. 0.72) in `PDFAssembler.compressedCGImage` and re-smoke. **Do the Release build for this** (prod bundle / real iCloud), not just Debug. Version bump 2.4/23 → 2.5/24 at archive.

---

## Notes for the implementer

- `renderPage` is the **only** image→PDF path, so this one change also compresses edited pages (`PageEditorView` → `PDFAssembler`) and added pages (`pipeline.process` → `PDFAssembler`) — no other files.
- The invisible OCR-text layer positions text from **normalized** (0–1) coordinates relative to `pageRect`, so downsampling the image needs **no** change there — the text stays aligned.
- `jpegData` bakes in `UIImage.imageOrientation`, so the compressed path is already upright; `normalizedCGImage` remains only as the fallback.
- Keep the baked params as named literals in `compressedCGImage` (2400 / 0.65) — they're deliberately tunable in one place for the on-device pass.
